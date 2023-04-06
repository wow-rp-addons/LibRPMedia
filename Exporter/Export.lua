--
-- This is free and unencumbered software released into the public domain.
--
-- Anyone is free to copy, modify, publish, use, compile, sell, or
-- distribute this software, either in source code form or as a compiled
-- binary, for any purpose, commercial or non-commercial, and by any
-- means.
--
-- In jurisdictions that recognize copyright laws, the author or authors
-- of this software dedicate any and all copyright interest in the
-- software to the public domain. We make this dedication for the benefit
-- of the public at large and to the detriment of our heirs and
-- successors. We intend this dedication to be an overt act of
-- relinquishment in perpetuity of all present and future rights to this
-- software under copyright law.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
-- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
--
-- For more information, please refer to <https://unlicense.org>
--

local bit = require "bit";

require "ExportUtil";

local REGION = os.getenv("LUACASC_REGION") or "us";
local PRODUCT = GetOption("product") or "wow";
local MANIFEST_PATH = GetOption("manifest") or "Manifest.lua";
local DATABASE_PATH = GetOption("database") or "Database.lua";
local LOCALE = os.getenv("LUACASC_LOCALE") or "US";

local LOAD_EXPRESSIONS = {
    ["wow_classic"] = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING",
    ["wow_classic_ptr"] = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING",
    ["wow_classic_beta"] = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING",
    ["wow_classic_era"] = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CLASSIC",
    ["wow_classic_era_ptr"] = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CLASSIC",
    ["wow"] = "WOW_PROJECT_ID == WOW_PROJECT_MAINLINE",
};

local function GetNormalizedAtlasName(atlasName)
    return string.lower(atlasName);
end

local function GetNormalizedFilePath(filePath)
    filePath = string.lower(filePath)
    filePath = string.gsub(filePath, "\\+", "/");

    return filePath;
end

local function GetNormalizedMusicName(musicName)
    -- Note: We strip trailing numbers off music names because this ensures
    --       that we can add our own when deduplicating names without then
    --       creating duplicates.

    musicName = string.lower(musicName)
    musicName = string.gsub(musicName, "[^a-z0-9]+", "_");
    musicName = string.gsub(musicName, "_+", "_");
    musicName = string.gsub(musicName, "^_+", "");
    musicName = string.gsub(musicName, "[0-9_]+$", "");

    return musicName;
end

local function IsIconFileExcluded(fileId, filePath, contentHash)
    -- Older version of the Devouring Plague icon that has weird naming.
    if fileId == 252996 then return true; end

    -- The following content hash is commonly used by invisible files; in
    -- Classic this is used by the inv_mace_18 and inv_staff_37 icons.
    if contentHash == "c45fe08ddc6ff6ec2a7233c88a360873" then return true; end

    -- The following "icons" aren't actually icon files.
    if string.find(filePath, "^interface/icons/6ih_ironhorde_stone_base_stonewalledge") then return true; end
    if string.find(filePath, "^interface/icons/6or_garrison_") then return true; end
    if string.find(filePath, "^interface/icons/cape_draenorcraftedcaster_d_") then return true; end
    if string.find(filePath, "^interface/icons/cape_draenorraid_") then return true; end
    if string.find(filePath, "^interface/icons/organic_reflect01") then return true; end
    if string.find(filePath, "^interface/icons/shield_draenorraid_") then return true; end
    if string.find(filePath, "^interface/icons/sword_1h_artifactfelomelorn_d_") then return true; end
    if string.find(filePath, "^interface/icons/sword_2h_ebonblade_b_") then return true; end
    if string.find(filePath, "^interface/icons/thrown_1h_") then return true; end

    -- Drop Blizzard branded icons.
    if string.find(filePath, "^interface/icons/mail_gmicon") then return true; end
    if string.find(filePath, "^interface/icons/ui_shop_bcv") then return true; end

    -- Default allow everything else.
    return false;
end

local function IsIconAtlasExcluded(atlasId, atlasName)
    -- TODO: Atlas support is disabled until we can actually support atlases.

    -- if string.find(atlasName, "^raceicon%-") then return false; end
    -- if string.find(atlasName, "^classicon%-") then return false; end

    -- Default reject everything else.
    return true;
end

