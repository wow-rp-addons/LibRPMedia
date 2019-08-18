-- This file is licensed under the terms expressed in the LICENSE file.
local LibRPMedia = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true);
if not LibRPMedia or not LibRPMedia.Test then
    return;
end

-- Upvalues.
local Test = LibRPMedia.Test;

local Assert = Test.Assert;
local AssertError = Test.AssertError;
local Assertf = Test.Assertf;
local AssertNoError = Test.AssertNoError;
local AssertType = Test.AssertType;
local Logf = Test.Logf;
local RegisterTest = Test.RegisterTest;

RegisterTest("Music: Database Loaded", function()
    -- Verify that music data is actually present.
    local hasMusic = LibRPMedia:IsMusicDataLoaded();
    Assertf(hasMusic, "No music data loaded in library");
end);

RegisterTest("Music: Database Size", function()
    -- Verify we have a non-zero count of music files.
    local numMusicFiles = LibRPMedia:GetNumMusicFiles();

    AssertType(numMusicFiles, "number", "Music file count is not numeric");
    Assertf(numMusicFiles > 0, "Invalid music file count: %d", numMusicFiles);

    -- We'll log some characteristics about the database too.
    Logf("Music database size: %d entries", LibRPMedia:GetNumMusicFiles());
end);

RegisterTest("Music: API Type Checks", function()
    -- Generate some values of each Lua type.
    local string = "";
    local number = 0;
    local boolean = false;
    local thread = coroutine.create(function() end);
    local userdata = newproxy(false);

    -- The Get<X>ByName functions allow only strings as their parameters.
    AssertNoError(LibRPMedia, "GetMusicFileByName", string);
    AssertError(LibRPMedia, "GetMusicFileByName", nil);
    AssertError(LibRPMedia, "GetMusicFileByName", number);
    AssertError(LibRPMedia, "GetMusicFileByName", boolean);
    AssertError(LibRPMedia, "GetMusicFileByName", thread);
    AssertError(LibRPMedia, "GetMusicFileByName", userdata);

    AssertNoError(LibRPMedia, "GetMusicIndexByName", string);
    AssertError(LibRPMedia, "GetMusicIndexByName", nil);
    AssertError(LibRPMedia, "GetMusicIndexByName", number);
    AssertError(LibRPMedia, "GetMusicIndexByName", boolean);
    AssertError(LibRPMedia, "GetMusicIndexByName", thread);
    AssertError(LibRPMedia, "GetMusicIndexByName", userdata);

    -- The Get<X>ByIndex functions and Get<X>ByFile functions expect
    -- numbers as their parameters.
    AssertNoError(LibRPMedia, "GetMusicFileByIndex", number);
    AssertError(LibRPMedia, "GetMusicFileByIndex", string);
    AssertError(LibRPMedia, "GetMusicFileByIndex", nil);
    AssertError(LibRPMedia, "GetMusicFileByIndex", boolean);
    AssertError(LibRPMedia, "GetMusicFileByIndex", thread);
    AssertError(LibRPMedia, "GetMusicFileByIndex", userdata);

    AssertNoError(LibRPMedia, "GetMusicNameByIndex", number);
    AssertError(LibRPMedia, "GetMusicNameByIndex", string);
    AssertError(LibRPMedia, "GetMusicNameByIndex", nil);
    AssertError(LibRPMedia, "GetMusicNameByIndex", boolean);
    AssertError(LibRPMedia, "GetMusicNameByIndex", thread);
    AssertError(LibRPMedia, "GetMusicNameByIndex", userdata);

    AssertNoError(LibRPMedia, "GetMusicIndexByFile", number);
    AssertError(LibRPMedia, "GetMusicIndexByFile", string);
    AssertError(LibRPMedia, "GetMusicIndexByFile", nil);
    AssertError(LibRPMedia, "GetMusicIndexByFile", boolean);
    AssertError(LibRPMedia, "GetMusicIndexByFile", thread);
    AssertError(LibRPMedia, "GetMusicIndexByFile", userdata);

    AssertNoError(LibRPMedia, "GetMusicNameByFile", number);
    AssertError(LibRPMedia, "GetMusicNameByFile", string);
    AssertError(LibRPMedia, "GetMusicNameByFile", nil);
    AssertError(LibRPMedia, "GetMusicNameByFile", boolean);
    AssertError(LibRPMedia, "GetMusicNameByFile", thread);
    AssertError(LibRPMedia, "GetMusicNameByFile", userdata);

    AssertNoError(LibRPMedia, "GetMusicFileDuration", number);
    AssertError(LibRPMedia, "GetMusicFileDuration", string);
    AssertError(LibRPMedia, "GetMusicFileDuration", nil);
    AssertError(LibRPMedia, "GetMusicFileDuration", boolean);
    AssertError(LibRPMedia, "GetMusicFileDuration", thread);
    AssertError(LibRPMedia, "GetMusicFileDuration", userdata);

    AssertNoError(LibRPMedia, "GetNativeMusicFile", number);
    AssertError(LibRPMedia, "GetNativeMusicFile", string);
    AssertError(LibRPMedia, "GetNativeMusicFile", nil);
    AssertError(LibRPMedia, "GetNativeMusicFile", boolean);
    AssertError(LibRPMedia, "GetNativeMusicFile", thread);
    AssertError(LibRPMedia, "GetNativeMusicFile", userdata);

    -- FindMusicFiles is a pain in the butt since it allows a string as the
    -- first parameter only, but either a nil or a table as the last.
    AssertNoError(LibRPMedia, "FindMusicFiles", string, nil);
    AssertError(LibRPMedia, "FindMusicFiles", nil, nil);
    AssertError(LibRPMedia, "FindMusicFiles", number, nil);
    AssertError(LibRPMedia, "FindMusicFiles", boolean, nil);
    AssertError(LibRPMedia, "FindMusicFiles", thread, nil);
    AssertError(LibRPMedia, "FindMusicFiles", userdata, nil);

    AssertNoError(LibRPMedia, "FindMusicFiles", string, {});
    AssertError(LibRPMedia, "FindMusicFiles", string, number);
    AssertError(LibRPMedia, "FindMusicFiles", string, boolean);
    AssertError(LibRPMedia, "FindMusicFiles", string, thread);
    AssertError(LibRPMedia, "FindMusicFiles", string, userdata);
end);

