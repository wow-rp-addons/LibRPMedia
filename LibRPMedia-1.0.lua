-- This file is licensed under the terms expressed in the LICENSE file.
assert(LibStub, "Missing dependency: LibStub");

local MODULE_MAJOR = "LibRPMedia-1.0";
local MODULE_MINOR = 2;

local LibRPMedia = LibStub:NewLibrary(MODULE_MAJOR, MODULE_MINOR);
if not LibRPMedia then
    return;
end

-- Dependencies.
local LibDeflate = LibStub:GetLibrary("LibDeflate");

-- Upvalues.
local error = error;
local floor = math.floor;
local loadstring = loadstring;
local min = math.min;
local nop = nop;
local pairs = pairs;
local rawset = rawset;
local setfenv = setfenv;
local setmetatable = setmetatable;
local strbyte = string.byte;
local strchar = string.char;
local strfind = string.find;
local strformat = string.format;
local strgsub = string.gsub;
local strjoin = string.join;
local strlower = string.lower;
local tconcat = table.concat;
local type = type;
local xpcall = xpcall;

local CallErrorHandler = CallErrorHandler;

-- Local declarations.
local AssertType;
local BinarySearch;
local BinarySearchPrefix;
local CheckType;
local GetCommonPrefixLength;
local IterMusicFiles;
local IterMusicFilesByPattern;
local IterMusicFilesByPrefix;
local NormalizeMusicName;

-- Error constants.
local ERR_DATA_DECOMPRESS_FAILED = "LibRPMedia: Error decompressing data.";
local ERR_DATA_NOT_HYDRATABLE = "LibRPMedia: Type %s cannot be hydrated.";
local ERR_DATABASE_NOT_FOUND = "LibRPMedia: Database %q was not found.";
local ERR_DATABASE_UNSIZED = "LibRPMedia: Database %q has no size.";
local ERR_INVALID_ARG_TYPE = "LibRPMedia: Argument %q is %s, expected %s";
local ERR_INVALID_SEARCH_METHOD = "LibRPMedia: Invalid search method: %q";

--- Music Database API

--- Returns true if music data is presently loaded.
--
--  If this returns false, most other functions will error.
function LibRPMedia:IsMusicDataLoaded()
    return self:IsDatabaseRegistered("music");
end

--- Returns the number of music files in the database.
function LibRPMedia:GetNumMusicFiles()
    return self:GetNumDatabaseEntries("music");
end

--- Returns the file ID for a music file based on its sound kit name, or
--  file path.
--
--  If no match is found, nil is returned.
function LibRPMedia:GetMusicFileByName(musicName)
    AssertType(musicName, "musicName", "string");

    musicName = NormalizeMusicName(musicName);

    local musicIndex = self:GetMusicIndexByName(musicName);
    if not musicIndex then
        return nil;
    end

    return self:GetMusicFileByIndex(musicIndex);
end

--- Returns the file ID for a music file based on its index, in the range
--  1 through GetNumMusicFiles.
--
--  If no file is found, nil is returned.
function LibRPMedia:GetMusicFileByIndex(musicIndex)
    AssertType(musicIndex, "musicIndex", "number");

    local music = self:GetDatabase("music");
    return music.data.file[musicIndex];
end

--- Returns the duration of a music file from its file ID, if known. The
--  value returned is in fractional seconds.
--
--  If no file is found, or no duration information is available, this will
--  return 0.
function LibRPMedia:GetMusicFileDuration(musicFile)
    AssertType(musicFile, "musicFile", "number");

    local music = self:GetDatabase("music");
    local musicIndex = self:GetMusicIndexByFile(musicFile);
    if not musicIndex then
        return 0;
    end

    return music.data.time[musicIndex] or 0;
end

--- Returns the index of a music file from its file ID. If the given file
--  ID is not present in the database, nil is returned.
function LibRPMedia:GetMusicIndexByFile(musicFile)
    AssertType(musicFile, "musicFile", "number");

    local music = self:GetDatabase("music");
    return BinarySearch(music.data.file, musicFile);
end

