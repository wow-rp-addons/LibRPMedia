# Path to a Lua interpreter.
LUA ?= lua
LUACHECK ?= luacheck

# Directory where releases and scripts are downoaded to.
RELEASE_DIR := .release

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
	@$(LUA) Tests/CLIRunner.lua --project WOW_PROJECT_CLASSIC
	@echo Testing Retail database...
	@$(LUA) Tests/CLIRunner.lua --project WOW_PROJECT_MAINLINE

LibRPMedia-%-1.0.lua: .FORCE
	@echo Generating $(@)...
	@$(LUA) Exporter/Main.lua --config Exporter/Config/$(*).lua

$(PACKAGER_SCRIPT): $(RELEASE_DIR) .FORCE
	@echo Fetching packager script...
	@curl -Ls $(PACKAGER_SCRIPT_URL) > $(@)

$(RELEASE_DIR):
	@mkdir $(@)
