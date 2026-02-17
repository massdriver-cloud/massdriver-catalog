.PHONY: all publish-all publish-bundles publish-artifact-definitions publish-platforms build-bundles validate-bundles clean clean-variables clean-lock clean-terraform clean-state clean-schemas help

# Enabled platforms - edit this list to enable additional platforms
# Available: aws, gcp, azure, kubernetes, vercel, snowflake, ovh, upcloud, scaleway, digitalocean
ENABLED_PLATFORMS ?= aws gcp azure kubernetes

# Dynamic discovery functions
BUNDLES = $(shell find bundles -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARTDEFS = $(shell find artifact-definitions -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
PLATFORMS = $(ENABLED_PLATFORMS)

help:
	@echo "Massdriver Catalog - Available Commands:"
	@echo ""
	@echo "  make all                      - Clean, publish artifacts, build, validate and publish bundles"
	@echo "  make publish-platforms        - Publish platform credential definitions"
	@echo "  make publish-artifact-definitions - Publish artifact definitions"
	@echo "  make build-bundles            - Build all bundles (generate schemas)"
	@echo "  make validate-bundles         - Initialize and validate all bundles with OpenTofu"
	@echo "  make publish-bundles          - Publish all bundles to Massdriver"
	@echo "  make clean                    - Clean up all artifacts"
	@echo "  make clean-variables          - Clean up _massdriver_variables.tf files"
	@echo "  make clean-lock               - Clean up .terraform.lock.hcl files"
	@echo "  make clean-terraform          - Clean up .terraform directories"
	@echo "  make clean-state              - Clean up terraform.tfstate files"
	@echo "  make clean-schemas            - Clean up schema-*.json files"
	@echo ""
	@echo "Configuration:"
	@echo "  ENABLED_PLATFORMS             - Space-separated list of platforms to publish"
	@echo "                                  Default: aws gcp azure kubernetes"
	@echo "                                  Available: aws gcp azure kubernetes vercel snowflake ovh upcloud scaleway digitalocean"
	@echo ""
	@echo "Examples:"
	@echo "  make publish-platforms                                    # Publish default platforms"
	@echo "  make publish-platforms ENABLED_PLATFORMS='aws gcp vercel' # Publish specific platforms"
	@echo ""

all:
	@echo "This will clean, publish artifact definitions, build, validate and publish all bundles."
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1)
	@$(MAKE) clean publish-artifact-definitions build-bundles validate-bundles publish-bundles

publish-all: publish-platforms publish-artifact-definitions publish-bundles
	@echo "Successfully published all platforms, artifact definitions, and bundles!"

publish-platforms:
	@for platform in $(PLATFORMS); do \
		echo "Publishing platform $$platform..."; \
		mass definition publish platforms/$$platform/massdriver.yaml; \
	done

publish-bundles: clean-lock build-bundles validate-bundles
	@for bundle in $(BUNDLES); do \
		echo "Publishing $$bundle..."; \
		cd bundles/$$bundle && mass bundle publish && cd ../..; \
	done

publish-artifact-definitions:
	@for artdef in $(ARTDEFS); do \
		echo "Publishing artifact definition $$artdef..."; \
		mass definition publish artifact-definitions/$$artdef/massdriver.yaml; \
	done

build-bundles:
	@for bundle in $(BUNDLES); do \
		echo "Building $$bundle..."; \
		cd bundles/$$bundle && mass bundle build && cd ../..; \
	done
	@echo "All bundles built successfully!"

validate-bundles: build-bundles
	@for bundle in $(BUNDLES); do \
		echo "Initializing OpenTofu for $$bundle..."; \
		cd bundles/$$bundle/src && tofu init && cd ../../..; \
		echo "Validating OpenTofu for $$bundle..."; \
		cd bundles/$$bundle/src && tofu validate && cd ../../..; \
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
