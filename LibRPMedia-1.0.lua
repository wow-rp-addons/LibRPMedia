-- This file is licensed under the terms expressed in the LICENSE file.
assert(LibStub, "Missing dependency: LibStub");

local VERSION = 23;

local LibRPMedia = LibStub:NewLibrary("LibRPMedia-1.0", VERSION);
if not LibRPMedia then
    return;
end

local BinarySearch;
local BinaryIndex;
local GetCommonPrefixLength;
local IterIcons;
local IterIconsByPattern;
local IterIconsByPrefix;
local IterIndexByPattern;
local IterIndexByPrefix;
local IterMusicFiles;
local IterMusicFilesByPattern;
local IterMusicFilesByPrefix;
local NormalizeIconName;
local NormalizeMusicName;

local ERR_DATABASE_NOT_FOUND = "LibRPMedia: Database %q was not found";
local ERR_INVALID_SEARCH_METHOD = "LibRPMedia: Invalid search method: %q";

--- Music Database API

function LibRPMedia:IsMusicDataLoaded()
    return self.schema and self.schema.music ~= nil;
end

function LibRPMedia:GetNumMusicFiles()
    return self.schema and self.schema.music.size or 0;
end

function LibRPMedia:GetMusicDataByName(musicName, target)
    local musicIndex = self:GetMusicIndexByName(musicName);

    if not musicIndex then
        return nil;
    end

    return self:GetMusicDataByIndex(musicIndex, target);
end

function LibRPMedia:GetMusicDataByFile(musicFile, target)
    local musicIndex = self:GetMusicIndexByFile(musicFile);

    if not musicIndex then
        return nil;
    end

    return self:GetMusicDataByIndex(musicIndex, target);
end

function LibRPMedia:GetMusicDataByIndex(musicIndex, target)
    assert(type(musicIndex) == "number", "bad argument #1 to 'GetMusicDataByIndex': expected number");

    local music = self:GetDatabase("music");

    if musicIndex < 1 or musicIndex > music.size then
        return nil;
    end

    local targetType = type(target);
    if targetType == "string" then
        local fieldData = music.data[target];

        if not fieldData then
            return nil;
        end

        return fieldData[musicIndex];
    elseif targetType == "table" or targetType == "nil" then
        local fieldTable = target or {};

        for fieldName, fieldData in pairs(music.data) do
            fieldTable[fieldName] = fieldData[musicIndex];
        end

        return fieldTable;
    else
        error("bad argument #2 to 'GetMusicDataByIndex': string, table, or nil");
    end
end

function LibRPMedia:GetMusicFileByName(musicName)
    return self:GetMusicDataByName(musicName, "file");
end

function LibRPMedia:GetMusicFileByIndex(musicIndex)
    return self:GetMusicDataByIndex(musicIndex, "file");
end

function LibRPMedia:GetMusicFileDuration(musicFile)
    return self:GetMusicDataByFile(musicFile, "time") or 0;
end

function LibRPMedia:GetNativeMusicFile(musicFile)
    assert(type(musicFile) == "number", "bad argument #1 to 'GetNativeMusicFile': expected number");

    if not self:GetMusicIndexByFile(musicFile) then
        return nil;
    end

    return musicFile;
end

function LibRPMedia:GetMusicIndexByFile(musicFile)
    assert(type(musicFile) == "number", "bad argument #1 to 'GetMusicIndexByFile': expected number");

    local music = self:GetDatabase("music");
    return BinarySearch(music.data.file, musicFile);
end

function LibRPMedia:GetMusicIndexByName(musicName)
    assert(type(musicName) == "string", "bad argument #1 to 'GetMusicIndexByName': expected string");

    musicName = NormalizeMusicName(musicName);

    local music = self:GetDatabase("music");
    local names = music.index.name;
    return names.row[BinarySearch(names.key, musicName)];
end

function LibRPMedia:GetMusicNameByIndex(musicIndex)
    return self:GetMusicDataByIndex(musicIndex, "name");
end

function LibRPMedia:GetMusicNameByFile(musicFile)
    return self:GetMusicDataByFile(musicFile, "name");
end

function LibRPMedia:FindMusicFiles(musicName, options)
    assert(type(musicName) == "string", "bad argument #1 to 'FindMusicFiles': expected string");
    assert(options == nil or type(options) == "table", "bad argument #2 to 'FindMusicFiles': expected table or nil");

    -- If the search space is empty then everything matches; the iterator
    -- from FindAllMusic files is *considerably* more efficient.

    if musicName == "" then
        return self:FindAllMusicFiles();
    end

    local optMethod = options and options.method or "prefix";

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
        error(string.format(ERR_INVALID_SEARCH_METHOD, optMethod), 2);
    end
