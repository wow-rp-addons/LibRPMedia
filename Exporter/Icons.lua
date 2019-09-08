-- This file is licensed under the terms expressed in the LICENSE file.
local Log = require "Exporter.Log";
local Resources = require "Exporter.Resources";
local Serializer = require "Exporter.Serializer";
local Utils = require "Exporter.Utils";

local bit = require "bit";
local plpath = require "pl.path";

-- Upvalues.
local bbor = bit.bor;
local blshift = bit.lshift;
local strbyte = string.byte;
local strfind = string.find;
local strgsub = string.gsub;
local strlower = string.lower;
local tinsert = table.insert;

-- Pattern matching files present in the icons directory.
local ICON_DIRECTORY_PATTERN = "^interface/icons/";

-- Enumeration of icon types. Entries here must be present in the library.
local IconType = {
    Texture = 1,
    Atlas = 2,
};

-- Adds a given icon to the specified manifest. Errors if a duplicate icon
-- with the same name already exists.
local function AddIconToManifest(icon, manifest)
    local index = Utils.BinaryIndex(manifest, function(_, index)
        return manifest[index].name >= icon.name;
    end);

    if manifest[index] and manifest[index].name == icon.name then
        Utils.Errorf("duplicate icon in manifest: %s", icon.name);
    end

    tinsert(manifest, index, icon);
end

-- Icon database module.
local Icons = {
    -- List of name patterns to exclude from the icon database.
    excludeNames = {},
    -- List of atlas name patterns to include in the icon database.
    includeAtlases = {},
};

-- Returns the list of excluded icon name patterns.
function Icons.GetExcludedNames()
    return Icons.excludeNames;
end

-- Sets the list of excluded icon name patterns.
function Icons.SetExcludedNames(excludeNames)
    Icons.excludeNames = excludeNames;
end

-- Returns the list of included atlas name patterns.
function Icons.GetIncludedAtlases()
    return Icons.includeAtlases;
end

-- Sets the list of included atlas name patterns.
function Icons.SetIncludedAtlases(includeAtlases)
    Icons.includeAtlases = includeAtlases;
end

-- Normalizes the given icon file path or name.
function Icons.NormalizeName(name)
    return strgsub(strlower(name), "\\", "/");
end

-- Returns the name for an icon based on its file path.
function Icons.GetNameFromFilePath(filePath)
    filePath = Icons.NormalizeName(filePath);

    local name = plpath.splitext(plpath.basename(filePath));
    return strlower(name);
end

-- Returns true if the given icon name is excluded from the database.
function Icons.IsNameExcluded(name)
    for _, pattern in ipairs(Icons.GetExcludedNames()) do
        if strfind(name, pattern) then
            return true;
        end
    end

    return false;
end

-- Returns true if the given atlas name should be included in the database.
function Icons.IsAtlasIncluded(atlasName)
    for _, pattern in ipairs(Icons.GetIncludedAtlases()) do
        if strfind(atlasName, pattern) then
            return true;
        end
    end

    return false;
end

-- Returns true if the given file path is valid as an icon that can be
-- exported in the database.
function Icons.IsValidFilePath(filePath)
    -- Reject paths not in the icons folder.
    filePath = Icons.NormalizeName(filePath);
    if not strfind(filePath, ICON_DIRECTORY_PATTERN) then
        return false;
    end

    -- Check the name against the excluded name patterns.
    local name = Icons.GetNameFromFilePath(filePath);
    return not Icons.IsNameExcluded(name);
end

-- Returns the width/height of an icon file specified by the given ID.
function Icons.GetIconDimensions(fileID)
    -- Obtain the file content for this icon.
    if not Resources.IsFileContentDownloaded(fileID) then
        Resources.DownloadFileContent(fileID);
    end

    -- Open the file up and read in the header bytes. We only need the first
    -- 20 bytes to obtain size infrmation.
    local filePath = Resources.GetFileContentPath(fileID);
    local file, err = io.open(filePath, "rb");
    if not file then
        Utils.Errorf("error opening file: %s", err);
    end

    local data, rerr = file:read(20);
    if not data then
        file:close();
        Utils.Errorf("error reading file: %s", rerr);
    end

    file:close();

    -- Verify that this ia BLP file.
    local m1, m2, m3, m4 = strbyte(data, 1, 4);
    if m1 ~= 0x42 or m2 ~= 0x4c or m3 ~= 0x50 or m4 ~= 0x32 then
        Utils.Errorf("file %s has invalid magic header", fileID);
    end

    -- The size (width/height) can be found from bytes 13-16 and 17-20.
    local w1, w2, w3, w4 = strbyte(data, 13, 16);
    local width = bbor(w1, blshift(w2, 8), blshift(w3, 16), blshift(w4, 24));

    local h1, h2, h3, h4 = strbyte(data, 13, 16);
    local height = bbor(h1, blshift(h2, 8), blshift(h3, 16), blshift(h4, 24));


    return Serializer.CreateSpacedTable({ w = width, h = height });
