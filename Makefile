# List of product names we'll generate files for.
PRODUCTS := Classic Retail

# List of databases we'll export for each product above.
DATABASES := Music

# Region to use when querying the CDN.
REGION ?= us

# CDN product IDs for version querying. Prefix these with a product name.
Classic_PRODUCT_ID ?= wow_classic_beta
Retail_PRODUCT_ID ?= wow

# TOC versions for file generation. Prefix these with a product name.
Classic_INTERFACE_VERSION ?= 13002
Retail_INTERFACE_VERSION ?= 80200

# Additional options to pass to the exporter script, prefixed by their
# applicable product name (or no prefix to apply to both).
#
# Options specified here take priority over anything previously declared.
EXPORTER_OPTIONS ?=
Classic_EXPORTER_OPTIONS ?= --max-interface-version 20000
Retail_EXPORTER_OPTIONS ?=

# Path to a Lua interpreter.
LUA ?= lua

# Path and URL to the packager script.
PACKAGER_SCRIPT := .release/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh

# Defines a rule to build the database for a specific product. The rule will
# be added to the target for the named product.
#
# Usage: $(eval $(call GEN_RULE,$(product),$(database)))
define GEN_RULE
$(1): LibRPMedia-$(1)$(2)-1.0.lua

LibRPMedia-$(1)$(2)-1.0.lua: .FORCE
	@echo Generating $$(@)...
	@$(LUA) Exporter/Exporter.lua \
		--database $(2) \
		--interface-version $($(1)_INTERFACE_VERSION) \
		--product-id $($(1)_PRODUCT_ID) \
		--region $(REGION) \
		--template Templates/$(2).lua \
		$(EXPORTER_OPTIONS) \
		$($(1)_EXPORTER_OPTIONS) > $$(@)
endef

.PHONY: build release $(PRODUCTS)
.FORCE:

build: $(PRODUCTS)

$(foreach product,$(PRODUCTS),\
	$(foreach database,$(DATABASES),\
		$(eval $(call GEN_RULE,$(product),$(database)))\
	)\
)

release: build $(PACKAGER_SCRIPT)
	@$(PACKAGER_SCRIPT) -d -l
	@$(PACKAGER_SCRIPT) -d -l -g 1.13.2

$(PACKAGER_SCRIPT): .FORCE
	@echo Fetching packager script...
	@mkdir -p $(@D)
	@curl -s $(PACKAGER_SCRIPT_URL) > $(@)
