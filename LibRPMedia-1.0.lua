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
