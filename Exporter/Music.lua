#!/usr/bin/env lua
local DB = require("Exporter.DB");
local Template = require("Exporter.Template");

-- Local declarations.
local CollectFilesFromFileList;
local CollectFilesFromSoundKits;
local GetFileNameData;
local GetFileNameSearchIndex;
local GetMusicSoundKits;
local GetSortedFileIDs;
local SortFileNames;

-- Sound type for sound kits that represent music pieces.
local SOUND_TYPE_MUSIC = 28;

-- Pattern matching where sound files will be looked for in the listfile.
local SOUND_PATH_PATTERN = "^sound/music/([^.]+)%.?%w*$";

--- Music module.
local Music = {};

--- Builds the music database.
function Music.GetDatabase(version)
    -- Grab the sound kits that reference music files and then, from that,
    -- build a hash of file IDs to a list of names for them.
    local musicKits = GetMusicSoundKits(version);
    local fileHash = CollectFilesFromSoundKits({}, musicKits, version);

    -- Clean up the names a bit by sorting them. We won't resort after this;
    -- the idea is to just ensure sound kit names are sensibly ordered.
    SortFileNames(fileHash);

    -- Next, include data from the file list for this build. This allows us
    -- to migrate older data, as well as reference files not present in
    -- any sound kit (and yes, there are some).
    CollectFilesFromFileList(fileHash, version);

    -- Sort the files into an ordered table, and from that we'll obtain
    -- a suitable short-form name for each file. Only one name will be
    -- picked, but all names will be searchable in the index.
    local fileIDs = GetSortedFileIDs(fileHash);
    local fileNames = GetFileNameData(fileIDs, fileHash);

    -- From there, collect the file names into a search index.
    local fileNameIndex = GetFileNameSearchIndex(fileIDs, fileHash);

    -- And finally we can yield the database.
    return {
        size = #fileIDs,
        data = {
            file = fileIDs,
            name = fileNames,
        },
        search = {
            name = fileNameIndex,
        },
    };
end

--- Writes the given database out to the given file.
function Music.WriteDatabase(file, db)
    -- The database itself contains things we want to lazily load, so we're
    -- gonna hydrate tables as we go. Start with the size information.
    file:write("LibRPMedia:CreateHydratedTable({");
    file:write("size=", Template.Serialize(db.size), ",");

    -- Start writing out the data tables.
    file:write("data={");
    file:write("file=", Template.Serialize(db.data.file), ",");
    file:write("name=", Template.Serialize(db.data.name));
    file:write("},");

    -- Write out the index data.
    file:write("search=LibRPMedia:CreateHydratedTable({");
    file:write("name=", Template.SerializeGenerator(db.search.name));
    file:write("}),");

    -- Close off the database table.
    file:write("})");
end

--- Internal API
--  The below declarations are for internal use only.

--- Collects files from the client file list for the given build, adding
--  them to the given file hashtable.
function CollectFilesFromFileList(fileHash, version)
    -- Grab the file list from the build.
    local fileList = DB.OpenFileList(version);

    for fileID, filePath in fileList:IterRows() do
        -- We only consider files inside the sound path.
        local fileName = string.match(filePath, SOUND_PATH_PATTERN);
        if fileName and fileName ~= "" then
            -- Ensure a list exists for files.
            if not fileHash[fileID] then
                fileHash[fileID] = {};
            end

            -- We'll insert two records; one is the exact path and the
            -- other will be the basename. We prepend them because we want
            -- file path data to take priority.
            local baseName = string.match(fileName, "[^/]-$");

            local fileNames = fileHash[fileID];
            table.insert(fileNames, 1, fileName);
            table.insert(fileNames, 1, baseName);
        end
    end

    fileList:Close();
    return fileHash;
end