local function IsMusicFileExcluded(fileId, filePath, contentHash)
    -- Exclude non-music event files.
    if fileId == 648283 then return true; end
    if fileId == 648285 then return true; end
    if fileId == 648287 then return true; end
    if fileId == 648289 then return true; end
    if fileId == 648293 then return true; end
    if fileId == 648295 then return true; end

    -- Permit explicit files.
    if fileId == 877254 then return false; end

    -- Ignore placeholder sounds.
    if string.find(filePath, "soundtest") then return true; end

    -- Some IGC files contain music, and typically match the below pattern.
    if string.find(filePath, "clientscene.*_musi?c?[_.].+") then return false; end
    if string.find(filePath, "rtc.*_musi?c?[_.].+") then return false; end

    -- Reject all other IGC files.
    if string.find(filePath, "^sound/music/[a-z/]*clientscene_") then return true; end
    if string.find(filePath, "^sound/music/[a-z/]*rtc_") then return true; end

    -- Permit all files within these directory/file paths only.
    if string.find(filePath, "^sound/music/") then return false; end
    if string.find(filePath, "^sound/mus_") then return false; end
    if string.find(filePath, "^sound/events/mus_") then return false; end
    if string.find(filePath, "^sound/.+music%.%w+$") then return false; end
    if string.find(filePath, "^sound/doodad/fx_bardluteperiodic_%d+%.ogg$") then return false; end

    -- Default reject everything else.
    return true;
end

local function IsMusicKitExcluded(soundKitId, musicName)
    -- Remove a few names that have Blizzard-internal tagging applied.
    if string.match(musicName, "^ph_") then return true; end
    if string.match(musicName, "^notused_") then return true; end
    if string.match(musicName, "_nu$") then return true; end
    if string.match(musicName, "_dep$") then return true; end
    if string.match(musicName, "^mus$") then return true; end
    if string.match(musicName, "test$") then return true; end
    if string.match(musicName, "test_kit$") then return true; end

    -- The garrison jukebox ones aren't all that helpfully named.
    if string.match(musicName, "garrisonjukebox") then return true; end

    -- Default allow everything else.
    return false;
end

local function GetNameForIconFile(fileId, filePath)
    return string.match(filePath, "interface/icons/([^.]+)%.blp$");
end

local function GetNameForIconAtlas(atlasId, atlasName)
    return atlasName;  -- Already normalized.
end

local function GetNameForMusic(fileId, soundKitId, musicName)
    -- Note: The input if it's a sound kit will already be normalized. If it's
    --       a path, we normalize the basename in the same way because this
    --       allows our Counted function below to apply a unique suffix since
    --       trailing numbers on normalized music names are stripped.

    if not soundKitId then
        -- Other clients use the basename, normalized with soundkit rules.
        local baseName = string.match(musicName, "^.+/([^%.]+)%.[ogmp3]+$");
        local normName = GetNormalizedMusicName(baseName);

        return normName;
    else
        -- The given name is from an associated sound kit.
        return musicName;
    end
end

local function GetCountedNameForMusic(fileId, soundKitId, musicName, duplicateIndex)
    musicName = GetNameForMusic(fileId, soundKitId, musicName);

    if duplicateIndex == 1 then
        return musicName;
    else
        return string.format("%s_%02d", musicName, duplicateIndex);
    end
end

