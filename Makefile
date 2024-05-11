PACKAGER_URL := https://raw.githubusercontent.com/BigWigsMods/packager/eca4e176cd6ae5404c66bef5c11c08200a458400/release.sh
PRODUCTS := wow_classic wow_classic_beta wow_classic_ptr wow_classic_era wow_classic_era_ptr wow wow_beta wowt wowxptr

.PHONY: all check dist deps libs $(PRODUCTS)
.DEFAULT: all
.DELETE_ON_ERROR:
.FORCE:

all: wow wow_classic wow_classic_era

check:
	luacheck -q $(shell git ls-files '*.lua' ':!:Exporter/Libs/')

deps: Exporter/Libs/sqlite3/csv.so

dist:
	curl -s $(PACKAGER_URL) | bash -s -- -dS

libs:
	curl -s $(PACKAGER_URL) | bash -s -- -cdlz
	cp -aTv .release/LibRPMedia/Libs Libs

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
	lrpm-export --product=$@ --manifest=Exporter/Data/TWW.lua --database=LibRPMediaData_TWW.lua

wowt: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

wowxptr: deps
	lrpm-export --product=$@ --manifest=Exporter/Data/Mainline.lua --database=LibRPMediaData_Mainline.lua

Exporter/Libs/sqlite3/csv.so: Exporter/Libs/sqlite3/csv.c
	$(CC) -fPIC -O2 -shared -Wl,--no-as-needed -lsqlite3 $< -o $@
