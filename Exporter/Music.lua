#!/usr/bin/env lua
local DB = require("Exporter.DB");
local RadixTree = require("Exporter.RadixTree");

-- Local declarations.
local CollectFilesFromFileList;
local CollectFilesFromSoundKits;
local GetFileSearchTree;
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
--  This constitutes the following structure:
--
--   music = {
--       size = <number>,     -- Number of music files.
--       data = <array>,      -- Array of file IDs.
--       tree = <radix-tree>, -- Search tree of names/paths => data indices.
--   }
function Music.GetDatabase(version)
    -- Grab the sound kits that reference music files and then, from that,
    -- build a hash of file IDs to a list of names for them.
    local musicKits = GetMusicSoundKits(version);
    local fileHash = CollectFilesFromSoundKits({}, musicKits, version);

    -- Clean up the names a bit by sorting them. We won't resort after this;
    -- the idea is to put sound kit names in first and then finally the path.
    SortFileNames(fileHash);

    -- Next, include data from the file list for this build. This allows us
    -- to migrate older data, as well as reference files not present in
    -- any sound kit (and yes, there are some).
    CollectFilesFromFileList(fileHash, version);

    -- Sort the files into an ordered table; this will represent the data
    -- list in the resulting DB.
    local sortedFileIDs = GetSortedFileIDs(fileHash);

    -- From there, collect the files into a search tree.
    local tree = GetFileSearchTree(sortedFileIDs, fileHash);

    -- And then we can yield the database structure.
    return {
        size = #sortedFileIDs,
        data = sortedFileIDs,
        tree = tree,
    };
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
            -- Append this name to the list.
            if not fileHash[fileID] then
                fileHash[fileID] = {};
            end

            local fileNames = fileHash[fileID];
            fileNames[#fileNames + 1] = fileName;
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

--- Creates a search tree for the given set of files.
function GetFileSearchTree(sortedFileIDs, fileHash)
    -- Create a new tree root and iterate over the sorted file IDs.
    local tree = {};
    for fileIndex = 1, #sortedFileIDs do
        local fileID = sortedFileIDs[fileIndex];
        local fileNames = fileHash[fileID];

        -- For each file, we should add the name to the tree pointing to
        -- the index within the sorted array.
        for i = 1, #fileNames do
            local fileName = fileNames[i];
            RadixTree.Insert(tree, fileName, fileIndex);
        end
    end

    -- Verification pass on the tree.
    for fileIndex = 1, #sortedFileIDs do
        local fileID = sortedFileIDs[fileIndex];
        local fileNames = fileHash[fileID];

        for i = 1, #fileNames do
            local fileName = fileNames[i];
            assert(RadixTree.FindExact(tree, fileName) == fileIndex);
        end
    end

    return tree;
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

        assert(kitData["ID"] == nameData["ID"]);

        if kitData["SoundType"] == SOUND_TYPE_MUSIC then
            local kitID = kitData["ID"];
            local kitName = nameData["Name"];

            -- Helpfully, some names have weird padding around them. Trim.
            kitName = string.lower(string.match(kitName, "^%s*(.-)%s*$"));

            musicKits[kitID] = kitName;
        end
    end

    soundkit:Close();
    soundkitname:Close();

    return musicKits;
end

--- Gets a sorted list of file IDs from the given file hashtable.
function GetSortedFileIDs(fileHash)
    local sortedFileIDs = {};
    for fileID in pairs(fileHash) do
        sortedFileIDs[#sortedFileIDs + 1] = fileID;
    end

    table.sort(sortedFileIDs);
    return sortedFileIDs;
end

--- Sorts all filenames for each entry in the given file hashtable.
function SortFileNames(fileHash)
    for _, fileNames in pairs(fileHash) do
        table.sort(fileNames);
    end
end

-- Module exports.
return Music;