local function Export()
    local build = GetBuildInfo(PRODUCT, REGION);
    local store = OpenCascStore(build, LOCALE);
    local db = OpenDatabase(GetCacheDirectory() .. "/build.db");

    db:LoadExtension("Exporter/Libs/sqlite3/csv.so");

    db:RegisterFunction("GetNameForMusic", 3, GetNameForMusic);
    db:RegisterFunction("GetCountedNameForMusic", 4, GetCountedNameForMusic);

    db:RegisterFunction("GetFileContentHash", 1, function(fileId) return store:getFileContentHash(fileId); end);
    db:RegisterFunction("GetIconHeight", 1, function(...) return GetIconHeight(store, ...); end);
    db:RegisterFunction("GetIconWidth", 1, function(...) return GetIconWidth(store, ...); end);
    db:RegisterFunction("GetMusicDuration", 1, function(...) return GetMusicDuration(store, ...); end);
    db:RegisterFunction("GetNameForIconAtlas", 2, GetNameForIconAtlas);
    db:RegisterFunction("GetNameForIconFile", 2, GetNameForIconFile);
    db:RegisterFunction("GetNormalizedAtlasName", 1, GetNormalizedAtlasName);
    db:RegisterFunction("GetNormalizedFilePath", 1, GetNormalizedFilePath);
    db:RegisterFunction("GetNormalizedMusicName", 1, GetNormalizedMusicName);
    db:RegisterFunction("IsIconAtlasExcluded", 2, IsIconAtlasExcluded);
    db:RegisterFunction("IsIconFileExcluded", 3, IsIconFileExcluded);
    db:RegisterFunction("IsMusicFileExcluded", 3, IsMusicFileExcluded);
    db:RegisterFunction("IsMusicKitExcluded", 2, IsMusicKitExcluded);

    WriteLog("Loading data sources...");

    db:LoadCsv(FetchListfile(store, build), "CsvFile", { header = true });
    db:LoadCsv(FetchDatabase("manifestinterfacedata", build), "CsvManifestInterfaceData", { header = true });
    db:LoadCsv(FetchDatabase("soundkit", build), "CsvSoundKit", { header = true });
    db:LoadCsv(FetchDatabase("soundkitentry", build), "CsvSoundKitEntry", { header = true });
    db:LoadCsv(FetchDatabase("zonemusic", build), "CsvZoneMusic", { header = true });
    db:LoadCsv(FetchDatabase("zoneintromusictable", build), "CsvZoneIntroMusic", { header = true });
    db:LoadCsv(FetchDatabase("uitextureatlas", build), "CsvUiTextureAtlas", { header = true });
    db:LoadCsv(FetchDatabase("uitextureatlaselement", build), "CsvUiTextureAtlasElement", { header = true });
    db:LoadCsv(FetchDatabase("uitextureatlasmember", build), "CsvUiTextureAtlasMember", { header = true });

    WriteLog("Preparing database...");

    db:ExecuteScriptFile("Exporter/Export.sql");

    --
    -- Manifest Export
    --

    local icons = {};
    local music = {};

    do
        WriteLog("Building icon manifest...");

        for row in db:NamedRows([[SELECT * FROM Icon]]) do
            table.insert(icons, {
                id = row.Id,
                file = row.FileId,
                hash = row.ContentHash,
                name = row.Name,
                size = { w = row.Width, h = row.Height },
                type = row.Type,
            });
        end
    end

    do
        WriteLog("Building music manifest...");

        local next, vm, row = db:NamedRows([[SELECT * FROM Music]]);
        row = next(vm, row);

        while row do
            local info = {
                file = row.FileId,
                hash = row.ContentHash,
                path = row.Path,
                time = row.Duration,
                name = {},
            };

            local fileId = row.FileId;

            repeat
                table.insert(info.name, row.Name);
                row = next(vm, row);
            until not row or row.FileId ~= fileId;

            table.insert(music, info);
        end
    end

    if MANIFEST_PATH then
        WriteLog("Exporting build manifest...");

        WriteTemplate("Exporter/Manifest.lua.tpl", MANIFEST_PATH, {
            build = build,
            icons = icons,
            music = music,
        });
    end

    --
    -- Database Export
    --

    local icondb = {};
    local musicdb = {};

    do
        WriteLog("Building icon database...");

        icondb.file = {};
        icondb.name = {};

        for index, info in ipairs(icons) do
            icondb.name[index] = info.name;
            icondb.file[index] = info.file;
        end
    end

    do
        WriteLog("Building music database...");

        musicdb.file = {};
        musicdb.name = {};
        musicdb.time = {};
        musicdb.namekeys = {};
        musicdb.namerows = {};

        for index, info in ipairs(music) do
            musicdb.file[index] = info.file;
            musicdb.name[index] = info.name[1];
            musicdb.time[index] = math.ceil(info.time);

            for _, name in ipairs(info.name) do
                local kidx = BinaryIndex(musicdb.namekeys, name);

                assert(musicdb.namekeys[kidx] ~= name);
                table.insert(musicdb.namekeys, kidx, name);
                table.insert(musicdb.namerows, kidx, index);
            end
        end
    end

    do
        WriteLog("Exporting build database...");

        WriteTemplate("Exporter/Database.lua.tpl", DATABASE_PATH, {
            build = build,
            version = build.version,
            loadexpr = LOAD_EXPRESSIONS[PRODUCT] or LOAD_EXPRESSIONS["wow"],
            db = {
                icons = {
                    size = #icondb.file,
                    file = repr(icondb.file),
                    name = repr(GenerateStringDeltas(icondb.name)),
                },
                music = {
                    size = #musicdb.file,
                    file = repr(musicdb.file),
                    name = repr(GenerateStringDeltas(musicdb.name)),
                    time = repr(musicdb.time),
                    namekeys = repr(GenerateStringDeltas(musicdb.namekeys)),
                    namerows = repr(musicdb.namerows),
                },
            },
        });
    end
end

xpcall(Export, function(...) WriteError("Export failed:", ...); end);