RegisterTest("Music: Name Lookup (By Index)", function()
    -- Each music index in the range 1 through GetNumMusicFiles should
    -- have a valid, non-repeating name.
    local names = {};

    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local name = LibRPMedia:GetMusicNameByIndex(i);

        AssertType(name, "string", "Music name is not a string");
        Assertf(name ~= "", "Music index %d has an empty name", i);

        Assertf(not names[name],
            "Music index %d has duplicate name: %q (last used by index %d)",
            i, name, names[name]);

        -- Keep track of the names as we go along.
        names[name] = i;
    end
end);

RegisterTest("Music: File Lookup (By Index)", function()
    -- Each music index in the range 1 through GetNumMusicFiles should
    -- point to a valid file ID.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local fileID = LibRPMedia:GetMusicFileByIndex(i);

        AssertType(fileID, "number", "Music file ID is not numeric");
        Assertf(fileID > 0, "Music index %d has an invalid file ID", i);
    end
end);

RegisterTest("Music: Index Lookup (By File)", function()
    -- Mapping each index from 1 through GetNumMusicFiles to a file and
    -- back to an index again should result in the same index.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local fileID = LibRPMedia:GetMusicFileByIndex(i);
        local index = LibRPMedia:GetMusicIndexByFile(fileID);

        AssertType(index, "number", "Music index is not numeric");
        Assertf(index == i,
            "Music file %d maps to index %d, expected %d",
            fileID, index, i);
    end
end);

