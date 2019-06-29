-- This file is licensed under the terms expressed in the LICENSE file.
local MAJOR_NAME = ...;

-- Upvalues.
local assert = assert;
local strformat = string.format;
local strmatch = string.match;
local strgsub = string.gsub;

-- Local declarations.
local Assert;
local AssertError;
local Assertf;
local AssertNoError;
local AssertType;
local Log;
local Logf;

-- Registry of known test functions.
local tests = {};

--- Registers a test for execution.
local function RegisterTest(name, func)
    table.insert(tests, { Name = name, Func = func });
end

-- Returns true if the test script is being run in-game.
local function IsInGame()
    return not debug and not package and not os;
end

--- Base Library Tests

local LibRPMedia;

RegisterTest("Lib: Initialization", function()
    -- Verify the library has registered with LibStub correctly.
    local lib = LibStub:GetLibrary(MAJOR_NAME, true);
    Assertf(lib, "No library loaded with name: %s", MAJOR_NAME);

    -- We'll store the library reference for future tests.
    LibRPMedia = lib;
end);

--- Music API Tests

RegisterTest("Music: API Type Checks", function()
    -- Generate some values of each Lua type.
    local string = "";
    local number = 0;
    local boolean = false;
    local thread = coroutine.create(nop);
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

--- Internal API
--  The below declarations are for internal use only.

-- luacheck: no unused

-- API polyfills.
local debugprofilestop = debugprofilestop or function()
    return os.time() * 1000;
end

local strjoin = string.join or function(delim, ...)
    return table.concat({ ... }, delim);
end

local WrapTextInColorCode = WrapTextInColorCode or function(text, color)
    if string.find(package.config, "^\\") then
        return text;
    end

    return string.format("\27[%sm%s\27[0m", color, text);
end

-- Color constants used for output messages.
local COLOR_BLUE = IsInGame() and "ff44cefc" or "1;34";
local COLOR_GREEN = IsInGame() and "ff44fc81" or "1;32";
local COLOR_YELLOW = IsInGame() and "fffce344" or "1;33";
local COLOR_RED = IsInGame() and "fffc4447" or "1;31";
local COLOR_GRAY = IsInGame() and "ff808080" or "1;30";

-- Log prefixes and format strings for output messages.
local LOG_DURATION = WrapTextInColorCode("(%.2fs)", COLOR_GRAY);
local LOG_INDENT = IsInGame() and "" or "    ";
local LOG_PREFIX_FAIL = WrapTextInColorCode("--- FAIL:", COLOR_RED);
local LOG_PREFIX_PASS = WrapTextInColorCode("--- PASS:", COLOR_GREEN);
local LOG_PREFIX_SKIP = WrapTextInColorCode("--- SKIP:", COLOR_YELLOW);
local LOG_PREFIX_TEST = WrapTextInColorCode("=== TEST:", COLOR_BLUE);

--- Test Utility Functions
--  Utility functions for use by the tests.

--- Returns a string representing the file/line of the function at a certain
--  level of the stack, relative to the caller.
local function GetStackFrameSource(depth)
    local source;
    if IsInGame() then
        local trace = debugstack(depth + 1, 1, 0);
        source = strmatch(trace, "^.+:%d+:") or "<unknown>:0:";
        source = strgsub(source, "^Interface\\AddOns\\", "");
    else
        local info = debug.getinfo(depth + 1, "Sl");
        source = strformat("%s:%d:", info.short_src, info.currentline);
    end

    return source;
end

--- Wrapper around assert that, well, asserts.
function Assert(value, msg)
    if value then
        return value;
    end

    error(msg or "Assertion failed!", 2);
end

--- Wrapper around assert that formats its error message on failure.
function Assertf(value, fmt, ...)
    if value then
        return value;
    end

    error(strformat(fmt, ...), 2);
end

--- Assertion that triggers if the given function errors when called.
--
--  If the function is a table, the second argument is used as the key to
--  look up a function within the table, which will be called as a method.
function AssertError(fn, ...)
    -- If fn is a table, assume the first parameter is a name to look up
    -- to obtain a function to be called as a method.
    local arg1 = (...);
    if type(fn) == "table" then
        fn, arg1 = fn[(...)], fn;
    end

    -- Validate the function - do this before the call so we can better
    -- report an invalid use of the assertion function.
    if type(fn) ~= "function" then
        error(strformat("Expected function, got: %s", type(fn)), 2);
    end

    -- Execute the function, if it fails then return the error.
    local result = { pcall(fn, arg1, select(2, ...)) };
    if not result[1] then
        return unpack(result, 2);
    end

    -- Otherwise, assertion gone bad.
    local returns = strjoin(", ", tostringall(unpack(result, 2)));
    error(strformat("Expected error, got: %s", returns), 2);
end


--- Assertion that triggers if the given function does not error when called.
--
--  If the function is a table, the second argument is used as the key to
--  look up a function within the table, which will be called as a method.
function AssertNoError(fn, ...)
    -- If fn is a table, assume the first parameter is a name to look up
    -- to obtain a function to be called as a method.
    local arg1 = (...);
    if type(fn) == "table" then
        fn, arg1 = fn[(...)], fn;
    end

    -- Validate the function - do this before the call so we can better
    -- report an invalid use of the assertion function.
    if type(fn) ~= "function" then
        error(strformat("Expected function, got: %s", type(fn)), 2);
    end

    -- Execute the function, if it succeeds then return the values.
    local result = { pcall(fn, arg1, select(2, ...)) };
    if result[1] then
        return unpack(result, 2);
    end

    -- Otherwise, assertion gone bad.
    error(strformat("Expected no error, got: %s", tostring(result[2])), 2);
end

--- Assertion that raises an error if a given values type does not match
--  the expected type name.
function AssertType(value, want, err)
    if type(value) == want then
        return value;
    end

    if not err then
        err = strformat("Expected type %s, got %s", want, type(value));
    end

    error(err, 2);
end

--- Logs a message for the current test.
function Log(...)
    local source = WrapTextInColorCode(GetStackFrameSource(2), COLOR_BLUE);
    print(strjoin("", LOG_INDENT, source, " ", strjoin(" ", ...)));
end

--- Logs a formatted message for the current test.
function Logf(fmt, ...)
    local source = WrapTextInColorCode(GetStackFrameSource(2), COLOR_BLUE);
    print(strjoin("", LOG_INDENT, source, " ", strformat(fmt, ...)));
end

--- Test Runner
--  The below script will run the test in an appropriate manner for however
--  you've chosen to execute this script.

--- Called when an error occurs in a test. This will forward the error to the
--  global error handler, and format it for our own report. The formatted
--  error is returned.
local function HandleTestError(err)
    -- Forward the error to the default error handler for reporting.
    CallErrorHandler(err);

    -- For our own sake, strip part of the path off and color the error.
    return strgsub(err, "^.-:%d+:", function(source)
        source = strgsub(source, "^Interface\\AddOns\\", "");
        return WrapTextInColorCode(source, COLOR_YELLOW);
    end);
end

--- Runs a named test function, capturing its errors and returning a true
--  or false value if it passes or fails.
local function RunTest(name, func)
    -- Capture execution and forward errors appropriately.
    local start = debugprofilestop();
    local ok, err = xpcall(func, HandleTestError);
    local finish = debugprofilestop();

    -- Print some messages indicating the result of the test.
    local duration = strformat(LOG_DURATION, (finish - start) / 1000);
    if not ok then
        if err then
            print(strjoin("", LOG_INDENT, tostring(err)));
        end

        print(strjoin(" ", LOG_PREFIX_FAIL, name, duration));
        return false;
    else
        print(strjoin(" ", LOG_PREFIX_PASS, name, duration));
        return true;
    end
end

--- Runs all registered tests that optionally pass a given name filter.
local function RunTests(filter)
    print(strjoin(" ", LOG_PREFIX_TEST, MAJOR_NAME));

    -- Run all the tests in-order.
    local pass, fail, skip = 0, 0, 0;
    for _, test in ipairs(tests) do
        if string.find(test.Name, filter or "", 1, true) then
            local ok = RunTest(test.Name, test.Func);
            if ok then
                pass = pass + 1;
            else
                fail = fail + 1;
            end
        else
            print(strjoin(" ", LOG_PREFIX_SKIP, test.Name));
            skip = skip + 1;
        end
    end

    -- Sum the tests up and generate a summary.
    local total = pass + fail;
    local prefix = LOG_PREFIX_PASS;
    local summary = strformat("%d tests passed", pass);

    -- If the test failed, change the summary format a bit.
    if fail > 0 then
        prefix = LOG_PREFIX_FAIL;
        summary = strformat("%d/%d tests passed", pass, total);
    end

    -- The summary should include skipped tests if any happened.
    if skip > 0 then
        summary = strformat("%s (%d skipped)", summary, skip);
    end

    -- Dump out the final summary and return true if everything passed.
    print(strjoin(" ", prefix, summary));
    return (fail == 0);
end

if IsInGame() then
    -- Allow re-running the tests via a slash command.
    SLASH_LIBRPMEDIA_SLASHCMD1 = "/lrpm";
    SlashCmdList['LIBRPMEDIA_SLASHCMD'] = RunTests;

    RunTests();
else
    -- Parse CLI arguments.
    local optInterface;

    local offset = 1;
    while offset < #arg do
        local opt = arg[offset];
        offset = offset + 1;

        if opt == "-i" or opt == "--interface" then
            optInterface = tonumber(arg[offset]);
            offset = offset + 1;
        else
            error(strformat("Unknown option: %s", tostring(opt)));
        end
    end

    -- Validate arguments.
    if not optInterface then
        error("No interface version specified (--interface). Aborting.");
    end

    -- Populate the global environment with things that WoW provides, and
    -- that we need for testing.
    _G.GetBuildInfo = function() return "", 0, "", optInterface; end;
    _G.CallErrorHandler = function(...) return ...; end;
    _G.nop = function() end;
    _G.strmatch = string.match;
    _G.tostringall = function(...)
        if select("#", ...) == 0 then
            return;
        end

        return tostring((...)), tostringall(select(2, ...));
    end

    -- Helper function for loading a script.
    local function LoadScript(path, ...)
        local chunk = assert(loadfile(path));
        return chunk(...);
    end

    -- Once everything is set up, we'll load the scripts in manually.
    MAJOR_NAME = "LibRPMedia-1.0";
    local ns = {};

    LoadScript("Libs/LibStub/LibStub.lua", MAJOR_NAME, ns);
    LoadScript("Libs/LibDeflate/LibDeflate.lua", MAJOR_NAME, ns);

    LoadScript("LibRPMedia-1.0.lua", MAJOR_NAME, ns);
    LoadScript("LibRPMedia-Classic-1.0.lua", MAJOR_NAME, ns);
    LoadScript("LibRPMedia-Retail-1.0.lua", MAJOR_NAME, ns);

    -- And then run the tests.
    local pass = RunTests();
    if not pass then
        os.exit(1);
    end
end
