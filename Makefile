LUA ?= lua5.1
LUACHECK ?= luacheck

PRODUCTS := classic classicptr retail retailbeta retailptr
RELEASE_DIR := .release
EXPORTER_DIR := Exporter
MANIFEST_DIR := $(EXPORTER_DIR)/Data
EXPORTER_LIBS_DIR := $(EXPORTER_DIR)/Libs

LUA_CPATH := ./$(EXPORTER_LIBS_DIR)/?/?.so;$(LUA_CPATH)
LUA_PATH := ./$(EXPORTER_LIBS_DIR)/?.lua;./$(EXPORTER_LIBS_DIR)/?/init.lua;./$(EXPORTER_DIR)/?.lua;./Libs/?/?.lua;$(LUA_PATH)

PACKAGER_SCRIPT := $(RELEASE_DIR)/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh

.PHONY: all check libs dist $(PRODUCTS)
.DEFAULT: all
.DELETE_ON_ERROR:
.FORCE:

all: classic retail

check:
	@$(LUACHECK) . -q

libs: $(EXPORTER_LIBS_DIR)/bit/bit.so \
	$(EXPORTER_LIBS_DIR)/casc/binc.so \
	$(EXPORTER_LIBS_DIR)/csv/csv.so \
	$(EXPORTER_LIBS_DIR)/lsqlite3/lsqlite3.so \
	$(EXPORTER_LIBS_DIR)/sqlite3/csv.so

dist: $(PACKAGER_SCRIPT)
	@bash $(PACKAGER_SCRIPT) -l

classic: libs
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=wow_classic --manifest=$(MANIFEST_DIR)/Classic.lua --database=LibRPMedia-ClassicData.lua
classicptr: libs
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=wow_classic_ptr --manifest=$(MANIFEST_DIR)/ClassicPTR.lua --database=LibRPMedia-ClassicData.lua
retail: libs
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=wow --manifest=$(MANIFEST_DIR)/Retail.lua --database=LibRPMedia-RetailData.lua
retailbeta: libs
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=wowbeta --manifest=$(MANIFEST_DIR)/RetailBeta.lua --database=LibRPMedia-RetailData.lua
retailptr: libs
	@$(LUA) $(EXPORTER_DIR)/Export.lua --product=wowt --manifest=$(MANIFEST_DIR)/RetailPTR.lua --database=LibRPMedia-RetailData.lua

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
