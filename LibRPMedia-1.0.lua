-- This file is licensed under the terms expressed in the LICENSE file.
assert(LibStub, "Missing dependency: LibStub");

local MODULE_MAJOR = "LibRPMedia-1.0";
local MODULE_MINOR = 3;

local LibRPMedia = LibStub:NewLibrary(MODULE_MAJOR, MODULE_MINOR);
if not LibRPMedia then
    return;
end

-- Upvalues.
local error = error;
local floor = math.floor;
local min = math.min;
local select = select;
local setmetatable = setmetatable;
local strbyte = string.byte;
local strfind = string.find;
local strformat = string.format;
local strgsub = string.gsub;
local strjoin = string.join;
local strlower = string.lower;
local strsub = string.sub;
local type = type;
local xpcall = xpcall;

local CallErrorHandler = CallErrorHandler;
local Mixin = Mixin;

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
local ERR_DATABASE_NOT_FOUND = "LibRPMedia: Database %q was not found";
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
    if musicName == "" then
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

--- Internal API
--  The below declarations are for internal use only.

--- Table storing all the databases.
--
--  This _currently_ doesn't persist across upgrades as there's a lot of
--  assumptions about the structure of the data, and the data is packed
--  into the library regardless.
LibRPMedia.schema = {};

--- Registers a named database with the given minor version.
--
--  If a database already exists with a greater or same minor version nil is
--  returned, otherwise a table will be returned.
--
--  The database will be initialized with a size field (set to zero), and a
--  version field matching the given minor version.
function LibRPMedia:NewDatabase(databaseName, minorVersion)
    -- Get or create a table for the database.
    local database = self.schema[databaseName] or {};
    if database.version and database.version >= minorVersion then
        -- No upgrade required.
        return nil;
    end

    -- Upgrade fields on the database.
    database.size = database.size or 0;
    database.version = minorVersion;

    self.schema[databaseName] = database;
    return database;
end

--- Returns true if the named database exists.
function LibRPMedia:IsDatabaseRegistered(databaseName)
    return self.schema[databaseName] ~= nil;
end

--- Returns the named database.
--  This function will error if the database is not present.
function LibRPMedia:GetDatabase(databaseName)
    local database = self.schema[databaseName];
    if not database then
        error(strformat(ERR_DATABASE_NOT_FOUND, databaseName), 2);
    end

    return database;
end

--- Returns the number of entries present within a named database.
--  This function will error if the database is not present.
function LibRPMedia:GetNumDatabaseEntries(databaseName)
    local database = self:GetDatabase(databaseName);
    return database.size;
end

--- Creates a table that lazily loads its contents upon first access to any
--  field.
--
--  If an error occurs during data loading, the global error handler is
--  invoked but execution will not terminate, and nil is instead returned.
function LibRPMedia:CreateLazyTable(generatorFunc)
    local metatable = {};
    metatable.__index = function(proxy, key)
        -- Unset the metatable so that loading is only tried once.
        setmetatable(proxy, nil);

        local ok, data = xpcall(generatorFunc, CallErrorHandler);
        if not ok then
            -- Error is passed through default error handler.
            return nil;
        end

        -- Copy the loaded data into the proxy.
        Mixin(proxy, data);
        return proxy[key];
    end

    return setmetatable({}, metatable);
end

--- Restores a string list encoded as a list of front-coded strings, returning
--  a new table with the loaded contents.
function LibRPMedia:LoadFrontCodedStringList(input)
    local output = {};

    -- Iterate over the list in pairs of common prefix length and suffixes.
    for i = 1, #input, 2 do
        local commonLength = input[i];
        local suffix = input[i + 1];

        if commonLength == 0 then
            -- No data in common; the suffix is the whole string.
            output[#output + 1] = suffix;
        else
            -- Combine the suffix with the previously restored string.
            local prefix = output[#output];
            local restored = strsub(prefix, 1, commonLength) .. suffix;

            output[#output + 1] = restored;
        end
    end

    return output;
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