end

-- Updates the data on the given icon table with additional data obtained
-- from the content of the icon files.
--
-- If the icon is invalid or should be omitted, nil is returned along with
-- an error message. Otherwise, the given icon is returned.
function Icons.UpdateIconData(icon)
    -- Obtain the dimensions of the icon.
    local ok, dimensions = pcall(Icons.GetIconDimensions, icon.file);
    if not ok then
        -- Error occurred; this'll usually mean the content is unreadable.
        return nil, dimensions;
    end

    -- Note if the dimensions of the icon look invalid. This can signal that
    -- a non-icon has been picked up within the icon folder itself.
    if dimensions.w ~= 64 or dimensions.h ~= 64 then
        Log.Debug("Icon has improper dimensions.", {
            file = icon.file,
            name = icon.name,
            width = dimensions.w,
            height = dimensions.h,
        });
    end

    -- Update fields on the icon.
    icon.hash = Resources.GetFileContentHash(icon.file);
    icon.size = dimensions;
    return icon;
end

-- Builds the manifest for icons. The manifest exports all the data that
-- is then compacted into the database in a later stage.
function Icons.GetManifest(cache)
    -- Wipe the existing manifest data as we don't cache anything useful.
    local manifest = {};

    -- Iterate over the filelist and find icons in the known directory,
    -- filtering out those in the exclusion lists.
    Log.Info("Collecting icon files...");

    local filelist = Resources.GetFileList();
    for i = 1, filelist.size do
        local file = filelist.files[i];
        local path = filelist.paths[i];
        local name = Icons.GetNameFromFilePath(path);

        if Icons.IsValidFilePath(path) then
            -- Create the icon table.
            local icon = {};
            icon.file = file;
            icon.name = name;
            icon.type = IconType.Texture;

            -- Populate the advanced data. If this fails, we'll omit it.
            local ok, err = Icons.UpdateIconData(icon);
            if not ok then
                Log.Warn("Skipping icon file.", {
                    file = file,
                    name = name,
                    err = err,
                });
            else
                -- Insert into the manifest.
                AddIconToManifest(icon, manifest);
            end
        end
    end

    Log.Info("Collecting icon atlases...");

    -- Collect atlas file IDs into a mapping.
    local atlases = Resources.GetDatabase("uitextureatlas");
    local atlasFiles = {};
    for i = 1, atlases.size do
        local atlasID = tonumber(atlases.ID[i]);
        local atlasFile = tonumber(atlases.FileDataID[i]);

        atlasFiles[atlasID] = atlasFile;
    end

    local atlasMembers = Resources.GetDatabase("uitextureatlasmember");
    for i = 1, atlasMembers.size do
        -- Verify that this atlas refers to a valid file.
        local atlasID = tonumber(atlasMembers.UiTextureAtlasID[i]);
        local atlasName = atlasMembers.CommittedName[i];

        if atlasFiles[atlasID] and Icons.IsAtlasIncluded(atlasName) then
            -- Extract attributes.
            local x1 = tonumber(atlasMembers.CommittedLeft[i])
            local x2 = tonumber(atlasMembers.CommittedRight[i]);
            local y1 = tonumber(atlasMembers.CommittedTop[i])
            local y2 = tonumber(atlasMembers.CommittedBottom[i]);

            -- Populate and insert an icon entry into the manifest.
            local icon = {};
            icon.file = atlasFiles[atlasID];
            icon.name = atlasName;
            icon.type = IconType.Atlas;
            icon.size = Serializer.CreateSpacedTable({
                w = x2 - x1,
                h = y2 - y1,
            });

            AddIconToManifest(icon, manifest);
        elseif not atlasFiles[atlasID] then
            Log.Warn("Icon atlas has no associated file ID.", {
                name = atlasName,
                atlas = atlasID,
            });
        end
    end

    return manifest;
end

-- Builds the database for icons as a compacted representation of the
-- given icon manifest for use by the library.
function Icons.GetDatabase(manifest)
    -- Create the initial database structure.
    local database = {
        -- Database size.
        size = #manifest,
        -- Data table.
        data = {
            -- Icon file ID array.
            file = {},
            -- Icon name array.
            name = Serializer.CreateFrontCodedStringList(),
            -- Icon type mapping.
            type = {},
        },
    };

    -- Copy the data from the manifest to the database.
    Log.Info("Building icon database...", { entries = database.size });

    for index, icon in ipairs(manifest) do
        database.data.name[index] = icon.name;
        database.data.file[index] = icon.file;

        -- Due to the sparseness of atlases vs files, we'll omit files and
        -- treat the type table as a map of indices => non-file-types.
        if icon.type ~= IconType.Texture then
            database.data.type[index] = icon.type;
        end
    end

    return database;
end

-- Module exports.
return Icons;