--- Returns the index of a music file from its name. If no matching name
--  is found in the database, nil is returned.
function LibRPMedia:GetMusicIndexByName(musicName)
    AssertType(musicName, "musicName", "string");

    musicName = NormalizeMusicName(musicName);

    local music = self:GetDatabase("music");
    local names = music.index.name;
    return names.row[BinarySearch(names.key, musicName)];
end

--- Returns a string name for a music file based on its index, in the range
--  1 through GetNumMusicFiles.
--
--  While a music file may have multiple names in the form of sound kit
--  names or file paths, this function will return only one predefined name.
--
--  If no name is found, nil is returned.
function LibRPMedia:GetMusicNameByIndex(musicIndex)
    AssertType(musicIndex, "musicIndex", "number");

    local music = self:GetDatabase("music");
    return music.data.name[musicIndex];
end

--- Returns a string name for a music file based on its file ID.
--
--  If no name is found, nil is returned.
function LibRPMedia:GetMusicNameByFile(musicFile)
    AssertType(musicFile, "musicFile", "number");

    local musicIndex = self:GetMusicIndexByFile(musicFile);
    if not musicIndex then
        return nil;
    end

    return self:GetMusicNameByIndex(musicIndex);
end

--- Returns an iterator for accessing all music files in the database
--  matching the given name.
--
--  The iterator will return triplet of file index, file ID, and file name.
--
--  The order of which files are returned by this iterator is not guaranteed.
function LibRPMedia:FindMusicFiles(musicName, options)
    AssertType(musicName, "musicName", "string");
    AssertType(options, "options", "table", "nil");

    -- If the search space is empty then everything matches; the iterator
    -- from FindAllMusic files is *considerably* more efficient.
    if not musicName or musicName == "" then
        return self:FindAllMusicFiles();
    end

    -- Default the options and extract them.
    local optMethod = options and options.method or "prefix";

    -- Grab the database and search appropriately.
    local music = self:GetDatabase("music");
    if optMethod == "prefix" then
        return IterMusicFilesByPrefix(music, musicName);
    elseif optMethod == "substring" then
        musicName = NormalizeMusicName(musicName);
        return IterMusicFilesByPattern(music, musicName, true);
    elseif optMethod == "pattern" then
        -- We won't normalize a pattern because it's a bit tricky.
        return IterMusicFilesByPattern(music, musicName, false);
    else
        error(strformat(ERR_INVALID_SEARCH_METHOD, optMethod), 2);
    end
end

--- Returns an iterator for accessing all music files in the database.
--  The iterator will return triplet of file index, file ID, and file name.
--
--  The order of which files are returned by this iterator is not guaranteed.
function LibRPMedia:FindAllMusicFiles()
    local music = self:GetDatabase("music");
    return IterMusicFiles(music);
end

--- Unpacks and decompresses music data within the database. This may cause
--  a momentary lag spike in the client.
function LibRPMedia:UnpackMusicData()
    -- Access anything that might be compressed here.
    local music = self:GetDatabase("music");
    nop(music.data);
    nop(music.index.name);

    -- We'll throw in a GC for free too, thanks to the decompression.
    collectgarbage("collect");
end

--- Internal API
--  The below declarations are for internal use only.

--- Table storing all the databases. Doesn't persist across upgrades; the
--  data is baked into the library and the library assumes a lot about it.
LibRPMedia.schema = {};

--- Registers a named database.
function LibRPMedia:RegisterDatabase(databaseName, database)
    -- Databases must have at minimum a size field.
    if not database.size then
        error(strformat(ERR_DATABASE_UNSIZED, databaseName));
    end

    self.schema[databaseName] = database;
end

--- Unregisters the named database.
function LibRPMedia:UnregisterDatabase(databaseName)
    -- Yoink!
    self.schema[databaseName] = nil;
end

--- Returns true if the named database exists. A real shocker, I know.
function LibRPMedia:IsDatabaseRegistered(databaseName)
    return not not self.schema[databaseName];
end

--- Returns the named database.
--  This function will error if the database is not present.
function LibRPMedia:GetDatabase(databaseName)
    if not self.schema[databaseName] then
        error(strformat(ERR_DATABASE_NOT_FOUND, databaseName), 2);
    end

    return self.schema[databaseName];
