.PHONY: publish-all publish-bundles publish-artdefs publish-credentials build-bundles

# Dynamic discovery functions
BUNDLES = $(shell find bundles -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
ARTDEFS = $(shell find artifact-definitions -name "*.json" -exec basename {} .json \;)
CREDENTIALS = $(shell find credential-artifact-definitions -name "*.json" -exec basename {} \;)

all:
	@echo "This will clean, publish credentials, publish artifact definitions, build and publish all bundles."
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1)
	@$(MAKE) clean publish-credentials publish-artdefs build-bundles publish-bundles

publish-all: publish-credentials publish-artdefs publish-bundles
	@echo "Successfully published all credentials, artifact definitions, and bundles!"

publish-credentials:
	@for credential in $(CREDENTIALS); do \
		echo "Publishing credential $$credential..."; \
		mass definition publish credential-artifact-definitions/$$credential; \
	done

publish-bundles:
	@for bundle in $(BUNDLES); do \
		echo "Publishing $$bundle..."; \
		cd bundles/$$bundle && mass bundle publish && cd ../..; \
	done

publish-artdefs:
	@for artdef in $(ARTDEFS); do \
		echo "Publishing artifact definition $$artdef..."; \
		mass definition publish artifact-definitions/$$artdef.json; \
	done

build-bundles:
	@for bundle in $(BUNDLES); do \
		echo "Building $$bundle..."; \
		cd bundles/$$bundle && mass bundle build && cd ../..; \
	done

clean:
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate*" -delete 2>/dev/null || true
	@find . -name "schema-*.json" -delete 2>/dev/null || true
	@echo "Cleaned up OpenTofu artifacts"

