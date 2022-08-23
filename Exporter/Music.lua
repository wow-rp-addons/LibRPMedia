-- This file is licensed under the terms expressed in the LICENSE file.
local Log = require "Exporter.Log";
local Resources = require "Exporter.Resources";
local Serializer = require "Exporter.Serializer";
local Utils = require "Exporter.Utils";

local plpath = require "pl.path";

-- Upvalues.
local strfind = string.find;
local strformat = string.format;
local strgsub = string.gsub;
local strlower = string.lower;
local tinsert = table.insert;
local tremove = table.remove;

-- Type constant for music soundkit entries.
local SOUNDKIT_TYPE_MUSIC = 28;

-- Pattern matching the directory where music files are rooted to.
local MUSIC_DIRECTORY_PATTERN = "^sound/music/";

-- Threshold at which any music files with a shorter duration than this
-- will trigger a debug log message.
local MUSIC_DURATION_LOG_THRESHOLD = 3;

-- Command for querying file durations via ffprobe.
local FFPROBE_CMD =
    "ffprobe -i %q -v quiet -show_entries format=duration -of csv=p=0";

-- Adds the given music file data entry to the specified files array.
local function AddMusicFileToList(file, files)
    local index = Utils.BinaryIndex(files, function(_, index)
        return files[index].id >= file.id;
    end);

    if files[index] and files[index].id == file.id then
        Utils.Errorf("duplicate file ID in list: %d", file.id);
    end

    tinsert(files, index, file);
end

-- Returns a music file entry from the manifest matching the given file
-- ID, or nil if not found.
local function GetMusicFileFromManifest(fileID, manifest)
    local index = Utils.BinaryIndex(manifest, function(_, index)
        return manifest[index].id >= fileID;
    end);

    if manifest[index] and manifest[index].id == fileID then
        return manifest[index];
    end
end

-- Adds the given music file to the specified manifest.
local function AddMusicFileToManifest(music, manifest)
    local index = Utils.BinaryIndex(manifest, function(_, index)
        return manifest[index].id >= music.id;
    end);

    if manifest[index] and manifest[index].id == music.id then
        Utils.Errorf("duplicate music file in manifest: %d", music.id);
    end

    tinsert(manifest, index, music);
end

-- Removes the given music file from the specified manifest.
local function RemoveMusicFileFromManifest(fileID, manifest)
    local index = Utils.BinaryIndex(manifest, function(_, index)
        return manifest[index].id >= fileID;
    end);

    if manifest[index] and manifest[index].id == fileID then
        tremove(manifest, index);
    end
end

-- Music database module.
local Music = {
    -- Mapping of soundkit overrides.
    overrideKits = {},
    -- List of excluded music file IDs.
    excludeFiles = {},
    -- List of excluded file/soundkit name patterns.
    excludeNames = {},
};

-- Returns the list of excluded music file IDs.
function Music.GetExcludedFiles()
    return Music.excludeFiles;
end

-- Sets the list of excluded music file IDs.
function Music.SetExcludedFiles(excludeFiles)
    Music.excludeFiles = excludeFiles;
end

-- Returns the list of excluded music file/soundkit name patterns.
function Music.GetExcludedNames()
    return Music.excludeNames;
end

-- Sets the list of excluded music file/soundkit name patterns.
function Music.SetExcludedNames(excludeNames)
    Music.excludeNames = excludeNames;
end

-- Returns the mapping of overridden soundkits to their inclusion/exclusion
-- state, or custom names.
function Music.GetOverrideKits()
    return Music.overrideKits;
end

-- Sets the mapping of overridden soundkits.
function Music.SetOverrideKits(overrideKits)
    Music.overrideKits = overrideKits;
end

-- Normalizes the given music file path or name.
function Music.NormalizeName(name)
    return strgsub(strlower(name), "\\", "/");
end

-- Returns any custom name assigned for a soundkit, or nil if not available.
function Music.GetOverrideKitName(kitID)
    local overrides = Music.GetOverrideKits();
    local name = overrides[kitID];

    if type(name) == "string" then
        return Music.NormalizeName(name);
    end

    return nil;
end

