#!/usr/bin/env lua

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
local casc = require "casc";
local cascbin = require "casc.bin";
local lfs = require "lfs";
local lsqlite3 = require "lsqlite3";

local function GetOption(name)
    for _, option in ipairs(arg) do
        local optname, optvalue = string.match(option, "^--(%w+)=(.+)$");

        if optname == name then
            return optvalue;
        end
    end

    return nil;
end

local CACHE_DIR = os.getenv("LUACASC_CACHE") or ".cache";
local REGION = os.getenv("LUACASC_REGION") or "us";
local PRODUCT = GetOption("product") or "wow";
local MANIFEST_PATH = GetOption("manifest") or "Manifest.lua";
local DATABASE_PATH = GetOption("database") or "Database.lua";
local LOCALE = os.getenv("LUACASC_LOCALE") or "US";

local function assertv(result, ...)
    if not result then
        error("assertion failure: " .. tostring((...)), 2);
    end

    return result, ...;
end

local function tostringall(...)
    if select("#", ...) == 0 then
        return;
    end

    return tostring((...)), tostringall(select(2, ...));
end

local function strjoin(delimiter, ...)
    return table.concat({ tostringall(...) }, delimiter);
end

local function errorf(format, ...)
    error(string.format(format, ...), 2);
end

local function log(...)
    local date = string.format("\27[90m%s\27[0m", os.date("%H:%M:%S"));
    io.stderr:write(strjoin(" ", date, ...), "\n");
end

local REPR_ESCAPES = {}
for i = 0, 31 do REPR_ESCAPES[string.char(i)] = string.format("\\%03d", i); end
for i = 127, 255 do REPR_ESCAPES[string.char(i)] = string.format("\\%03d", i); end
REPR_ESCAPES["\0"] = "\\0";
REPR_ESCAPES["\a"] = "\\a";
REPR_ESCAPES["\b"] = "\\b";
REPR_ESCAPES["\f"] = "\\f";
REPR_ESCAPES["\n"] = "\\n";
REPR_ESCAPES["\r"] = "\\r";
REPR_ESCAPES["\t"] = "\\t";
REPR_ESCAPES["\v"] = "\\v";

