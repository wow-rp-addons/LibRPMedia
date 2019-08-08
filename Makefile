# Region to use when querying the CDN.
REGION ?= eu

# CDN product IDs for version querying. Prefix these with a product name.
Classic_PRODUCT_ID ?= wow_classic
Retail_PRODUCT_ID ?= wow

# Path to a Lua interpreter.
LUA ?= lua
LUACHECK ?= luacheck

# Directory where releases and scripts are downoaded to.
RELEASE_DIR := .release
# Directory where things will be cached.
CACHE_DIR := .cache

# Path and URL to the packager script.
PACKAGER_SCRIPT := $(RELEASE_DIR)/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh

.PHONY: check build classic release retail test
.FORCE:

build: classic retail

check:
	@$(LUACHECK) . -q

classic: LibRPMedia-Classic-1.0.lua

retail: LibRPMedia-Retail-1.0.lua

release: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -l

test:
	@echo Testing Classic database...
	@$(LUA) Tests/Tests.lua --interface $(Classic_INTERFACE_VERSION)
	@echo Testing Retail database...
	@$(LUA) Tests/Tests.lua --interface $(Retail_INTERFACE_VERSION)

LibRPMedia-%-1.0.lua: $(CACHE_DIR) .FORCE
	@echo Generating $(@)...
	@LUACASC_CACHE=$(PWD)/$(CACHE_DIR) $(LUA) Exporter/Exporter.lua \
		--config Exporter/Config.$(*).lua \
		--manifest LibRPMedia-$(*)-1.0.manifest \
		--output $(@) \
		--product $($(*)_PRODUCT_ID) \
		--region $(REGION) \
		--template Exporter/Template.$(*).lua

$(PACKAGER_SCRIPT): $(RELEASE_DIR) .FORCE
	@echo Fetching packager script...
	@curl -Ls $(PACKAGER_SCRIPT_URL) > $(@)

$(RELEASE_DIR) $(CACHE_DIR):
	@mkdir $(@)
