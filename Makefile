PRODUCTS := wow_classic wow_classic_beta wow_classic_ptr wow_classic_era wow_classic_era_ptr wow wow_beta wowt wowxptr
RELEASE_DIR := .release

PACKAGER_SCRIPT := $(RELEASE_DIR)/release.sh
PACKAGER_SCRIPT_URL := https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh

.PHONY: all check dist deps libs $(PRODUCTS)
.DEFAULT: all
.DELETE_ON_ERROR:
.FORCE:

all: wow wow_classic wow_classic_era

check:
	luacheck -q $(shell git ls-files '*.lua' ':!:Exporter/Libs/')

deps: Exporter/Libs/sqlite3/csv.so

dist: $(PACKAGER_SCRIPT)
	bash $(PACKAGER_SCRIPT) -l -S

libs: $(PACKAGER_SCRIPT)
	bash $(PACKAGER_SCRIPT) -- -c -d -z
	mkdir -p Libs/
	cp -a .release/LibRPMedia/Libs/* Libs/

wow_classic: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Cata.lua --database=LibRPMediaData_Cata.lua

wow_classic_beta: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Cata.lua --database=LibRPMediaData_Cata.lua

wow_classic_ptr: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Cata.lua --database=LibRPMediaData_Cata.lua

wow_classic_era: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Vanilla.lua --database=LibRPMediaData_Vanilla.lua

wow_classic_era_ptr: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Vanilla.lua --database=LibRPMediaData_Vanilla.lua

wow: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

wow_beta: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

wowt: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

wowxptr: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

Exporter/Libs/sqlite3/csv.so: Exporter/Libs/sqlite3/csv.c
	$(CC) -fPIC -O2 -shared -Wl,--no-as-needed -lsqlite3 $< -o $@

$(PACKAGER_SCRIPT): $(RELEASE_DIR) .FORCE
	@echo Fetching packager script...
	@curl -Ls $(PACKAGER_SCRIPT_URL) -o $@

$(RELEASE_DIR):
	@mkdir $(@)
