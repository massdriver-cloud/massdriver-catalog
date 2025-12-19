.PHONY: all publish-all publish-bundles publish-artifact-definitions publish-credentials build-bundles validate-bundles clean clean-variables clean-lock help

# Dynamic discovery functions
BUNDLES = $(shell find bundles -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARTDEFS = $(shell find artifact-definitions -name "*.json" -exec basename {} .json \;)
CREDENTIALS = $(shell find credential-artifact-definitions -name "*.json" -exec basename {} \;)

help:
	@echo "Massdriver Catalog - Available Commands:"
	@echo ""
	@echo "  make all                      - Clean, publish artifacts, build, validate and publish bundles"
	@echo "  make publish-credentials      - Publish cloud credential artifact definitions"
	@echo "  make publish-artifact-definitions - Publish artifact definitions"
	@echo "  make build-bundles            - Build all bundles (generate schemas)"
	@echo "  make validate-bundles         - Initialize and validate all bundles with OpenTofu"
	@echo "  make publish-bundles          - Publish all bundles to Massdriver"
	@echo "  make clean                    - Clean up OpenTofu artifacts and lock files"
	@echo "  make clean-variables          - Clean up _massdriver_variables.tf files"
	@echo "  make clean-lock               - Clean up .terraform.lock.hcl files"
	@echo ""

all:
	@echo "This will clean, publish artifact definitions, build, validate and publish all bundles."
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1)
	@$(MAKE) clean publish-artifact-definitions build-bundles validate-bundles publish-bundles

publish-all: publish-credentials publish-artifact-definitions publish-bundles
	@echo "Successfully published all credentials, artifact definitions, and bundles!"

publish-credentials:
	@for credential in $(CREDENTIALS); do \
		echo "Publishing credential $$credential..."; \
		mass definition publish credential-artifact-definitions/$$credential; \
	done

publish-bundles: clean-lock
	@for bundle in $(BUNDLES); do \
		echo "Publishing $$bundle..."; \
		cd bundles/$$bundle && mass bundle publish && cd ../..; \
	done

publish-artifact-definitions:
	@for artdef in $(ARTDEFS); do \
		echo "Publishing artifact definition $$artdef..."; \
		mass definition publish artifact-definitions/$$artdef.json; \
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

clean: clean-variables clean-lock
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate*" -delete 2>/dev/null || true
	@find . -name "schema-*.json" -delete 2>/dev/null || true
	@find . -name "_massdriver_variables.tf" -delete 2>/dev/null || true
	@echo "Cleaned up OpenTofu artifacts"

clean-variables:
	@find . -name "_massdriver_variables.tf" -delete 2>/dev/null || true
	@echo "Cleaned up Massdriver variable files"

clean-lock:
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "Cleaned up Terraform lock files"