-- Returns a name for a music file derived from its file path.
function Music.GetNameFromFilePath(filePath)
    -- Strip the music directory prefix and extension from the file.
    filePath = Music.NormalizeName(filePath);
    filePath = strgsub(strlower(filePath), MUSIC_DIRECTORY_PATTERN, "");

    local name = plpath.splitext(filePath);
    return name;
end

local SeenMusicNames = {};

-- Returns a name for a music file derived from a soundkit name and the
-- index of the file entry for the soundkit.
function Music.GenerateNameForSoundKit(soundkitName)
    local count = SeenMusicNames[soundkitName] or 0;
    local index = count + 1;
    local name = strformat("%s_%02d", soundkitName, index);
    SeenMusicNames[soundkitName] = index;
    return Music.NormalizeName(name);
end

-- Returns true if the given music name (file path or soundkit name) is
-- excluded from the database.
function Music.IsNameExcluded(name)
    for _, pattern in ipairs(Music.GetExcludedNames()) do
        if strfind(name, pattern) then
            return true;
        end
    end

    return false;
end

-- Returns true if the given soundkit ID is explicitly included inside
-- the database.
function Music.IsKitIncluded(kitID)
    local overrides = Music.GetOverrideKits();
    return not not overrides[kitID]; -- Allow any truthy value.
end

-- Returns true if the given soundkit ID is explicitly excluded from the
-- database.
function Music.IsKitExcluded(kitID)
    local overrides = Music.GetOverrideKits();
    return overrides[kitID] == false; -- Explicit false required.
end

-- Returns true if the given file path is that of a music file that can be
-- exported in the database.
function Music.IsValidFilePath(filePath)
    -- Reject paths not in the music folder.
    filePath = Music.NormalizeName(filePath);
    if not strfind(filePath, MUSIC_DIRECTORY_PATTERN) then
        return false;
    end

    -- Test the exclusion list.
    local name = Music.GetNameFromFilePath(filePath);
    return not Music.IsNameExcluded(name);
end

-- Returns the duration of a music file referenced by the given file ID.
--
-- Raises an error on failure, otherwise returns the duration in seconds as
-- a fractional number.
function Music.GetFileDuration(fileID)
    -- We'll shell out to ffprobe since it's reliable and works for all the
    -- files that we try to process. It's slow, but that's life.
    local filePath = Resources.GetFileContentPath(fileID);

    -- The file content must be locally downloaded since ffprobe will need it.
    if not Resources.IsFileContentDownloaded(fileID) then
        Resources.DownloadFileContent(fileID);
    end

    -- Execute the command.
    local command = strformat(FFPROBE_CMD, filePath);
    local pipe, err = io.popen(command, "r");
    if not pipe then
        Utils.Errorf("error running ffprobe: %s", err);
    end

    -- Read in the result and convert it to a number.
    local output, rerr = pipe:read("*a");
    if not output then
        Utils.Errorf("error reading ffprobe output: %s", rerr);
    end

    return tonumber(output) or 0;
end