end

function LibRPMedia:FindAllMusicFiles()
    local music = self:GetDatabase("music");
    return IterMusicFiles(music);
end

--- Icon Database API

LibRPMedia.IconType = {
    -- Icon name is a standard texture file in the Interface\Icons folder.
    Texture = 1,
    -- [Unused] Icon name is a texture atlas.
    Atlas = 2,
};

function LibRPMedia:IsIconDataLoaded()
    return self.schema and self.schema.icons ~= nil;
end

function LibRPMedia:GetNumIcons()
    return self.schema and self.schema.icons.size or 0;
end

function LibRPMedia:GetIconDataByName(iconName, target)
    local iconIndex = self:GetIconIndexByName(iconName);
    if not iconIndex then
        return nil;
    end

    return self:GetIconDataByIndex(iconIndex, target);
end

function LibRPMedia:GetIconDataByIndex(iconIndex, target)
    assert(type(iconIndex) == "number", "bad argument #1 to 'GetIconDataByIndex': expected number");

    local icons = self:GetDatabase("icons");

    if iconIndex < 1 or iconIndex > icons.size then
        return nil;
    end

    local targetType = type(target);
    if targetType == "string" then
        local fieldData = icons.data[target];

        if not fieldData then
            return nil;
        end

        return fieldData[iconIndex];
    elseif targetType == "table" or targetType == "nil" then
        local fieldTable = target or {};

        for fieldName, fieldData in pairs(icons.data) do
            fieldTable[fieldName] = fieldData[iconIndex];
        end

        return fieldTable;
    else
        error("bad argument #2 to 'GetIconDataByIndex': string, table, or nil");
    end
end

function LibRPMedia:GetIconNameByIndex(iconIndex)
    return self:GetIconDataByIndex(iconIndex, "name");
end

function LibRPMedia:GetIconFileByIndex(iconIndex)
    return self:GetIconDataByIndex(iconIndex, "file");
end

function LibRPMedia:GetIconFileByName(iconName)
    return self:GetIconDataByName(iconName, "file");
end

function LibRPMedia:GetIconTypeByIndex(iconIndex)
    return LibRPMedia.IconType.Texture;
end

function LibRPMedia:GetIconTypeByName(iconName)
    return LibRPMedia.IconType.Texture;
end

function LibRPMedia:GetIconIndexByName(iconName)
    assert(type(iconName) == "string", "bad argument #1 to 'GetIconIndexByName': expected string");

    local icons = self:GetDatabase("icons");
    return BinarySearch(icons.data.name, NormalizeIconName(iconName));
end

function LibRPMedia:FindIcons(iconName, options)
    assert(type(iconName) == "string", "bad argument #1 to 'FindIcons': expected string");
    assert(options == nil or type(options) == "table", "bad argument #2 to 'FindIcons': expected table or nil");

    if iconName == "" then
        return self:FindAllIcons();
    end

    local optMethod = options and options.method or "prefix";

    local icons = self:GetDatabase("icons");
    if optMethod == "prefix" then
        return IterIconsByPrefix(icons, iconName);
    elseif optMethod == "substring" then
        return IterIconsByPattern(icons, NormalizeIconName(iconName), true);
    elseif optMethod == "pattern" then
        return IterIconsByPattern(icons, iconName, false);
    else
        error(string.format(ERR_INVALID_SEARCH_METHOD, optMethod), 2);
    end
end

function LibRPMedia:FindAllIcons()
    local icons = self:GetDatabase("icons");
    return IterIcons(icons);
end

--- Internal API
--  The below declarations are for internal use only.

LibRPMedia.schema = nil;  -- We assume all minor upgrades nuke the database.

function LibRPMedia:NewDatabase()
    -- No-op; required for pre-v23 compatibility.
end

function LibRPMedia:GetDatabase(databaseName)
    local database = self.schema and self.schema[databaseName] or nil;

    if not database then
        error(string.format(ERR_DATABASE_NOT_FOUND, databaseName), 2);
    end

    return database;
end

function BinaryIndex(table, value, i, j)
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

function BinarySearch(table, value, i, j)
    local index = BinaryIndex(table, value, i, j);
    return table[index] == value and index or nil;
end

