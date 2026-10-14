packager_url := "https://raw.githubusercontent.com/BigWigsMods/packager/v2/release.sh"
cc := env("CC", "cc")

all: wow wow_anniversary wow_classic wow_classic_era

check:
    luacheck -q $(git ls-files '*.lua' ':!:Exporter/Libs/')

deps:
    if [ ! -f Exporter/Libs/sqlite3/csv.so ] || [ Exporter/Libs/sqlite3/csv.c -nt Exporter/Libs/sqlite3/csv.so ]; then \
        {{ cc }} -fPIC -O2 -shared -Wl,--no-as-needed -lsqlite3 Exporter/Libs/sqlite3/csv.c -o Exporter/Libs/sqlite3/csv.so || { rm -f Exporter/Libs/sqlite3/csv.so; exit 1; }; \
    fi

dist:
    curl -s {{ packager_url }} | bash -s -- -d

libs:
    curl -s {{ packager_url }} | bash -s -- -cdlz
    cp -aTv .release/LibRPMedia/Libs Libs

wow_classic: deps
    lrpm-export --product=wow_classic --manifest=Exporter/Data/Mists.lua --database=LibRPMediaData_Mists.lua

wow_classic_ptr: deps
    lrpm-export --product=wow_classic_ptr --manifest=Exporter/Data/Mists.lua --database=LibRPMediaData_Mists.lua

wow_classic_era: deps
    lrpm-export --product=wow_classic_era --manifest=Exporter/Data/Vanilla.lua --database=LibRPMediaData_Vanilla.lua

wow_classic_era_ptr: deps
    lrpm-export --product=wow_classic_era_ptr --manifest=Exporter/Data/Vanilla.lua --database=LibRPMediaData_Vanilla.lua

wow_anniversary: deps
    lrpm-export --product=wow_anniversary --manifest=Exporter/Data/TBC.lua --database=LibRPMediaData_TBC.lua

wow_anniversary_ptr: deps
    lrpm-export --product=wow_anniversary_ptr --manifest=Exporter/Data/TBC.lua --database=LibRPMediaData_TBC.lua

wow: deps
    lrpm-export --product=wow --manifest=Exporter/Data/Standard.lua --database=LibRPMediaData_Standard.lua

wow_beta: deps
    lrpm-export --product=wow_beta --manifest=Exporter/Data/Standard.lua --database=LibRPMediaData_Standard.lua

wowt: deps
    lrpm-export --product=wowt --manifest=Exporter/Data/Standard.lua --database=LibRPMediaData_Standard.lua

wowxptr: deps
    lrpm-export --product=wowxptr --manifest=Exporter/Data/Standard.lua --database=LibRPMediaData_Standard.lua

wowf: deps
    lrpm-export --product=wowf --manifest=Exporter/Data/Forever.lua --database=LibRPMediaData_Forever.lua

wow_classic_beta: deps
    lrpm-export --product=wow_classic_beta --manifest=Exporter/Data/Forever.lua --database=LibRPMediaData_Forever.lua