end

--- Returns the number of entries present within a named database.
--  This function will error if the database is not present.
function LibRPMedia:GetNumDatabaseEntries(databaseName)
    local database = self:GetDatabase(databaseName);
    return database.size;
end

--- Checks the type of a given value against a list of types. If no type
--  matches, returns nil and an error message formatted with the given
--  parameter name.
--
--  On success, the value is returned as-is with a nil error message.
function CheckType(value, name, t1, t2, ...)
    local tv = type(value);

    -- Slight unrolling; handle the common case of a one or two type check
    -- explicitly without having to iterate over the varargs.
    if tv == t1 then
        return value, nil;
    elseif t2 and tv == t2 then
        return value, nil;
    end

    -- Otherwise consult the varargs.
    for i = 1, select("#", ...) do
        local tn = select(i, ...);
        if tv == tn then
            return value, nil;
        end
    end

    -- Invalid parameter.
    local types;
    if not t2 then
        types = t1;
    elseif select("#", ...) == 0 then
        types = strjoin(" or ", t1, t2);
    else
        types = strjoin(", ", t1, t2, ...);
    end

    return nil, strformat(ERR_INVALID_ARG_TYPE, name, tv, types);
end

--- Asserts the type of a given value as with CheckType, but raises an error
--  if the check fails.
--
--  The error will be raised to occur at a stack depth 3 levels higher than
--  this function, and so will be reported by the caller of the function that
--  calls AssertType.
function AssertType(...)
    local value, err = CheckType(...);
    if not value and err then
        error(err, 3);
    end

    return value;
end

