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
local csv = require "csv";
local lfs = require "lfs";
local lsqlite3 = require "lsqlite3";

function tostringall(...)
    if select("#", ...) == 0 then
        return;
    end

    return tostring((...)), tostringall(select(2, ...));
end

function strjoin(delimiter, ...)
    return table.concat({ tostringall(...) }, delimiter, 1, select("#", ...));
end

function errorf(format, ...)
    error(string.format(format, ...), 2);
end

function tunique(t)
    -- Assumes `t` is a sorted table, since this will only strip consecutive
    -- unique values.

    local j = 1;

    for i = 1, #t do
        local v = t[i];

        if t[j] ~= v then
            j = j + 1;
        end

        t[i] = nil;
        t[j] = v;
    end

    return t;
end

local reprEscapes = {}
for i = 0, 31 do reprEscapes[string.char(i)] = string.format("\\%03d", i); end
for i = 127, 255 do reprEscapes[string.char(i)] = string.format("\\%03d", i); end
reprEscapes["\0"] = "\\0";
reprEscapes["\a"] = "\\a";
reprEscapes["\b"] = "\\b";
reprEscapes["\f"] = "\\f";
reprEscapes["\n"] = "\\n";
reprEscapes["\r"] = "\\r";
reprEscapes["\t"] = "\\t";
reprEscapes["\v"] = "\\v";