RegisterTest("Music: Index Lookup (By Name)", function()
    -- Mapping each index from 1 through GetNumMusicFiles to a name and
    -- back to an index again should result in the same index.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local name = LibRPMedia:GetMusicNameByIndex(i);
        local index = LibRPMedia:GetMusicIndexByName(name);

        AssertType(index, "number", "Music index is not numeric");
        Assertf(index == i,
            "Music name %q maps to index %d, expected %d",
            name, index, i);
    end
end);

RegisterTest("Music: Name Lookup (By File)", function()
    -- Iterate over each music index, get the file, then map that to a name.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local fileID = LibRPMedia:GetMusicFileByIndex(i);
        local want = LibRPMedia:GetMusicNameByIndex(i);
        local have = LibRPMedia:GetMusicNameByFile(fileID);

        AssertType(have, "string", "Looked-up music name is not a string");
        AssertType(want, "string", "Expected music name is not a string");
        Assertf(have == want,
            "Music file %q has name %q, expected %q",
            fileID, have, want);
    end
end);

RegisterTest("Music: Invalid Lookups", function()
    -- Each function that is given a correctly-typed but otherwise invalid
    -- value for lookup should return nil to indicate no match.
    local count = LibRPMedia:GetNumMusicFiles();

    -- Test ranges outside of 1 through GetNumMusicFiles for index lookups.
    Assert(LibRPMedia:GetMusicNameByIndex(-1) == nil,
        "Expected nil music name.");

    Assert(LibRPMedia:GetMusicNameByIndex(count + 1) == nil,
        "Expected nil music name.");

    Assert(LibRPMedia:GetMusicFileByIndex(-1) == nil,
        "Expected nil music file.");

    Assert(LibRPMedia:GetMusicFileByIndex(count + 1) == nil,
        "Expected nil music file.");

    -- Test invalid file IDs.
    Assert(LibRPMedia:GetMusicIndexByFile(0) == nil,
        "Expected nil music index.");

    Assert(LibRPMedia:GetMusicNameByFile(0) == nil,
        "Expected nil music name.");

    -- Test invalid music names.
    Assert(LibRPMedia:GetMusicIndexByName("") == nil,
        "Expected nil music index.");

    Assert(LibRPMedia:GetMusicFileByName("") == nil,
        "Expected nil music file.");
end);

RegisterTest("Music: File Lookup (By Name)", function()
    -- Iterate over each music index, get the name, then map that to a file.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local name = LibRPMedia:GetMusicNameByIndex(i);
        local want = LibRPMedia:GetMusicFileByIndex(i);
        local have = LibRPMedia:GetMusicFileByName(name);

        AssertType(have, "number", "Looked-up music file ID is not numeric");
        AssertType(want, "number", "Expected music file ID is not numeric");
        Assertf(have == want,
            "Music name %q belongs to file %d, expected %d",
            name, have, want);
    end
end);

RegisterTest("Music: Valid File Durations", function()
    -- Each music file should have a valid duration as a number. This may
    -- be zero if no information is present.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local fileID = LibRPMedia:GetMusicFileByIndex(i);
        local duration = LibRPMedia:GetMusicFileDuration(fileID);

        AssertType(duration, "number", "Music duration is not numeric");
        Assertf(duration >= 0, "Music index %d has a negative duration.", i);
    end
end);

RegisterTest("Music: Invalid File Durations", function()
    -- Testing invalid file IDs should also return a zero value.
    local duration = LibRPMedia:GetMusicFileDuration(-1);
    AssertType(duration, "number", "Music duration is not numeric");
    Assert(duration == 0, "Expected a zero duration.");
end);

