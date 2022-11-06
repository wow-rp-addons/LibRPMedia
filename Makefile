# Path to a Lua interpreter.
LUA ?= lua
LUACHECK ?= luacheck

# Directory where releases and scripts are downoaded to.
RELEASE_DIR := .release

# Path and URL to the packager script.
PACKAGER_SCRIPT := $(RELEASE_DIR)/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/v2/release.sh

.PHONY: check wrath build classic release retail
.FORCE:

build: classic wrath retail

check:
	@$(LUACHECK) . -q

libs: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -- -c -d -z
	@mkdir -p Libs/
	@cp -a .release/LibRPMedia/Libs/* Libs/

classic: LibRPMedia-Classic-1.0.lua
wrath: LibRPMedia-Wrath-1.0.lua
retail: LibRPMedia-Retail-1.0.lua

release: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -l -S

LibRPMedia-%-1.0.lua: .FORCE
	@echo Generating $(@)...
	@$(LUA) Exporter/Main.lua --config Exporter/Config/$(*).lua

$(PACKAGER_SCRIPT): $(RELEASE_DIR) .FORCE
	@echo Fetching packager script...
	@curl -Ls $(PACKAGER_SCRIPT_URL) > $(@)

$(RELEASE_DIR):
	@mkdir $(@)