function GetCommonPrefixLength(a, b)
    local strbyte = string.byte;

    if a == b then
        return #a;
    end

    local offset = 1;
    local length = math.min(#a, #b);

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

function IterIndexByPrefix(index, prefix, rowAccessorFunc, data)
    local seen = {};

    -- Begin iteration from the closest matching prefix.
    local offset = BinaryIndex(index.key, prefix);
    local length = #index.key;

    local iterator = function()
        while offset <= length do
            local key = index.key[offset];
            local commonLength = GetCommonPrefixLength(prefix, key);

            if commonLength ~= #prefix then
                -- Common prefix length isn't the full prefix, so we're
                -- past the searchable range where things can match.
                return nil;
            end

            local row = index.row[offset];
            offset = offset + 1;

            if not seen[row] then
                seen[row] = true;
                return rowAccessorFunc(data, row, key);
            end
        end
    end

    return iterator;
end

function IterIndexByPattern(index, pattern, plain, rowAccessorFunc, data)
    local strfind = string.find;

    local seen = {};

    local offset = 1;
    local length = #index.key;

    local iterator = function()
        while offset <= length do
            local key = index.key[offset];
            local row = index.row[offset];
            offset = offset + 1;

            if not seen[row] and strfind(key, pattern, 1, plain) then
                seen[row] = true;
                return rowAccessorFunc(data, row, key);
            end
        end
    end

    return iterator;
end

-- Music API support functions.

do
    local function accessor(data, row, key)
        -- The music name is always the matched key and not the canonical
        -- name, since searches don't make sense otherwise.
        local musicIndex = row;
        local musicFile = data.file[musicIndex];
        local musicName = key;

        return musicIndex, musicFile, musicName;
    end

    local function iterator(music, musicIndex)
        musicIndex = musicIndex + 1;
        if musicIndex > music.size then
            return nil;
        end

        local musicFile = music.data.file[musicIndex];
        local musicName = music.data.name[musicIndex];
        return musicIndex, musicFile, musicName;
    end

    function IterMusicFiles(music)
        return iterator, music, 0;
    end

    function IterMusicFilesByPattern(music, pattern, plain)
        local index = music.index.name;
        local data = music.data;

        return IterIndexByPattern(index, pattern, plain, accessor, data);
    end

    function IterMusicFilesByPrefix(music, prefix)
        local index = music.index.name;
        local data = music.data;

        return IterIndexByPrefix(index, prefix, accessor, data);
    end

    function NormalizeMusicName(musicName)
        return string.lower(string.gsub(musicName, "\\", "/"));
    end
end

-- Icon API support functions.

do
    local function iterator(icons, iconIndex)
        iconIndex = iconIndex + 1;
        if iconIndex > icons.size then
            return nil;
        end

        local iconName = icons.data.name[iconIndex];
        return iconIndex, iconName;
    end

    function IterIcons(icons)
        return iterator, icons, 0;
    end

    function IterIconsByPattern(icons, pattern, plain)
        local strfind = string.find;

        local patternIterator = function(_, offset)
            for iconIndex = offset + 1, icons.size do
                local iconName = icons.data.name[iconIndex];
                if strfind(iconName, pattern, 1, plain) then
                    return iconIndex, iconName;
                end
            end
        end

        return patternIterator, icons, 0;
    end

    function IterIconsByPrefix(icons, prefix)
        local prefixIterator = function(_, offset)
            local iconIndex = offset + 1;
            local iconName = icons.data.name[iconIndex];
            local commonLength = GetCommonPrefixLength(prefix, iconName);

            if commonLength == #prefix then
                -- Common prefix length still matches, so this is a hit.
                return iconIndex, iconName;
            end

            -- Common prefix length isn't the full prefix, so we're
            -- past the searchable range where things can match.
            return nil;
        end

        -- Start iteration from the index before the matched prefix, as our
        -- name data is stored alphabetically.
        local startIndex = BinaryIndex(icons.data.name, prefix);
        return prefixIterator, icons, startIndex - 1;
    end

    function NormalizeIconName(iconName)
        return string.lower(iconName);
    end
end

--@do-not-package@

if (...) == "LibRPMedia" and UIParent ~= nil then
    SLASH_LIBRPMEDIA_SLASHCMD1 = "/lrpm";

    SlashCmdList["LIBRPMEDIA_SLASHCMD"] = function(cmd)
        local subcommand = string.match(cmd, "^([^%s]*)%s*(.-)$");
        if subcommand == "" or subcommand == "browse" then
            if not LibRPMedia_BrowserFrame then
                CreateFrame("Frame", "LibRPMedia_BrowserFrame", UIParent, "LibRPMedia_BrowserTemplate");
                LibRPMedia_BrowserFrame:SetPoint("TOPLEFT", 80, -104);
                LibRPMedia_BrowserFrame:SetSize(800, 600);
            end

            LibRPMedia_BrowserFrame:SetShown(not LibRPMedia_BrowserFrame:IsShown());
        elseif subcommand == "validate" then
            for _, name in LibRPMedia:FindAllIcons() do
                if not GetFileIDFromPath([[Interface\Icons\]] .. name) then
                    print("Bad icon found: " .. name);
                end
            end
        end
    end
end

--@end-do-not-package@