RegisterTest("Music: Valid Native Files", function()
    -- Each music file should be convertible to a native file of some type.
    for i = 1, LibRPMedia:GetNumMusicFiles() do
        local fileID = LibRPMedia:GetMusicFileByIndex(i);
        local nativeFile = LibRPMedia:GetNativeMusicFile(fileID);

        Assertf(nativeFile ~= nil, "Music index %d lacks a native file", i);

        -- We'll test the types here for validity, as we're not a black box.
        if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
            AssertType(nativeFile, "string", "Native file is not a path");
        else
            AssertType(nativeFile, "number", "Native file is not a file ID");
        end
    end
end);

RegisterTest("Music: Invalid Native Files", function()
    -- Testing invalid file IDs should return nil.
    local nativeFile = LibRPMedia:GetNativeMusicFile(-1);
    AssertType(nativeFile, "nil", "Native file is not nil");
end);

RegisterTest("Music: Find All", function()
    -- Finding all music files should result in a number of results equal
    -- to the size of the database, and for each result we should validate
    -- the values against the lookup functions.
    local numFiles = 0;
    for index, fileID, name in LibRPMedia:FindAllMusicFiles() do
        numFiles = numFiles + 1;

        -- Check the types of each value from the iterator.
        AssertType(index, "number", "Music index is not numeric");
        AssertType(fileID, "number", "Music file ID is not numeric");
        AssertType(name, "string", "Music name is not a string");

        -- Querying things via the index should compare the same as the
        -- data from our iterator.
        local wantedFileID, wantedIndex, wantedName;

        wantedName = LibRPMedia:GetMusicNameByIndex(index);
        Assertf(name == wantedName,
            "Music name %q does not match name for index %d (%q)",
            name, index, wantedName or "<nil>");

        wantedFileID = LibRPMedia:GetMusicFileByIndex(index);
        Assertf(fileID == wantedFileID,
            "Music file ID %d does not match file ID for index %d (%s)",
            fileID, index, wantedFileID or "<nil>");

        -- Repeat this time looking up by name.
        wantedIndex = LibRPMedia:GetMusicIndexByName(name);
        Assertf(index == wantedIndex,
            "Music index %d does not match index for name %q (%s)",
            index, name, wantedIndex or "<nil>");

        wantedFileID = LibRPMedia:GetMusicFileByName(name);
        Assertf(fileID == wantedFileID,
            "Music file ID %d does not match file ID for name %q (%s)",
            fileID, name, wantedFileID or "<nil>");

        -- And once more for files!
        wantedIndex = LibRPMedia:GetMusicIndexByFile(fileID);
        Assertf(index == wantedIndex,
            "Music index %d does not match index for file ID %d (%s)",
            index, fileID, wantedIndex or "<nil>");

        wantedName = LibRPMedia:GetMusicNameByIndex(index);
        Assertf(name == wantedName,
            "Music name %q does not match name for file ID %d (%q)",
            name, fileID, wantedName or "<nil>");
    end

    Assertf(numFiles == LibRPMedia:GetNumMusicFiles(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumMusicFiles(), numFiles);
end);

RegisterTest("Music: Find by Prefix", function()
    -- Search with a specific query and confirm all names in the results
    -- have the same prefix as the query.
    local query = "mus_";
    local options = { method = "prefix" };

    local numFiles = 0;
    for _, _, name in LibRPMedia:FindMusicFiles(query, options) do
        local prefix = string.sub(name, 1, #query);
        Assertf(prefix == query,
            "Expected prefix %q, got name: %q (prefix: %q)",
            query, name, prefix);

        numFiles = numFiles + 1;
    end

    -- Verify that we found something at least.
    Assert(numFiles > 0, "Test did not iterate over any files");
end);

RegisterTest("Music: Find by Substring", function()
    -- Search with a specific query and confirm all names in the results
    -- contain the matched string.
    local query = "iron";
    local options = { method = "substring" };

    local numFiles = 0;
    for _, _, name in LibRPMedia:FindMusicFiles(query, options) do
        Assertf(string.find(name, query, 1, true),
            "Expected substring %q, got name: %q",
            query, name);

        numFiles = numFiles + 1;
    end

    -- Verify that we found something at least.
    Assert(numFiles > 0, "Test did not iterate over any files");
end);

RegisterTest("Music: Find by Pattern", function()
    -- Search with a specific query and confirm all names in the results
    -- are valid hits against the pattern.
    local query = "cursedland%d+";
    local options = { method = "pattern" };

    local numFiles = 0;
    for _, _, name in LibRPMedia:FindMusicFiles(query, options) do
        Assertf(string.find(name, query),
            "Expected pattern match %q, got name: %q",
            query, name);

        numFiles = numFiles + 1;
    end

    -- Verify that we found something at least.
    Assert(numFiles > 0, "Test did not iterate over any files");
end);

RegisterTest("Music: Default Find Method", function()
    -- The default search method should perform a prefix search. The below
    -- query is what we'll test with for this across all datasets.
    local query = "citymusic/";

    local numFiles = 0;
    for _, _, name in LibRPMedia:FindMusicFiles(query) do
        local prefix = string.sub(name, 1, #query);
        Assertf(prefix == query,
            "Expected prefix %q, got name: %q (prefix: %q)",
            query, name, prefix);

        numFiles = numFiles + 1;
    end

    -- Verify that we found something at least.
    Assert(numFiles > 0, "Test did not iterate over any files");
end);

RegisterTest("Music: Empty Find Query", function()
    -- An empty find query should always return all files.
    local numFiles = 0;
    for _ in LibRPMedia:FindMusicFiles("") do
        numFiles = numFiles + 1;
    end

    Assertf(numFiles == LibRPMedia:GetNumMusicFiles(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumMusicFiles(), numFiles);
end);

RegisterTest("Music: Find All (By Pattern)", function()
    -- We'll verify that when finding matching files all the data returned
    -- matches the stuff yielded from explicit lookups.
    local query = ".+";
    local options = { method = "pattern" };

    local numFiles = 0;
    local seenFiles = {};

    for index, fileID, name in LibRPMedia:FindMusicFiles(query, options) do
        -- Verify return types.
        AssertType(index, "number", "Music index is not numeric");
        AssertType(fileID, "number", "Music file ID is not numeric");
        AssertType(name, "string", "Music name is not a string");

        -- Test all the reverse lookups except for obtaining the names,
        -- since the names returned by the iterator may or may not match
        -- the defaults used by the GetMusicNameBy<X> functions.
        local wantedFileID, wantedIndex;

        wantedFileID = LibRPMedia:GetMusicFileByIndex(index);
        Assertf(fileID == wantedFileID,
            "Music file ID %d does not match file ID for index %d (%s)",
            fileID, index, wantedFileID or "<nil>");

        wantedIndex = LibRPMedia:GetMusicIndexByName(name);
        Assertf(index == wantedIndex,
            "Music index %d does not match index for name %q (%s)",
            index, name, wantedIndex or "<nil>");

        wantedFileID = LibRPMedia:GetMusicFileByName(name);
        Assertf(fileID == wantedFileID,
            "Music file ID %d does not match file ID for name %q (%s)",
            fileID, name, wantedFileID or "<nil>");

        wantedIndex = LibRPMedia:GetMusicIndexByFile(fileID);
        Assertf(index == wantedIndex,
            "Music index %d does not match index for file ID %d (%s)",
            index, fileID, wantedIndex or "<nil>");

        -- Verify this file hasn't been seen before.
        Assertf(not seenFiles[fileID],
            "Music file %d returned twice by iterator",
            fileID);

        numFiles = numFiles + 1;
        seenFiles[fileID] = true;
    end

    -- Verify each file was returned.
    Assertf(numFiles == LibRPMedia:GetNumMusicFiles(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumMusicFiles(), numFiles);
end);
