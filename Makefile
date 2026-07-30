.PHONY: all publish-all publish-bundles publish-resource-types publish-platforms create-repos build-bundles validate-bundles clean clean-variables clean-lock clean-terraform clean-state clean-schemas help

# Enabled platforms - edit this list to enable additional platforms
# Available: aws, gcp, azure, kubernetes, vercel, snowflake, ovh, upcloud, scaleway, digitalocean
ENABLED_PLATFORMS ?= aws gcp azure kubernetes

# Dynamic discovery functions
BUNDLES = $(shell find bundles -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
RESOURCE_TYPES = $(shell find resource-types -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
PLATFORMS = $(ENABLED_PLATFORMS)

help:
	@echo "Massdriver Catalog - Available Commands:"
	@echo ""
	@echo "  make all                    - Clean, publish resource types, build, validate and publish bundles"
	@echo "  make publish-platforms      - Publish platform credential resource types"
	@echo "  make publish-resource-types - Publish resource types"
	@echo "  make create-repos           - Create OCI repositories for all bundles + resource types (idempotent)"
	@echo "  make build-bundles          - Build all bundles (generate schemas)"
	@echo "  make validate-bundles       - Initialize and validate all bundles with OpenTofu"
	@echo "  make publish-bundles        - Publish all bundles to Massdriver"
	@echo "  make clean                  - Clean up all artifacts"
	@echo "  make clean-variables        - Clean up _massdriver_variables.tf files"
	@echo "  make clean-lock             - Clean up .terraform.lock.hcl files"
	@echo "  make clean-terraform        - Clean up .terraform directories"
	@echo "  make clean-state            - Clean up terraform.tfstate files"
	@echo "  make clean-schemas          - Clean up schema-*.json files"
	@echo ""
	@echo "Configuration:"
	@echo "  ENABLED_PLATFORMS           - Space-separated list of platforms to publish"
	@echo "                                Default: aws gcp azure kubernetes"
	@echo "                                Available: aws gcp azure kubernetes vercel snowflake ovh upcloud scaleway digitalocean"
	@echo ""
	@echo "Examples:"
	@echo "  make publish-platforms                                    # Publish default platforms"
	@echo "  make publish-platforms ENABLED_PLATFORMS='aws gcp vercel' # Publish specific platforms"
	@echo ""

all:
	@echo "This will clean, publish resource types, build, validate and publish all bundles."
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1)
	@$(MAKE) clean create-repos publish-resource-types build-bundles validate-bundles publish-bundles

publish-all: create-repos publish-platforms publish-resource-types publish-bundles
	@echo "Successfully published all platforms, resource types, and bundles!"

publish-platforms: create-repos
	@for platform in $(PLATFORMS); do \
		echo "Publishing platform $$platform..."; \
		mass resource-type publish platforms/$$platform/massdriver.yaml; \
	done

# Massdriver v2 publishes into OCI repositories, and the repository must exist
# before publish — for BUNDLES and RESOURCE TYPES alike (platforms are resource
# types too). A repository is named exactly after the bundle / resource type it
# holds, and all repositories share one namespace, so names cannot collide.
# `mass repository create` is safe to re-run — if the repository already exists
# the command exits non-zero, which we ignore. We keep stderr on the console so
# auth or network errors stay visible. If a repository needs custom attributes,
# run `mass repository create <name> -t <type> -a key=value` once by hand.
create-repos:
	@for rt in $(RESOURCE_TYPES); do \
		echo "Ensuring resource-type repository exists for $$rt..."; \
		mass repository create $$rt -t resource-type 2>&1 || true; \
	done
	@for platform in $(PLATFORMS); do \
		name=$$(grep -m1 '^name:' platforms/$$platform/massdriver.yaml | awk '{print $$2}'); \
		echo "Ensuring resource-type repository exists for $$name..."; \
		mass repository create $$name -t resource-type 2>&1 || true; \
	done
	@for bundle in $(BUNDLES); do \
		echo "Ensuring bundle repository exists for $$bundle..."; \
		mass repository create $$bundle -t bundle 2>&1 || true; \
	done

publish-bundles: clean-lock create-repos build-bundles validate-bundles
	@for bundle in $(BUNDLES); do \
		echo "Publishing $$bundle..."; \
		mass bundle publish --bundle-directory bundles/$$bundle; \
	done

publish-resource-types: create-repos
	@for rt in $(RESOURCE_TYPES); do \
		echo "Publishing resource type $$rt..."; \
		mass resource-type publish resource-types/$$rt/massdriver.yaml; \
	done

build-bundles:
	@for bundle in $(BUNDLES); do \
		echo "Building $$bundle..."; \
		mass bundle build --bundle-directory bundles/$$bundle; \
	done
	@echo "All bundles built successfully!"

validate-bundles: build-bundles
	@for bundle in $(BUNDLES); do \
		echo "Initializing OpenTofu for $$bundle..."; \
		( cd bundles/$$bundle/src && tofu init ); \
		echo "Validating OpenTofu for $$bundle..."; \
		( cd bundles/$$bundle/src && tofu validate ); \
	done
	@echo "All bundles validated successfully!"

clean: clean-variables clean-lock clean-terraform clean-state clean-schemas
	@echo "Cleaned up all artifacts"

clean-variables:
	@find . -name "_massdriver_variables.tf" -delete 2>/dev/null || true
	@echo "Cleaned up Massdriver variable files"

clean-lock:
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "Cleaned up Terraform lock files"

clean-terraform:
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaned up Terraform directories"

clean-state:
	@find . -name "terraform.tfstate*" -delete 2>/dev/null || true
	@echo "Cleaned up Terraform state files"

clean-schemas:
	@find . -name "schema-*.json" -delete 2>/dev/null || true
	@echo "Cleaned up schema files"