do
    -- Use a restricted environment for the lazy loading to prevent any
    -- weird ideas taking form in the data generation layer.
    local baseenv = { __newindex = function() end, __metatable = false };
    local nullenv = setmetatable({}, baseenv);

    -- Lookup table of ASCII bytes (decimal) for base64 decoding.
    --
    -- This table is based off the standard character set defined in RFC 4648,
    -- and used in MIME (RFC 2045) and PEM (RFC 1421).
    local b64bytes = {
        [ 65] =  0, [ 66] =  1, [ 67] =  2, [ 68] =  3,
        [ 69] =  4, [ 70] =  5, [ 71] =  6, [ 72] =  7,
        [ 73] =  8, [ 74] =  9, [ 75] = 10, [ 76] = 11,
        [ 77] = 12, [ 78] = 13, [ 79] = 14, [ 80] = 15,
        [ 81] = 16, [ 82] = 17, [ 83] = 18, [ 84] = 19,
        [ 85] = 20, [ 86] = 21, [ 87] = 22, [ 88] = 23,
        [ 89] = 24, [ 90] = 25, [ 97] = 26, [ 98] = 27,
        [ 99] = 28, [100] = 29, [101] = 30, [102] = 31,
        [103] = 32, [104] = 33, [105] = 34, [106] = 35,
        [107] = 36, [108] = 37, [109] = 38, [110] = 39,
        [111] = 40, [112] = 41, [113] = 42, [114] = 43,
        [115] = 44, [116] = 45, [117] = 46, [118] = 47,
        [119] = 48, [120] = 49, [121] = 50, [122] = 51,
        [ 48] = 52, [ 49] = 53, [ 50] = 54, [ 51] = 55,
        [ 52] = 56, [ 53] = 57, [ 54] = 58, [ 55] = 59,
        [ 56] = 60, [ 57] = 61, [ 43] = 62, [ 47] = 63,
    };

    --- Decodes a base64 encoded text string, returning the result as a a
    --  decoded string.
    --
    --  This implementation is based off LibBase64, but tuned for a bit more
    --  performance by omitting support for padding characters and using
    --  only one loop/table for the decode phase.
    --
    --  Source:  https://www.wowace.com/projects/libbase64-1-0
    --  Credit:  ckknight (ckknight@gmail.com)
    --  License: MIT
    local function b64decode(text)
        -- Create a temporary table and a local length counter.
        local t = {};
        local n = 0;

        -- Get local references for things in the loop.
        local b64bytes = b64bytes; -- luacheck: no redefined
        local strbyte = strbyte; -- luacheck: no redefined
        local strchar = strchar; -- luacheck: no redefined
        local strjoin = strjoin; -- luacheck: no redefined

        -- Read the text in blocks of 4 bytes.
        for i = 1, #text, 4 do
            -- Map the bytes using the lookup table.
            local a, b, c, d = strbyte(text, i, i + 3);
            a, b, c, d = b64bytes[a], b64bytes[b], b64bytes[c], b64bytes[d];

            -- We don't support padding characters, so we'll check for the
            -- absence of bytes. This also means we'll break if the input is
            -- malformed, but we're not a public function.
            local nilNum = 0;
            if not c then
                nilNum = 2;
                c = 0;
                d = 0;
            elseif not d then
                nilNum = 1;
                d = 0;
            end

            -- Convert the four input bytes to three output bytes.
            local num = (a * 2^18) + (b * 2^12) + (c * 2^6) + d;
            c = num % 2^8;
            num = (num - c) / 2^8;
            b = num % 2^8;
            num = (num - b) / 2^8;
            a = num % 2^8;

            -- Put the three output bytes into the output table.
            n = n + 1;
            if nilNum == 0 then
                t[n] = strjoin("", strchar(a), strchar(b), strchar(c));
            elseif nilNum == 1 then
                t[n] = strjoin("", strchar(a), strchar(b));
            elseif nilNum == 2 then
                t[n] = strchar(a);
            end
        end

        -- Join the output up and we're done.
        return tconcat(t, "");
    end

    --- Hydrates the given data as a compressed string, returning a generator
    --  that will inflate it upon being called and evaluate its contents.
    local function HydrateDataString(data)
        -- Create the generator that will load the data.
        local function generator()
            -- Decode and decompress.
            local decoded = b64decode(data)
            local decompressed = LibDeflate:DecompressDeflate(decoded);

            -- Load the chunk.
            local stmt = strjoin(" ", "return", decompressed);
            local chunk, err = loadstring(stmt);
            if err then
                -- The error string might be super long, so we'll drop it.
                error(ERR_DATA_DECOMPRESS_FAILED, 2);
            end

            -- Execute the chunk in an empty environment.
            setfenv(chunk, nullenv);
            return chunk();
        end

        -- Ensure the generator doesn't do anything weird.
        return setfenv(generator, nullenv);
    end

    --- Hydrates the given data as a table, causing any contained generator
    --  functions to be lazily executed on first access to the table.
    local function HydrateDataTable(data)
        -- Map of functions that generate data on first access.
        local generators = {};

        -- Move any data producing functions from the table to the generators.
        for key, value in pairs(data) do
            if type(value) == "function" then
                generators[key] = setfenv(value, nullenv);
                data[key] = nil;
            end
        end

        -- Apply a metatable that will catch hits to the fields we just nil'd.
        local metatable = {};
        metatable.__index = function(_, key)
            local generator = generators[key];
            if not generator then
                return nil;
            end

            -- Drop the reference to the generator to let it be GC'd.
            generators[key] = nil;

            -- Invoke the generator and get its value.
            local ok, value = xpcall(generator, CallErrorHandler);
            if not ok then
                return nil;
            end

            -- Cache it and we're done.
            rawset(data, key, value);
            return value;
        end

        return setmetatable(data, metatable);
    end

    --- Hydrates the given data. Depending upon the type of data given,
    --  this will have different effects.
    --
    --  If a table is given, it will be wrapped in a proxy which detects
    --  the first access to any field and lazily loads its content if the
    --  value stored is a function.
    --
    --  If a string is given, it is assumed to be a base64 encoded, compressed
    --  Lua expression that when inflated will expand out to the data. This
    --  will be transformed into a function.
    --
    --  If any other type is given, an error is raised.
    function LibRPMedia:HydrateData(data)
        if type(data) == "table" then
            return HydrateDataTable(data);
        elseif type(data) == "string" then
            return HydrateDataString(data);
        else
            error(strformat(ERR_DATA_NOT_HYDRATABLE, type(data)), 2);
        end
    end
end

--- Internal utility functions.
--  Some of these are copy/pasted from the exporter, so need keeping in sync.