-- Collects a mapping of soundkits representing music files from the
-- client database dumps.
function Music.GetSoundKits()
    -- Run over all soundkits and find music entries.
    Log.Info("Collecting music soundkits...");
    local soundkit = Resources.GetDatabase("soundkit");
    local soundkitEntries = Resources.GetDatabase("soundkitentry");
    local soundkitNames = Resources.GetDatabase("soundkitname");
    local zoneMusic = Resources.GetDatabase("zonemusic");

    -- Collect the soundkits from the primary database. Start with all
    -- files flagged as being music.
    local kits = {};
    for index = 1, soundkit.size do
        local id = tonumber(soundkit.ID[index]);
        local type = tonumber(soundkit.SoundType[index]);
        local name = Music.GetOverrideKitName(id);

        if type == SOUNDKIT_TYPE_MUSIC or Music.IsKitIncluded(id) then
            kits[id] = { id = id, name = name, files = {} };
        end
    end

    -- Next, go over the name database and attach that information if present.
    for index = 1, soundkitNames.size do
        local name = Music.NormalizeName(soundkitNames.Name[index]);
        local kitID = tonumber(soundkitNames.ID[index]);
        local kit = kits[kitID];

        if kit and not kit.name then
            kit.name = name;
        end
    end

    -- Soundkits can have names derived from the zonemusic database too.
    for rowIndex = 1, zoneMusic.size do
        -- Zones have two potential soundkits for day and night music.
        local name = Music.NormalizeName(zoneMusic.SetName[rowIndex]);

        for columnIndex = 0, 1 do
            local columnName = strformat("Sounds[%d]", columnIndex);
            local kitID = tonumber(zoneMusic[columnName][rowIndex]);
            local kit = kits[kitID];

            if kit and not kit.name then
                kit.name = name;
            end
        end
    end

    -- Now prune the kits; anything excluded by ID, name, or lacking a name
    -- will be discarded.
    for id, kit in pairs(kits) do
        -- We implicitly exclude soundkits if they have no names. Otherwise
        -- we check for an explicit exclusion.
        local implicitExclude = (not kit.name);
        local explicitExclude = implicitExclude
            or Music.IsKitExcluded(id)
            or Music.IsNameExcluded(kit.name);

        if explicitExclude or implicitExclude then
            -- Only log implicit exclusions so the user can maybe fix them.
            if implicitExclude then
                -- Use the debug level since with the patch 8.3 changes
                -- we're likely going to just amass a huge amount of
                -- missing names going forward.
                Log.Debug("Skipping unnamed soundkit.", { soundkit = id });
            end

            kits[id] = nil;
        end
    end

    -- Run over the entries to obtain the files for each music soundkit.
    Log.Info("Collecting soundkit files...");

    for index = 1, soundkitEntries.size do
        local entryKitID = tonumber(soundkitEntries.SoundKitID[index]);
        local entryFileID = tonumber(soundkitEntries.FileDataID[index]);

        local kit = kits[entryKitID];
        if kit then
            -- Some soundkits reference the same file multiple times. This
            -- isn't an error, but should be noted when it does occur.
            if Utils.BinarySearch(kit.files, entryFileID) then
                Log.Debug("Duplicate file ID in soundkit.", {
                    soundkit = entryKitID,
                    file = entryFileID,
                });
            else
                Utils.BinaryInsert(kit.files, entryFileID, true);
            end
        end
    end

    return kits;
end

-- Returns a sorted array of music file entries as exported from the client
-- filelist dump.
function Music.GetFiles()
    -- Run over the contents of the filelist and find music files.
    Log.Info("Collecting music files...");
    local filelist = Resources.GetFileList();

    local files = {};
    for index = 1, filelist.size do
        local fileID = filelist.files[index];
        local filePath = filelist.paths[index];

        if Music.IsValidFilePath(filePath) then
            local name = Music.GetNameFromFilePath(filePath);
            local file = { id = fileID, name = name, path = filePath };

            AddMusicFileToList(file, files);
        end
    end

    return files;
end

-- Returns an appropriate name for a given music file data table. This will
-- prefer the name derived from the filepath if available, otherwise it will
-- use a name from the soundkits list.
function Music.GetMusicName(music)
    return music.name or music.kits[1];
end

-- Updates the given music file with new data from the data stores.
--
-- Returns nil if the file is invalid and should be purged from the database,
-- along with an error message. Otherwise, returns true.
function Music.UpdateMusicFileData(music, oldMusic)
    -- Get the content hash for this file.
    local ok, hash = pcall(Resources.GetFileContentHash, music.id);
    if not ok then
        -- The file is invalid. This is the only time we'll handle errors.
        return nil, hash;
    end

    -- Obtain the duration for this music file if the content hash has
    -- changed since the last build.
    local time;
    if not oldMusic or oldMusic.hash ~= hash then
        time = Music.GetFileDuration(music.id);
    else
        time = oldMusic.time;
    end

    -- Zero duration files indicate the file is *probably* invalid.
    if time == 0 then
        return nil, "file has an invalid file duration";
    elseif time < MUSIC_DURATION_LOG_THRESHOLD then
        -- Short files will trigger a message for investigation.
        Log.Debug("Music file has short duration.", {
            file = music.id,
            name = Music.GetMusicName(music),
            time = time,
        });
    end

    -- Update the music data object.
    music.hash = hash;
    music.time = time;
    return true;
