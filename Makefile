LUA ?= lua
LUACHECK ?= luacheck

PRODUCTS := wow_classic wow_classic_ptr wow_classic_era wow_classic_era_ptr wow wowbeta wowt
RELEASE_DIR := .release
EXPORTER_DIR := Exporter
MANIFEST_DIR := $(EXPORTER_DIR)/Data
EXPORTER_LIBS_DIR := $(EXPORTER_DIR)/Libs

export LUA_CPATH := ./$(EXPORTER_LIBS_DIR)/?/?.so;$(LUA_CPATH)
export LUA_PATH := ./$(EXPORTER_LIBS_DIR)/?.lua;./$(EXPORTER_LIBS_DIR)/?/init.lua;./$(EXPORTER_DIR)/?.lua;./Libs/?/?.lua;$(LUA_PATH)

PACKAGER_SCRIPT := $(RELEASE_DIR)/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/v2/release.sh

.PHONY: all check deps libs dist $(PRODUCTS)
.DEFAULT: all
.DELETE_ON_ERROR:
.FORCE:

all: wow wow_classic wow_classic_era

deps: $(EXPORTER_LIBS_DIR)/bit/bit.so \
	$(EXPORTER_LIBS_DIR)/casc/binc.so \
	$(EXPORTER_LIBS_DIR)/csv/csv.so \
	$(EXPORTER_LIBS_DIR)/lsqlite3/lsqlite3.so \
	$(EXPORTER_LIBS_DIR)/sqlite3/csv.so

check:
	@$(LUACHECK) -q $(shell git ls-files '*.lua' ':!:Exporter/Libs/')

libs: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -- -c -d -z
	@mkdir -p Libs/
	@cp -a .release/LibRPMedia/Libs/* Libs/

dist: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -l -S

wow_classic: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Wrath.lua --database=LibRPMedia-Wrath-1.0.lua

wow_classic_ptr: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Wrath.lua --database=LibRPMedia-Wrath-1.0.lua

wow_classic_era: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Classic.lua --database=LibRPMedia-Classic-1.0.lua

wow_classic_era_ptr: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Classic.lua --database=LibRPMedia-Classic-1.0.lua

wow: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Retail.lua --database=LibRPMedia-Retail-1.0.lua

wowbeta: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Retail.lua --database=LibRPMedia-Retail-1.0.lua

wowt: deps
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=$@ --manifest=$(MANIFEST_DIR)/Retail.lua --database=LibRPMedia-Retail-1.0.lua

$(EXPORTER_LIBS_DIR)/bit/bit.so: $(EXPORTER_LIBS_DIR)/bit/bit.c
	$(CC) -fPIC -O2 -I/usr/include/lua5.1 -shared -Wl,--no-as-needed -llua5.1 $< -o $@
$(EXPORTER_LIBS_DIR)/casc/binc.so: $(EXPORTER_LIBS_DIR)/casc/bin.c
	$(CC) -fPIC -O2 -I/usr/include/lua5.1 -shared -Wl,--no-as-needed -llua5.1 $< -o $@
$(EXPORTER_LIBS_DIR)/csv/csv.so: $(EXPORTER_LIBS_DIR)/csv/csv.c
	$(CC) -fPIC -O2 -I/usr/include/lua5.1 -shared -Wl,--no-as-needed -llua5.1 $< -o $@
$(EXPORTER_LIBS_DIR)/lsqlite3/lsqlite3.so: $(EXPORTER_LIBS_DIR)/lsqlite3/lsqlite3.c
	$(CC) -fPIC -O2 -I/usr/include/lua5.1 -shared -Wl,--no-as-needed -llua5.1 -lsqlite3 $< -o $@
$(EXPORTER_LIBS_DIR)/sqlite3/csv.so: $(EXPORTER_LIBS_DIR)/sqlite3/csv.c
	$(CC) -fPIC -O2 -shared -Wl,--no-as-needed -lsqlite3 $< -o $@

$(PACKAGER_SCRIPT): $(RELEASE_DIR) .FORCE
	@echo Fetching packager script...
	@curl -Ls $(PACKAGER_SCRIPT_URL) > $(@)

$(RELEASE_DIR):
	@mkdir $(@)