--- Performs a binary search for a value inside a given value, optionally
--  limited to the ranges i through j (defaulting to 1, #table).
--
--  This function will always return the index that is the closest to the
--  given value if an exact match cannot be found.
function BinarySearchPrefix(table, value, i, j)
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

--- Performs a binary search for a value inside a given table, optionally
--  limited to the ranges i through j (defaulting to 1, #table).
--
--  If a match is found, the index of the value is returned. Otherwise, nil.
function BinarySearch(table, value, i, j)
    local index = BinarySearchPrefix(table, value, i, j);
    return table[index] == value and index or nil;
end

--- Returns the length of the longest common prefix between two strings.
function GetCommonPrefixLength(a, b)
    if a == b then
        return #a;
    end

    local offset = 1;
    local length = min(#a, #b);

    -- The innards of the loop are manually unrolled so we can minimize calls.
    while offset <= length do
        local a1, a2, a3, a4, a5, a6, a7, a8 = strbyte(a, offset, offset + 7);
        local b1, b2, b3, b4, b5, b6, b7, b8 = strbyte(b, offset, offset + 7);

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

do
    local function iterator(music, musicIndex)
        musicIndex = musicIndex + 1;
        if musicIndex > music.size then
            return nil;
        end

        local musicFile = music.data.file[musicIndex];
        local musicName = music.data.name[musicIndex];
        return musicIndex, musicFile, musicName;
    end

    --- Returns an iterator that returns all music files in the database
    --  in index-order.
    function IterMusicFiles(music)
        return iterator, music, 0;
    end
end

--- Returns an iterator that returns all matching music files in the database
--  that share a common prefix with the given search string.
function IterMusicFilesByPrefix(music, search)
    -- Map of file indices that we've already returned.
    local seen = {};

    -- Upvalue the database and search index to minimize lookups a bit.
    local data = music.data;
    local names = music.index.name;

    -- Begin iteration from the closest matching prefix in the key array.
    local nameIndex = BinarySearchPrefix(names.key, search);

    local function iterator()
        -- Loop so long as we don't run out of keys.
        local keyCount = #names.key;
        while nameIndex < keyCount do
            -- If the common prefix between our search string and the current
            -- file name isn't the same as the search string, then we should
            -- stop since we're past the "like" range of names.
            local name = names.key[nameIndex];
            local shared = GetCommonPrefixLength(search, name);
            if shared ~= #search then
                return nil;
            end

            -- Convert the search index into a music index.
            local musicIndex = names.row[nameIndex];
            nameIndex = nameIndex + 1;

            -- Yield the music file if we haven't reported it already.
            if not seen[musicIndex] then
                seen[musicIndex] = true;

                -- It's important that we yield the matched name and not
                -- the canonical name, since the searches don't make sense
                -- otherwise.
                local musicFile = data.file[musicIndex];
                return musicIndex, musicFile, name;
            end
        end
    end

    return iterator;
end

--- Returns an iterator that returns all matching music files in the database
--  that match a given pattern string. If plain is true, the search will not
--  be a pattern but rather a substring test.
function IterMusicFilesByPattern(music, search, plain)
    -- Map of file indices that we've already returned.
    local seen = {};

    -- Upvalue the database and search index to minimize lookups a bit.
    local data = music.data;
    local names = music.index.name;

    -- Start iteration from the beginning of the keys array.
    local nameIndex = 1;

    local function iterator()
        local keyCount = #names.key;
        while nameIndex < keyCount do
            local name = names.key[nameIndex];
            local musicIndex = names.row[nameIndex];
            nameIndex = nameIndex + 1;

            -- If we've not seen this file, test the name.
            if not seen[musicIndex] and strfind(name, search, 1, plain) then
                -- Got a hit.
                seen[musicIndex] = true;

                local musicFile = data.file[musicIndex];
                return musicIndex, musicFile, name;
            end
        end
    end

    return iterator;
end

--- Normalizes the given music name, turning it into a lowercase string
--  with all backslashes (\) into forward slashes (/).
function NormalizeMusicName(musicName)
    return strlower(strgsub(musicName, "\\", "/"));
end