--- Collects files from the sound kit databases for the given client version,
--  adding them to the given file hashtable.
function CollectFilesFromSoundKits(fileHash, musicKits, version)
    -- Open the soundkitentry database, which maps sound kit IDs to a
    -- varying number of file IDs.
    local soundkitentry = DB.OpenDatabase("soundkitentry", version);
    soundkitentry:SetColumnTransform("SoundKitID", tonumber);
    soundkitentry:SetColumnTransform("FileDataID", tonumber);

    -- Keep a count of each time we see each sound kit.
    local musicKitCounts = {};

    -- Iterate over the entries and add files to the mapping with a name
    -- based upon their owning kits.
    for entryData in soundkitentry:IterRows() do
        local kitID = entryData["SoundKitID"];
        if musicKits[kitID] then
            -- Increment the counter for this kit.
            musicKitCounts[kitID] = (musicKitCounts[kitID] or 0) + 1;

            -- Create a file listing if needed.
            local fileID = entryData["FileDataID"];
            if not fileHash[fileID] then
                fileHash[fileID] = {};
            end

            -- Create a name of the form <kit>_<index> for this file,
            -- where index is the number of times we've seen this kit.
            local files = fileHash[fileID];
            local kitName = musicKits[kitID];
            local kitIndex = musicKitCounts[kitID];

            files[#files + 1] = string.format("%s_%d", kitName, kitIndex);
        end
    end

    soundkitentry:Close();
    return fileHash;
end

--- Gets a list of file names for use in the resulting database. At most
--  one name is chosen for each file.
function GetFileNameData(fileIDs, fileHash)
    local names = {};

    -- We'll pick the first name of each file as the "stable" name. This
    -- will usually be the basename of the file, or a soundkit if no path
    -- exists.
    for i = 1, #fileIDs do
        local fileID = fileIDs[i];
        local fileName = fileHash[fileID][1];
        if not fileName then
            error(string.format("File %d has no names.", fileID));
        end

        names[#names + 1] = fileName;

        -- Validation on the record.
        if not names[#names] then
            error(string.format("File %d has a nil name.", fileID));
        elseif names[#names] == "" then
            error(string.format("File %d has an empty name.", fileID));
        end
    end

    return names;
end

--- Creates a search table for the given set of files.
function GetFileNameSearchIndex(fileIDs, fileHash)
    -- The search table will be an ordered array of all file names, either
    -- sound kit, basename, or filename based.
    local index = { keys = {}, values = {} };

    -- Hash of file names to their file index.
    local fileNameHash = {};

    -- Push each file into the key list, and put its index into the hash.
    for fileIndex = 1, #fileIDs do
        local fileID = fileIDs[fileIndex];
        local fileNames = fileHash[fileID];

        -- For each file, we should add the its name to the index array.
        for i = 1, #fileNames do
            local fileName = fileNames[i];
            index.keys[#index.keys + 1] = fileName;
            fileNameHash[fileName] = fileIndex;
        end
    end

    -- Sort the keys and then put the indices into the values in sync with
    -- the now-sorted keys.
    table.sort(index.keys);
    for i = 1, #index.keys do
        index.values[#index.values + 1] = fileNameHash[index.keys[i]];
    end

    return index;
end

--- Returns a hash table of all sound kits representing music.
function GetMusicSoundKits(version)
    -- Collect the kits into a mapping of kit IDs to their names.
    local musicKits = {};

    -- Grab the soundkit databases first, since we want to establish a
    -- searchable mapping of sound kit names to file IDs.
    local soundkit = DB.OpenDatabase("soundkit", version);
    soundkit:SetColumnTransform("ID", tonumber);
    soundkit:SetColumnTransform("SoundType", tonumber);

    local soundkitname = DB.OpenDatabase("soundkitname", version);
    soundkitname:SetColumnTransform("ID", tonumber);

    -- Iterate over the kits and names; assume the databases are in-sync.
    while soundkit:Next() and soundkitname:Next() do
        local kitData = soundkit:GetCurrentRow();
        local nameData = soundkitname:GetCurrentRow();

        if kitData["ID"] ~= nameData["ID"] then
            error("Sound kit databases are out-of-sync!");
        end

        if kitData["SoundType"] == SOUND_TYPE_MUSIC then
            local kitID = kitData["ID"];
            local kitName = nameData["Name"];

            -- Helpfully, some names have weird padding around them. Trim.
            kitName = string.lower(string.match(kitName, "^%s*(.-)%s*$"));
            if kitName ~= "" then
                musicKits[kitID] = kitName;
            end
        end
    end

    soundkit:Close();
    soundkitname:Close();

    return musicKits;
end

--- Gets a sorted list of file IDs from the given file hashtable.
function GetSortedFileIDs(fileHash)
    local fileIDs = {};
    for fileID in pairs(fileHash) do
        fileIDs[#fileIDs + 1] = fileID;
    end

    table.sort(fileIDs);
    return fileIDs;
end

--- Sorts all filenames for each entry in the given file hashtable.
function SortFileNames(fileHash)
    for _, fileNames in pairs(fileHash) do
        table.sort(fileNames);
    end
end

-- Module exports.
return Music;
