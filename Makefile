.PHONY: all publish-all publish-bundles publish-artifact-definitions publish-credentials build-bundles validate-bundles clean clean-variables clean-lock

# Dynamic discovery functions
BUNDLES = $(shell find bundles -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARTDEFS = $(shell find artifact-definitions -name "*.json" -exec basename {} .json \;)
CREDENTIALS = $(shell find credential-artifact-definitions -name "*.json" -exec basename {} \;)

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

clean:
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
