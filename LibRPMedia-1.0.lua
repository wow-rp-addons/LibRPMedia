-- This file is licensed under the terms expressed in the LICENSE file.
assert(LibStub, "Missing dependency: LibStub");

local MODULE_MAJOR = "LibRPMedia-1.0";
local MODULE_MINOR = 1;

local LibRPMedia = LibStub:NewLibrary(MODULE_MAJOR, MODULE_MINOR);
if not LibRPMedia then
    return;
end

-- Upvalues.
local min = math.min;
local strbyte = string.byte;
local strsub = string.sub;
local type = type;
local xpcall = xpcall;

local CallErrorHandler = CallErrorHandler;

-- Local declarations.
local FindExactInRadixTree;
local GetCommonPrefixLength;

-- Error constants.
local ERR_DATABASE_NOT_FOUND = "LibRPMedia: Database %q was not found.";

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
function LibRPMedia:GetMusicFile(musicName)
    -- Normalize the name a bit on the way in.
    musicName = string.lower(string.gsub(musicName, "\\", "/"));

    local music = self:GetDatabase("music");
    local musicIndex = FindExactInRadixTree(music.tree, musicName);
    return music.data[musicIndex];
end

--- Returns the file ID for a music file based on its index, in the range
--  1 through GetNumMusicFiles.
--
--  If no file is found, nil is returned.
function LibRPMedia:GetMusicFileByIndex(musicIndex)
    local music = self:GetDatabase("music");
    return music.data[musicIndex];
end

--- Returns an iterator for accessing all music files in the database.
--  The iterator will return pair of file index, and file ID.
--
--  The order of files returned by the iterator is not specified.
function LibRPMedia:IterMusicFiles()
    local music = self:GetDatabase("music");
    return ipairs(music.data);
end

--- Internal API
--  The below declarations are for internal use only.

--- Table storing all the databases. Doesn't persist across upgrades; the
--  data is baked into the library and the library assumes a lot about it.
LibRPMedia.schema = {};

--- Registers a named database.
function LibRPMedia:RegisterDatabase(databaseName, database)
    -- Databases must have at minimum a size field.
    assert(database.size, "database has no size field");
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
        error(string.format(ERR_DATABASE_NOT_FOUND, databaseName), 2);
    end

    return self.schema[databaseName];
end

--- Returns the number of entries present within a named database.
--  This function will error if the database is not present.
function LibRPMedia:GetNumDatabaseEntries(databaseName)
    local database = self:GetDatabase(databaseName);
    return database.size;
end

do
    -- Use a restricted environment for the lazy loading to prevent any
    -- weird ideas taking form in the data generation layer.
    local baseenv = { __newindex = function() end, __metatable = false };
    local nullenv = setmetatable({}, baseenv);

    local function loadstring(code)
        local chunk, err = _G.loadstring(code);
        if err then
            return nil, err;
        end

        return setfenv(chunk, nullenv);
    end

    local loadenv = setmetatable({ loadstring = loadstring }, baseenv);

    --- Creates a hydrated table from the given contents.
    function LibRPMedia:CreateHydratedTable(table)
        -- Map of functions that generate data on first access.
        local generators = {};

        -- Move any data producing functions from the table to the generators.
        for key, value in pairs(table) do
            if type(value) == "function" then
                generators[key] = setfenv(value, loadenv);
                table[key] = nil;
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

            -- Generators are functions that wrap a function generated
            -- dynamically via loadstring. That might sound insane but
            -- there's a good reason behind it in terms of memory usage.
            --
            -- Basically, by lazily generating the closure that contains
            -- the data we don't pay the cost of having all the constants
            -- for the data loaded all the time.
            local ok, data;
            repeat
                ok, data = xpcall(data or generator, CallErrorHandler);
                if not ok then
                    return nil;
                end
            until type(data) ~= "function";

            -- Once we're here, we're done.
            rawset(table, key, data);
            return data;
        end

        return setmetatable(table, metatable);
    end
end

--- Internal utility functions.
--  Some of these are copy/pasted from the exporter, so need keeping in sync.

--- Returns the value associated with a key in the given radix tree, or nil
--  if no match is found.
function FindExactInRadixTree(tree, key)
    local keyLength = #key;
    local nextNode = tree;
    local node;

    repeat
        node, nextNode = nextNode, nil;

        for edgeIndex = 1, #node, 2 do
            local edgeLabel = node[edgeIndex];
            local sharedLength = GetCommonPrefixLength(key, edgeLabel);

            if sharedLength == #edgeLabel then
                -- Exact match for this label.
                local edgeValue = node[edgeIndex + 1];
                if type(edgeValue) == "table" then
                    -- Exact match on label, points to a child. Recurse.
                    nextNode = edgeValue;
                    key = strsub(key, sharedLength + 1);
                    keyLength = keyLength - sharedLength;
                    break;
                elseif sharedLength == keyLength then
                    -- Exact match on key and label, points to a value.
                    return edgeValue;
                end
            end
        end
    until not nextNode

    return nil;
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