end

-- Collects the raw files and soundkits from the client data dumps and
-- returns a manifest table.
function Music.GetManifest(cache)
    -- Collect music from soundkits and the filelist.
    local files = Music.GetFiles();
    local soundkits = Music.GetSoundKits();

    -- From that we'll merge the mappings into a single list ordered by the
    -- ID of the file being referenced.
    local manifest = {};

    -- Start by processing files. These are already sorted by file ID for us.
    Log.Info("Processing music files...");

    for _, file in ipairs(files) do
        local music = { id = file.id, name = file.name, kits = {} };

        AddMusicFileToManifest(music, manifest);
    end

    -- Now run over the soundkits.
    Log.Info("Processing music soundkits...");

    for _, soundkit in pairs(soundkits) do
        for fileIndex, fileID in ipairs(soundkit.files) do
            -- Get the generated name for this entry.
            local name = Music.GenerateNameForSoundKit(soundkit.name);
            if not Music.IsNameExcluded(name) then
                -- Get the music file from the manifest if one was inserted.
                local music = GetMusicFileFromManifest(fileID, manifest);
                if not music then
                    -- Create a new entry as one doesn't exist.
                    music = { id = fileID, kits = {} };
                    AddMusicFileToManifest(music, manifest);
                end

                -- Update the kit names for this music file entry.
                Utils.BinaryInsert(music.kits, name, true);
            end
        end
    end

    -- Remove excluded files from the manifest.
    Log.Info("Processing file exclusions...");
    for _, fileID in ipairs(Music.GetExcludedFiles()) do
        RemoveMusicFileFromManifest(fileID, manifest);
    end

    -- Once we have all the files we can do our final data collection
    -- based on the CASC storage container data.
    Log.Info("Processing music file data...");

    -- Iterate in reverse order as we may remove files.
    for index = #manifest, 1, -1 do
        -- Get the existing file from the old manifest if one exists.
        local newMusic = manifest[index];
        local oldMusic = GetMusicFileFromManifest(newMusic.id, cache);

        local ok, err = Music.UpdateMusicFileData(newMusic, oldMusic);
        if not ok then
            -- File is invalid; purge it.
            Log.Warn("Skipping invalid music file.", {
                file = newMusic.id,
                name = Music.GetMusicName(newMusic),
                err = err,
            });

            RemoveMusicFileFromManifest(newMusic.id, manifest);
        end
    end

    return manifest;
end

-- Builds a compressed music database for export and use in the library
-- from the contents of the given manifest.
function Music.GetDatabase(manifest)
    -- Create the initial database structure.
    local database = {
        -- Database size.
        size = #manifest,
        -- Data table.
        data = {
            -- File ID array.
            file = {},
            -- File name array.
            name = Serializer.CreateFrontCodedStringList(),
            -- File duration array.
            time = {},
        },
        -- Search index root.
        index = {
            -- Search index for music names.
            name = {
                -- Array of data row indices.
                row = {},
                -- Array of file names.
                key = Serializer.CreateFrontCodedStringList(),
            },
        };
    };

    -- Copy the data from the manifest to the database.
    Log.Info("Building music database...", { entries = database.size });

    for index, music in ipairs(manifest) do
        -- The data can just be copied; if a name for the file (from its path)
        -- doesn't exist we'll use the first soundkit name.
        database.data.file[index] = music.id;
        database.data.name[index] = Music.GetMusicName(music);
        database.data.time[index] = music.time;

        -- Add the name and all soundkit names to the name search index.
        local rows = database.index.name.row;
        local keys = database.index.name.key;

        if music.name then
            local keyIndex = Utils.BinaryInsert(keys, music.name, true);
            tinsert(rows, keyIndex, index);
        end

        for _, kitName in ipairs(music.kits) do
            local keyIndex = Utils.BinaryInsert(keys, kitName, true);
            tinsert(rows, keyIndex, index);
        end
    end

    return database;
end

-- Module exports.
return Music;