local function repr(v)
    local tv = type(v);

    if tv == "nil" then
        return "nil";
    elseif tv == "boolean" then
        return v and "true" or "false";
    elseif tv == "number" then
        return string.format("%.14g", v);
    elseif tv == "string" then
        v = string.gsub(string.format("%q", v), "[^\032-\126]", REPR_ESCAPES);
        return v;
    elseif tv == "table" then
        local buf    = { "{" };
        local numarr = 0;

        for k, u in pairs(v) do
            if numarr ~= nil and k == (numarr + 1) then
                -- Consecutive array-like entries are written as such.
                numarr = numarr + 1;
                buf[#buf + 1] = repr(u);
            else
                -- Otherwise write as a full `[key] = value` pair.
                numarr = nil;

                if type(k) == "string" and string.find(k, "^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    -- Compact key without brackets.
                    buf[#buf + 1] = k;
                    buf[#buf + 1] = "=";
                else
                    buf[#buf + 1] = "[";
                    buf[#buf + 1] = repr(k);
                    buf[#buf + 1] = "]=";
                end

                buf[#buf + 1] = repr(u);

            end

            if next(v, k) then
                buf[#buf + 1] = ",";
            end
        end

        buf[#buf + 1] = "}";
        return table.concat(buf);
    else
        return "nil";
    end
end

local function BinaryIndex(table, value, i, j)
    local floor = math.floor;

    local l = i or 1;
    local r = j or #table;

    while l <= r do
        local m = floor((l + r) / 2);
        if table[m] < value then
            l = m + 1;
        elseif table[m] > value then
            r = m - 1;
        else
            return m;
        end
    end

    return l;
end

local function OpenFile(path, mode)
    local file, err = io.open(path, mode);

    if not file then
        errorf("Failed to open file %s: %s", path, err);
    else
        return file;
    end
end

local function ReadFile(path, mode)
    local file = OpenFile(path, mode or "rb");
    local data, err = file:read("*a");
    file:close();

    if not data then
        errorf("Failed to read file %s: %s", path, err);
    else
        return data;
    end
end

local function OpenUrl(url)
    local stream, err = io.popen(string.format("curl -sfL %q", url));

    if not stream then
        errorf("Failed to open stream for %s: %s", url, err);
    else
        return stream;
    end
end

local function DownloadUrl(url, path)
    local command = string.format("curl -sfL %q -o %q", url, path);
    local status = os.execute(command);

    if status ~= 0 then
        errorf("Failed to execute command (exit code %d): %s", status, command);
    else
        return true;
    end
end

local function GetBuildInfo(product, region)
    product = product or "wow";
    region = region or "us";

    log("Fetching build information for", product);

    local url = string.format("ribbit://%s.version.battle.net:1119/%s", region, product);
    local info = select(5, assert(casc.cdnbuild(url, region)));

    return {
        bkey = info.buildKey,
        number = info.build,
        cdn = info.cdnBase,
        ckey = info.cdnKey,
        version = info.version,
    };
end

local function GetTextureDimensions(store, contentHash)
    local data, err = store:readFileByContentHash(contentHash);

    if not data then
        return nil, "failed to read file: " .. err;
    elseif type(data) ~= "string" then
        return nil, "blp data is incorrect type";
    elseif string.sub(data, 1, 4) ~= "BLP2" then
        return nil, "blp data has an invalid header";
    elseif #data < 20 then
        return nil, "blp data is too small";
    end

    -- The dimensions of the file can be found at these byte ranges.
    local w1, w2, w3, w4 = string.byte(data, 13, 16);
    local h1, h2, h3, h4 = string.byte(data, 17, 20);

    return {
        w = bit.bor(w1, bit.lshift(w2, 8), bit.lshift(w3, 16), bit.lshift(w4, 24)),
        h = bit.bor(h1, bit.lshift(h2, 8), bit.lshift(h3, 16), bit.lshift(h4, 24)),
    };
end

local function GetIconWidth(store, contentHash)
    log("Fetching icon dimensions for:", contentHash);

    local dimensions = GetTextureDimensions(store, contentHash);
    return dimensions and dimensions.w or 0;
end

local function GetIconHeight(store, contentHash)
    -- Don't log here since the query executes both functions for each file.
    local dimensions = GetTextureDimensions(store, contentHash);
    return dimensions and dimensions.h or 0;
end

local function GetMusicDuration(store, contentHash)
    log("Fetching duration for music file:", contentHash);

    -- A bit of a hack is needed to get the path to the luacasc cached file
    -- path as seen below...

    if not store:readFileByContentHash(contentHash) then
        return 0;  -- Failed to grab the file.
    end

    local keys = store.encoding:getEncodingHash(#contentHash == 16 and contentHash or cascbin.to_bin(contentHash));
    local path;

	for _ = 1, keys and 2 or 0 do
        for i = 1, #keys do
            local keyhash = #keys[i] == 32 and keys[i]:lower() or cascbin.to_hex(keys[i]);
            local keypath = string.format("%s/file.%s", CACHE_DIR, keyhash);

            if lfs.attributes(keypath, "mode") then
                path = keypath;
                break;
            end
        end

        if path then
            break;
        end
    end

    local command = "ffprobe -i %q -v quiet -show_entries format=duration -of csv=p=0";
    local pipe = assert(io.popen(string.format(command, path), "r"));
    local data = pipe:read("*a");
    pipe:close();

    return tonumber(string.match(data, "[^%s]+")) or 0;
end

local function GetTactKeys()
    local url = "https://raw.githubusercontent.com/wowdev/TACTKeys/master/WoW.txt";
    local path = string.format("%s/tactkeys.csv", CACHE_DIR);

    log("Downloading encryption keys:", url);

    if not DownloadUrl(url, path) then
        errorf("Failed to download encryption keys: %s", url);
    end

    local tactkeys = {};

    for row in OpenFile(path, "r"):lines() do
        local lookup, hexkey = string.match(row, "([0-9A-Fa-f]+) ([0-9A-Fa-f]+)");
        tactkeys[lookup] = hexkey;
    end

    return tactkeys;
end

local function FetchDatabase(name, build)
    local url = string.format("https://wago.tools/db2/%s/csv?build=%s", name, build.version);
    local path = string.format("%s/%s@%s.csv", CACHE_DIR, name, build.bkey);

    log("Downloading client database:", url);

    if not DownloadUrl(url, path) then
        errorf("Failed to download database: %s", url);
    end

    return path;
end

local function FetchListfile(store, build)
    local url = string.format("https://raw.githubusercontent.com/wowdev/wow-listfile/master/community-listfile.csv");
    local path = string.format("%s/community-listfile.csv", CACHE_DIR);

    log("Downloading listfile:", url);

    -- To minimize loading time we process the listfile to remove file
    -- extensions that we don't really care about, and to turn the
    -- delimiter to "," for use with the CSV virtual table. We also
    -- collect content hashes now since it's faster to write them to
    -- the listfile once than to recalculate them on each export.

    local rfile = OpenUrl(url);
    local wfile = OpenFile(path, "w+");

    -- We also include a header because we're CIVILIZED people.
    assert(wfile:write("Id,Path,ContentHash\n"));

    for line in rfile:lines() do
        local fileId, filePath = string.match(line, "^(%d+);(.+)$");

        local TEXTURE_PATTERN = "^interface/[^.]+%.blp$";
        local SOUND_PATTERN = "^sound/[^.]+%.[ogmp3]+$";

        if string.find(filePath, TEXTURE_PATTERN) or string.find(filePath, SOUND_PATTERN) then
            local contentHash = store:getFileContentHash(tonumber(fileId));

            if contentHash then
                assert(wfile:write(fileId, ",", string.format("%q", filePath), ",", contentHash, "\n"));
            end
        end
    end

    rfile:close();
    wfile:close();

    return path;
end

local function OpenCascStore(build, locale)
    if lfs.attributes(CACHE_DIR, "mode") ~= "directory" then
        assert(lfs.mkdir(CACHE_DIR));
    end

    return assert(casc.open({
        bkey = build.bkey,
        ckey = build.ckey,
        cdn = build.cdn,
        locale = locale or "US",
        cache = CACHE_DIR,
        cacheFiles = true,
        zerofillEncryptedChunks = true,
        log = function(_, text) if text ~= "Ready" then log(text); end end,
        keys = GetTactKeys(),
    }));
end

local SqlDatabaseMixin = {};

function SqlDatabaseMixin:Init(db, ...)
    self.db = assertv(db, ...);
end

function SqlDatabaseMixin:CheckResult(result, ...)
    if result ~= lsqlite3.OK then
        error(self.db:error_message(), 2);
    end

    return ...;
end

function SqlDatabaseMixin:ExecuteScriptFile(filePath)
    local script = ReadFile(filePath);
    return self:CheckResult(self.db:exec(script));
end

function SqlDatabaseMixin:LoadCsv(filePath, tableName, options)
    local args = {};
    table.insert(args, string.format("filename=%q", filePath));

    if options and options.columns then
        table.insert(args, string.format("columns=%d", options.columns));
    end

    if options and options.header then
        table.insert(args, "header=1");
    end

    if options and options.schema then
        table.insert(args, string.format("schema=%s", options.schema));
    end

    local basequery = [[CREATE VIRTUAL TABLE temp.%s USING csv(%s)]];
    local query = string.format(basequery, tableName, table.concat(args, ","));

    return self:CheckResult(self.db:exec(query));
end

function SqlDatabaseMixin:NamedRows(query)
    return assertv(self.db:nrows(query));
end

function SqlDatabaseMixin:LoadExtension(extension, entrypoint)
    return assertv(self.db:load_extension(extension, entrypoint));
end

function SqlDatabaseMixin:RegisterFunction(name, narg, func)
    local function EntryPoint(context, ...)
        local ok, result = pcall(func, ...);

        if not ok then
            return context:result_error(result);
        elseif type(result) == "number" then
            return context:result_number(result);
        elseif type(result) == "boolean" then
            return context:result_int(result and 1 or 0);
        elseif type(result) == "string" then
            return context:result_text(result);
        elseif result == nil then
            return context:result_null();
        else
            return context:result_error(string.format("unexpected return type from %s: %s", name, type(result)));
        end
    end

    return assertv(self.db:create_function(name, narg, EntryPoint));
end

local function OpenDatabase(path)
    local db = {};

    for k, v in pairs(SqlDatabaseMixin) do
        db[k] = v;
    end

    db:Init(lsqlite3.open(path));
    return db;
end

local function WriteTemplate(sourcePath, outputPath, env)
    local source = OpenFile(sourcePath, "rb");
    local output = OpenFile(outputPath, "w+");

    local buf = { "local _OUT = ..." };

    for line in source:lines() do
        if string.find(line, "^%-%-@") then
            buf[#buf + 1] = string.match(line, "^%-%-@%s*(.+)$");
        else
            local last = 1;
            for leading, expr, pos in string.gmatch(line, "(.-)%[%[(%b@@)%]%]()") do
                if leading ~= "" then
                    buf[#buf + 1] = "_OUT:write(" .. string.format("%q", leading) .. ")";
                end

                buf[#buf + 1] = "_OUT:write(" .. string.sub(expr, 2, -2) .. ")";
                last = pos;
            end

            buf[#buf + 1] = "_OUT:write(" .. string.format("%q", string.sub(line, last) .. "\n") .. ")";
        end
    end

    local chunk = assert(loadstring(table.concat(buf, "\n")));
    setfenv(chunk, setmetatable(env or {}, { __index = getfenv(0) }));
    chunk(output);

    source:close();
    output:close();

    return true;
end

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

local build = GetBuildInfo(PRODUCT, REGION);
local store = OpenCascStore(build, LOCALE);
local db = OpenDatabase(CACHE_DIR .. "/build.db");

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

log("Loading data sources...");

db:LoadCsv(FetchListfile(store, build), "CsvFile", { header = true });
db:LoadCsv(FetchDatabase("manifestinterfacedata", build), "CsvManifestInterfaceData", { header = true });
db:LoadCsv(FetchDatabase("soundkit", build), "CsvSoundKit", { header = true });
db:LoadCsv(FetchDatabase("soundkitentry", build), "CsvSoundKitEntry", { header = true });
db:LoadCsv(FetchDatabase("zonemusic", build), "CsvZoneMusic", { header = true });
db:LoadCsv(FetchDatabase("zoneintromusictable", build), "CsvZoneIntroMusic", { header = true });
db:LoadCsv(FetchDatabase("uitextureatlas", build), "CsvUiTextureAtlas", { header = true });
db:LoadCsv(FetchDatabase("uitextureatlaselement", build), "CsvUiTextureAtlasElement", { header = true });
db:LoadCsv(FetchDatabase("uitextureatlasmember", build), "CsvUiTextureAtlasMember", { header = true });

log("Preparing database...");

db:ExecuteScriptFile("Exporter/Export.sql");

--
-- Manifest Export
--

local icons = {};
local music = {};

do
    log("Building icon manifest...");

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
    log("Building music manifest...");

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
    log("Exporting build manifest...");

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
    log("Building icon database...");

    icondb.file = {};
    icondb.name = {};

    for index, info in ipairs(icons) do
        icondb.name[index] = info.name;
        icondb.file[index] = info.file;
    end
end

do
    log("Building music database...");

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
    log("Exporting build database...");

    WriteTemplate("Exporter/Database.lua.tpl", DATABASE_PATH, {
        build = build,
        version = build.version,
        expansion = (string.gsub(build.version, "^(%d+)\..+$", {
            ["1"] = "LE_EXPANSION_CLASSIC",
            ["2"] = "LE_EXPANSION_BURNING_CRUSADE",
            ["3"] = "LE_EXPANSION_WRATH_OF_THE_LICH_KING",
            ["4"] = "LE_EXPANSION_CATACLYSM",
            ["5"] = "LE_EXPANSION_MISTS_OF_PANDARIA",
            ["6"] = "LE_EXPANSION_WARLORDS_OF_DRAENOR",
            ["7"] = "LE_EXPANSION_LEGION",
            ["8"] = "LE_EXPANSION_BATTLE_FOR_AZEROTH",
            ["9"] = "LE_EXPANSION_SHADOWLANDS",
            ["10"] = "LE_EXPANSION_DRAGONFLIGHT",
            ["11"] = "LE_EXPANSION_11_0",
        })),
        db = {
            icons = {
                size = #icondb.file,
                file = repr(icondb.file),
                name = repr(icondb.name),
            },
            music = {
                size = #musicdb.file,
                file = repr(musicdb.file),
                name = repr(musicdb.name),
                time = repr(musicdb.time),
                namekeys = repr(musicdb.namekeys),
                namerows = repr(musicdb.namerows),
            },
        },
    });
end