function repr(v, opts)
    local tv = type(v);

    if tv == "nil" then
        return "nil";
    elseif tv == "boolean" then
        return v and "true" or "false";
    elseif tv == "number" then
        return string.format(opts and opts.numberformat or "%.14g", v);
    elseif tv == "string" then
        v = string.format(opts and opts.stringformat or "%q", v);
        if not opts or not opts.binarystring then
            v = string.gsub(v, "[^\032-\126]", reprEscapes);
        end

        return v;
    elseif tv == "table" then
        local buf    = { "{" };
        local numarr = 0;

        for k, u in pairs(v) do
            if numarr ~= nil and k == (numarr + 1) then
                -- Consecutive array-like entries are written as such.
                numarr = numarr + 1;
                buf[#buf + 1] = repr(u, opts);
            else
                -- Otherwise write as a full `[key] = value` pair.
                numarr = nil;

                if type(k) == "string" and string.find(k, "^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    -- Compact key without brackets.
                    buf[#buf + 1] = k;
                    buf[#buf + 1] = "=";
                else
                    buf[#buf + 1] = "[";
                    buf[#buf + 1] = repr(k, opts);
                    buf[#buf + 1] = "]=";
                end

                buf[#buf + 1] = repr(u, opts);

            end

            if next(v, k) then
                buf[#buf + 1] = ",";
            end
        end

        buf[#buf + 1] = "}";
        return table.concat(buf);
    else
        return "nil"; -- Unsupported type.
    end
end

function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;
        end
    end

    return object;
end

function CreateFromMixins(...)
    return Mixin({}, ...)
end

function CreateAndInitFromMixin(mixin, ...)
    local object = CreateFromMixins(mixin);
    object:Init(...);
    return object;
end

function GetOption(name)
    for _, option in ipairs(arg) do
        local optname, optvalue = string.match(option, "^--(%w+)=(.+)$");

        if optname == name then
            return optvalue;
        end
    end

    return nil;
end

--
-- Encoding Utilities
--

function BinaryIndex(t, v, i, j)
    local l = i or 1;
    local r = (j or #t) + 1;

    while l < r do
        local m = math.floor((l + r) / 2);
        if t[m] < v then
            l = m + 1;
        else
            r = m;
        end
    end

    return l;
end

function BinarySearch(t, v, i, j)
    local l = i or 1;
    local r = j or #t;

    while l <= r do
        local m = math.floor((l + r) / 2);
        if t[m] < v then
            l = m + 1;
        elseif t[m] > v then
            r = m - 1;
        else
            return m;
        end
    end

    return nil;
end

function GetCommonPrefixLength(a, b)
    if a == b then
        return #a;
    end

    local offset = 1;
    local length = math.min(#a, #b);

    -- The innards of the loop are manually unrolled so we can minimize calls.
    while offset <= length do
        local a1, a2, a3, a4, a5, a6, a7, a8 = string.byte(a, offset, offset + 7);
        local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(b, offset, offset + 7);

        if a1 ~= b1 then
            return offset - 1;
        elseif a2 ~= b2 then
            return offset;
        elseif a3 ~= b3 then
            return offset + 1;
        elseif a4 ~= b4 then
            return offset + 2;
        elseif a5 ~= b5 then
            return offset + 3;
        elseif a6 ~= b6 then
            return offset + 4;
        elseif a7 ~= b7 then
            return offset + 5;
        elseif a8 ~= b8 then
            return offset + 6;
        end

        offset = offset + 8;
    end

    return offset - 1;
end

function GenerateStringDeltas(strings)
    local deltas = {};

    for i = 1, #strings do
        local previous = strings[i - 1] or "";
        local current = strings[i];
        local commonLength = GetCommonPrefixLength(previous, current);

        table.insert(deltas, commonLength);
        table.insert(deltas, string.sub(current, commonLength + 1));
    end

    return deltas;
end

--
-- Log Utilities
--

function WriteLog(...)
    local date = string.format("\27[90m%s\27[0m", os.date("%H:%M:%S"));
    io.stderr:write(strjoin(" ", date, ...), "\n");
end

function WriteError(...)
    local date = string.format("\27[91m%s\27[0m", os.date("%H:%M:%S"));
    io.stderr:write(strjoin(" ", date, ...), "\n");
end

--
-- File Utilities
--

function WithClosable(closable, continuationFunc, ...)
    local function OnReturn(ok, ...)
        closable:close();

        if not ok then
            error((...), 2);
        else
            return ...;
        end
    end

    return OnReturn(pcall(continuationFunc, closable, ...));
end

function IsFile(filePath)
    return lfs.attributes(filePath, "mode") == "file";
end

function IsDirectory(filePath)
    return lfs.attributes(filePath, "mode") == "directory";
end

function OpenFile(path, mode)
    local file, err = io.open(path, mode);

    if not file then
        errorf("Failed to open file %s: %s", path, err);
    else
        return file;
    end
end

function ReadFile(path)
    return WithClosable(OpenFile(path, "rb"), function(file)
        local data, err = file:read("*a");

        if not data then
            errorf("Failed to read file %s: %s", path, err);
        else
            return data;
        end
    end);
end

function WriteFile(data, path)
    return WithClosable(OpenFile(path, "w+"), function(file)
        local written, err = file:write(data);

        if not written then
            errorf("Failed to write file %s: %s", path, err);
        else
            return written;
        end
    end);
end

--
-- Build Utilities
--

function OpenUrl(url)
    local stream, err = io.popen(string.format("curl -sfL %q", url));

    if not stream then
        errorf("Failed to open stream for %s: %s", url, err);
    else
        return stream;
    end
end

function DownloadUrl(url, path)
    local command = string.format("curl -sfL %q -o %q", url, path);
    local status = os.execute(command);

    if status ~= 0 then
        errorf("Failed to execute command (exit code %d): %s", status, command);
    else
        return true;
    end
end

function GetCacheDirectory()
    return os.getenv("LUACASC_CACHE") or ".cache";
end

function GetBuildInfo(product, region)
    product = product or "wow";
    region = region or "us";

    WriteLog("Fetching build information for", product);

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

function GetTextureDimensions(store, contentHash)
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

function GetIconWidth(store, contentHash)
    WriteLog("Fetching icon dimensions for:", contentHash);

    local dimensions = GetTextureDimensions(store, contentHash);
    return dimensions.w;
end

function GetIconHeight(store, contentHash)
    -- Don't log here since the query executes both functions for each file.
    local dimensions = GetTextureDimensions(store, contentHash);
    return dimensions.h;
end

function GetMusicDuration(store, contentHash)
    WriteLog("Fetching duration for music file:", contentHash);

    -- A bit of a hack is needed to get the path to the LuaCasc cached file
    -- path as seen below...

    if not store:readFileByContentHash(contentHash) then
        return 0;  -- Failed to grab the file.
    end

    local cache = GetCacheDirectory();
    local keys = store.encoding:getEncodingHash(#contentHash == 16 and contentHash or cascbin.to_bin(contentHash));
    local path;

	for _ = 1, keys and 2 or 0 do
        for i = 1, #keys do
            local keyhash = #keys[i] == 32 and keys[i]:lower() or cascbin.to_hex(keys[i]);
            local keypath = string.format("%s/file.%s", cache, keyhash);

            if IsFile(keypath) then
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

    return WithClosable(pipe, function()
        local data = assert(pipe:read("*a"));
        return tonumber(string.match(data, "[^%s]+")) or 0;
    end);
end

function GetTactKeys()
    local url = "https://raw.githubusercontent.com/wowdev/TACTKeys/master/WoW.txt";
    local path = string.format("%s/tactkeys.csv", GetCacheDirectory());

    WriteLog("Downloading encryption keys:", url);

    if not DownloadUrl(url, path) then
        errorf("Failed to download encryption keys: %s", url);
    end

    local headers = false;
    local convert = false;
    local delim = " ";
    local reader = assert(csv.reader(path, headers, convert, delim));
    local tactkeys = {};

    for row in reader:rows() do
        local lookup = row[1];
        local hexkey = row[2];

        tactkeys[lookup] = hexkey;
    end

    return tactkeys;
end

function FetchDatabase(name, build)
    local url = string.format("https://wago.tools/db2/%s/csv?build=%s", name, build.version);
    local path = string.format("%s/%s@%s.csv", GetCacheDirectory(), name, build.bkey);

    if not IsFile(path) then
        WriteLog("Downloading client database:", url);

        if not DownloadUrl(url, path) then
            errorf("Failed to download database: %s", url);
        end
    else
        WriteLog("Using cached client database:", path);
    end

    return path;
end

function FetchListfile(store, build)
    local url = string.format("https://raw.githubusercontent.com/wowdev/wow-listfile/master/community-listfile.csv");
    local path = string.format("%s/listfile@%s.csv", GetCacheDirectory(), build.bkey);

    if not IsFile(path) then
        WriteLog("Downloading listfile:", url);

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
    else
        WriteLog("Using cached listfile:", path);
    end

    return path;
end

function OpenCascStore(build, locale)
    local cacheDir = GetCacheDirectory();

    if not IsDirectory(cacheDir) then
        assert(lfs.mkdir(cacheDir));
    end

    return assert(casc.open({
        bkey = build.bkey,
        ckey = build.ckey,
        cdn = build.cdn,
        locale = locale or "US",
        cache = cacheDir,
        cacheFiles = true,
        zerofillEncryptedChunks = true,
        log = function(_, text) if text ~= "Ready" then WriteLog(text); end end,
        keys = GetTactKeys(),
    }));
end

--
-- SQL Utilities
--

function OpenDatabase(path)
    return CreateAndInitFromMixin(SqlDatabaseMixin, lsqlite3.open(path));
end

--
-- SqlDatabaseMixin
--
-- Simple wrapper around an lsqlite3 database handle that improves ease of
-- use and error handling.
--

SqlDatabaseMixin = {};

function SqlDatabaseMixin:Init(db, ...)
    self.db = self:CheckTruthyWithMessage(db, ...);
end

function SqlDatabaseMixin:ExecuteScriptFile(filePath)
    local script = ReadFile(filePath);
    return self:CheckOk(self.db:exec(script));
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

    return self:CheckOk(self.db:exec(query));
end

function SqlDatabaseMixin:NamedRows(query)
    return self:CheckTruthy(self.db:nrows(query));
end

-- Extensions

function SqlDatabaseMixin:LoadExtension(extension, entrypoint)
    return self:CheckTruthy(self.db:load_extension(extension, entrypoint));
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

    return self:CheckTruthy(self.db:create_function(name, narg, EntryPoint));
end

-- Error handling helpers

function SqlDatabaseMixin:GetLastError()
    return self.db:error_message();
end

function SqlDatabaseMixin:CheckTruthy(value, ...)
    if not value then
        error((...), 2);
    end

    return value, ...;
end

function SqlDatabaseMixin:CheckTruthyWithMessage(value, ...)
    if not value then
        error(select(2, ...), 2);
    end

    return value, ...;
end

function SqlDatabaseMixin:CheckDone(result, ...)
    if result ~= lsqlite3.DONE then
        error(self:GetLastError(), 2);
    end

    return ...;
end

function SqlDatabaseMixin:CheckOk(result, ...)
    if result ~= lsqlite3.OK then
        error(self:GetLastError(), 2);
    end

    return ...;
end

--
-- Template Utilities
--

function WriteTemplate(sourcePath, outputPath, env)
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
