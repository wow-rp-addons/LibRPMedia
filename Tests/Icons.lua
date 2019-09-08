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

RegisterTest("Icons: Database Loaded", function()
    -- Verify that icon data is actually present.
    local hasIcons = LibRPMedia:IsIconDataLoaded();
    Assertf(hasIcons, "No icon data loaded in library");
end);

RegisterTest("Icons: Database Size", function()
    -- Verify we have a non-zero count of icons.
    local numIcons = LibRPMedia:GetNumIcons();

    AssertType(numIcons, "number", "Icon count is not numeric");
    Assertf(numIcons > 0, "Invalid icon count: %d", numIcons);

    -- We'll log some characteristics about the database too.
    Logf("Icon database size: %d entries", LibRPMedia:GetNumIcons());
end);

RegisterTest("Icons: API Type Checks", function()
    -- Generate some values of each Lua type.
    local string = "";
    local number = 0;
    local boolean = false;
    local thread = coroutine.create(function() end);
    local userdata = newproxy(false);

    -- The Get<X>ByName functions allow only strings as their parameters.
    AssertNoError(LibRPMedia, "GetIconDataByName", string);
    AssertError(LibRPMedia, "GetIconDataByName", nil);
    AssertError(LibRPMedia, "GetIconDataByName", number);
    AssertError(LibRPMedia, "GetIconDataByName", boolean);
    AssertError(LibRPMedia, "GetIconDataByName", thread);
    AssertError(LibRPMedia, "GetIconDataByName", userdata);

    AssertNoError(LibRPMedia, "GetIconIndexByName", string);
    AssertError(LibRPMedia, "GetIconIndexByName", nil);
    AssertError(LibRPMedia, "GetIconIndexByName", number);
    AssertError(LibRPMedia, "GetIconIndexByName", boolean);
    AssertError(LibRPMedia, "GetIconIndexByName", thread);
    AssertError(LibRPMedia, "GetIconIndexByName", userdata);

    AssertNoError(LibRPMedia, "GetIconFileByName", string);
    AssertError(LibRPMedia, "GetIconFileByName", nil);
    AssertError(LibRPMedia, "GetIconFileByName", number);
    AssertError(LibRPMedia, "GetIconFileByName", boolean);
    AssertError(LibRPMedia, "GetIconFileByName", thread);
    AssertError(LibRPMedia, "GetIconFileByName", userdata);

    AssertNoError(LibRPMedia, "GetIconTypeByName", string);
    AssertError(LibRPMedia, "GetIconTypeByName", nil);
    AssertError(LibRPMedia, "GetIconTypeByName", number);
    AssertError(LibRPMedia, "GetIconTypeByName", boolean);
    AssertError(LibRPMedia, "GetIconTypeByName", thread);
    AssertError(LibRPMedia, "GetIconTypeByName", userdata);

    -- The Get<X>ByIndex functions expect numbers as their parameters.
    AssertNoError(LibRPMedia, "GetIconDataByIndex", number);
    AssertError(LibRPMedia, "GetIconDataByIndex", string);
    AssertError(LibRPMedia, "GetIconDataByIndex", nil);
    AssertError(LibRPMedia, "GetIconDataByIndex", boolean);
    AssertError(LibRPMedia, "GetIconDataByIndex", thread);
    AssertError(LibRPMedia, "GetIconDataByIndex", userdata);

    AssertNoError(LibRPMedia, "GetIconNameByIndex", number);
    AssertError(LibRPMedia, "GetIconNameByIndex", string);
    AssertError(LibRPMedia, "GetIconNameByIndex", nil);
    AssertError(LibRPMedia, "GetIconNameByIndex", boolean);
    AssertError(LibRPMedia, "GetIconNameByIndex", thread);
    AssertError(LibRPMedia, "GetIconNameByIndex", userdata);

    AssertNoError(LibRPMedia, "GetIconFileByIndex", number);
    AssertError(LibRPMedia, "GetIconFileByIndex", string);
    AssertError(LibRPMedia, "GetIconFileByIndex", nil);
    AssertError(LibRPMedia, "GetIconFileByIndex", boolean);
    AssertError(LibRPMedia, "GetIconFileByIndex", thread);
    AssertError(LibRPMedia, "GetIconFileByIndex", userdata);

    AssertNoError(LibRPMedia, "GetIconTypeByIndex", number);
    AssertError(LibRPMedia, "GetIconTypeByIndex", string);
    AssertError(LibRPMedia, "GetIconTypeByIndex", nil);
    AssertError(LibRPMedia, "GetIconTypeByIndex", boolean);
    AssertError(LibRPMedia, "GetIconTypeByIndex", thread);
    AssertError(LibRPMedia, "GetIconTypeByIndex", userdata);

    -- FindIcons is a pain in the butt since it allows a string as the
    -- first parameter only, but either a nil or a table as the last.
    AssertNoError(LibRPMedia, "FindIcons", string, nil);
    AssertError(LibRPMedia, "FindIcons", nil, nil);
    AssertError(LibRPMedia, "FindIcons", number, nil);
    AssertError(LibRPMedia, "FindIcons", boolean, nil);
    AssertError(LibRPMedia, "FindIcons", thread, nil);
    AssertError(LibRPMedia, "FindIcons", userdata, nil);

    AssertNoError(LibRPMedia, "FindIcons", string, {});
    AssertError(LibRPMedia, "FindIcons", string, number);
    AssertError(LibRPMedia, "FindIcons", string, boolean);
    AssertError(LibRPMedia, "FindIcons", string, thread);
    AssertError(LibRPMedia, "FindIcons", string, userdata);
end);

RegisterTest("Icons: Data Lookup (By Index)", function()
    -- Test that each index can be collected into a table, and that each
    -- entry for those indices matches a field name lookup.
    for i = 1, LibRPMedia:GetNumIcons() do
        local iconData = LibRPMedia:GetIconDataByIndex(i);

        AssertType(iconData, "table", "Icon data is not a table");
        Assertf(next(iconData), "Icon data (index %d) is empty", i);

        -- Validate the contents against field name lookups.
        for fieldName, fieldValue in pairs(iconData) do
            local value = LibRPMedia:GetIconDataByIndex(i, fieldName);

            Assertf(fieldValue == value,
                "Field lookup (%s) had differing data: %s ~= %s",
                fieldName, fieldValue, value);
        end
    end
end);

RegisterTest("Icons: Data Lookup (By Name)", function()
    -- Test that each name lookup returns a data table.
    for i = 1, LibRPMedia:GetNumIcons() do
        local iconName = LibRPMedia:GetIconNameByIndex(i);
        local iconData = LibRPMedia:GetIconDataByName(iconName);
        AssertType(iconData, "table", "Icon data is not a table");
        Assertf(next(iconData), "Icon data (name %q) is empty", iconName);

        -- Validate the contents against field name lookups.
        for fieldName, fieldValue in pairs(iconData) do
            local value = LibRPMedia:GetIconDataByName(iconName, fieldName);

            Assertf(fieldValue == value,
                "Field lookup (%s) had differing data: %s ~= %s",
                fieldName, fieldValue, value);
        end
    end
end);

RegisterTest("Icons: Name Lookup (By Index)", function()
    -- Each icon index in the range 1 through GetNumIcons should have a
    -- valid, non-repeating name.
    local names = {};

    for i = 1, LibRPMedia:GetNumIcons() do
        local name = LibRPMedia:GetIconNameByIndex(i);

        AssertType(name, "string", "Icon name is not a string");
        Assertf(name ~= "", "Icon index %d has an empty name", i);

        Assertf(not names[name],
            "Icon index %d has duplicate name: %q (last used by index %d)",
            i, name, names[name]);

        -- Keep track of the names as we go along.
        names[name] = i;
    end
end);

RegisterTest("Icons: Type Lookup (By Index)", function()
    -- Each icon index in the range 1 through GetNumIcons should return
    -- a valid type constant.
    for i = 1, LibRPMedia:GetNumIcons() do
        local iconType = LibRPMedia:GetIconTypeByIndex(i);

        AssertType(iconType, "number", "Icon type is not numeric");
    end
end);

RegisterTest("Icons: File Lookup (By Index)", function()
    -- Each icon index in the range 1 through GetNumIcons should return
    -- a valid file ID.
    for i = 1, LibRPMedia:GetNumIcons() do
        local iconFile = LibRPMedia:GetIconFileByIndex(i);

        AssertType(iconFile, "number", "Icon file ID is not numeric");
    end
end);

RegisterTest("Icons: Index Lookup (By Name)", function()
    -- Mapping each index from 1 through GetNumIcons to a name and back to an
    -- index again should result in the same index.
    for i = 1, LibRPMedia:GetNumIcons() do
        local name = LibRPMedia:GetIconNameByIndex(i);
        local index = LibRPMedia:GetIconIndexByName(name);

        AssertType(index, "number", "Icon index is not numeric");
        Assertf(index == i,
            "Icon name %q maps to index %d, expected %d",
            name, index, i);
    end
end);

RegisterTest("Icons: Type Lookup (By Name)", function()
    -- Iterate over each icon index, get the type, then map that to a name.
    for i = 1, LibRPMedia:GetNumIcons() do
        local name = LibRPMedia:GetIconNameByIndex(i);
        local want = LibRPMedia:GetIconTypeByIndex(i);
        local have = LibRPMedia:GetIconTypeByName(name);

        AssertType(have, "number", "Looked-up icon type is not a numeric");
        AssertType(want, "number", "Expected icon type is not a numeric");
        Assertf(have == want,
            "Icon %q by-index has type %d, but has type %d by-name.",
            name, want, have);
    end
end);

RegisterTest("Icons: File Lookup (By Name)", function()
    -- Iterate over each icon index, get the file ID, then map that to a name.
    for i = 1, LibRPMedia:GetNumIcons() do
        local name = LibRPMedia:GetIconNameByIndex(i);
        local want = LibRPMedia:GetIconFileByIndex(i);
        local have = LibRPMedia:GetIconFileByName(name);

        AssertType(have, "number", "Looked-up file ID is not numeric");
        AssertType(want, "number", "Expected file ID is not numeric");
        Assertf(have == want,
            "Icon %q by-index is file %s, but is file %s by-name.",
            name, tostring(want), tostring(have));
    end
end);

RegisterTest("Icons: Invalid Lookups", function()
    -- Each function that is given a correctly-typed but otherwise invalid
    -- value for lookup should return nil to indicate no match.
    local count = LibRPMedia:GetNumIcons();

    -- Test ranges outside of 1 through GetNumIcons for index lookups.
    Assert(LibRPMedia:GetIconDataByIndex(-1) == nil,
        "Expected nil icon data.");

    Assert(LibRPMedia:GetIconDataByIndex(count + 1) == nil,
        "Expected nil icon data.");

    Assert(LibRPMedia:GetIconNameByIndex(-1) == nil,
        "Expected nil icon name.");

    Assert(LibRPMedia:GetIconNameByIndex(count + 1) == nil,
        "Expected nil icon name.");

    Assert(LibRPMedia:GetIconFileByIndex(-1) == nil,
        "Expected nil icon file ID.");

    Assert(LibRPMedia:GetIconFileByIndex(count + 1) == nil,
        "Expected nil icon file ID.");

    Assert(LibRPMedia:GetIconTypeByIndex(-1) == nil,
        "Expected nil icon type.");

    Assert(LibRPMedia:GetIconTypeByIndex(count + 1) == nil,
        "Expected nil icon type.");

    -- Test invalid icon names.
    Assert(LibRPMedia:GetIconDataByName("") == nil,
        "Expected nil icon data.");

    Assert(LibRPMedia:GetIconIndexByName("") == nil,
        "Expected nil icon index.");

    Assert(LibRPMedia:GetIconFileByName("") == nil,
        "Expected nil icon file ID.");

    Assert(LibRPMedia:GetIconTypeByName("") == nil,
        "Expected nil icon type.");

    -- Data lookups involving invalid fields should return nil.
    local validIconName = LibRPMedia:GetIconNameByIndex(1);

    Assert(LibRPMedia:GetIconDataByIndex(1, "-") == nil,
        "Expected nil result.");
    Assert(LibRPMedia:GetIconDataByName(validIconName, "-") == nil,
        "Expected nil result.");
end);

RegisterTest("Icons: Find All", function()
    -- Finding all icons should result in a number of results equal to the
    -- size of the database, and for each result we should validate the
    -- values against the lookup functions.
    local numIcons = 0;
    for index, name in LibRPMedia:FindAllIcons() do
        numIcons = numIcons + 1;

        -- Check the types of each value from the iterator.
        AssertType(index, "number", "Icon index is not numeric");
        AssertType(name, "string", "Icon name is not a string");

        -- Querying things via the index should compare the same as the
        -- data from our iterator.
        local wantedIndex, wantedName;

        wantedName = LibRPMedia:GetIconNameByIndex(index);
        Assertf(name == wantedName,
            "Icon name %q does not match name for index %d (%q)",
            name, index, wantedName or "<nil>");

        -- Repeat this time looking up by name.
        wantedIndex = LibRPMedia:GetIconIndexByName(name);
        Assertf(index == wantedIndex,
            "Icon index %d does not match index for name %q (%s)",
            index, name, wantedIndex or "<nil>");
    end

    Assertf(numIcons == LibRPMedia:GetNumIcons(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumIcons(), numIcons);
end);

RegisterTest("Icons: Find by Prefix", function()
    -- Search with a specific query and confirm all names in the results
    -- have the same prefix as the query.
    local query = "ability_";
    local options = { method = "prefix" };

    local numIcons = 0;
    for _, name in LibRPMedia:FindIcons(query, options) do
        local prefix = string.sub(name, 1, #query);
        Assertf(prefix == query,
            "Expected prefix %q, got name: %q (prefix: %q)",
            query, name, prefix);

        numIcons = numIcons + 1;
    end

    -- Verify that we found something at least.
    Assert(numIcons > 0, "Test did not iterate over any icons");
end);

RegisterTest("Icons: Find by Substring", function()
    -- Search with a specific query and confirm all names in the results
    -- contain the matched string.
    local query = "potion";
    local options = { method = "substring" };

    local numIcons = 0;
    for _, name in LibRPMedia:FindIcons(query, options) do
        Assertf(string.find(name, query, 1, true),
            "Expected substring %q, got name: %q",
            query, name);

        numIcons = numIcons + 1;
    end

    -- Verify that we found something at least.
    Assert(numIcons > 0, "Test did not iterate over any files");
end);

RegisterTest("Icons: Find by Pattern", function()
    -- Search with a specific query and confirm all names in the results
    -- are valid hits against the pattern.
    local query = "inv_weapon_halberd_%d+";
    local options = { method = "pattern" };

    local numIcons = 0;
    for _, name in LibRPMedia:FindIcons(query, options) do
        Assertf(string.find(name, query),
            "Expected pattern match %q, got name: %q",
            query, name);

        numIcons = numIcons + 1;
    end

    -- Verify that we found something at least.
    Assert(numIcons > 0, "Test did not iterate over any files");
end);

RegisterTest("Icons: Default Find Method", function()
    -- The default search method should perform a prefix search. The below
    -- query is what we'll test with for this across all datasets.
    local query = "spell_";

    local numIcons = 0;
    for _, name in LibRPMedia:FindIcons(query) do
        local prefix = string.sub(name, 1, #query);
        Assertf(prefix == query,
            "Expected prefix %q, got name: %q (prefix: %q)",
            query, name, prefix);

        numIcons = numIcons + 1;
    end

    -- Verify that we found something at least.
    Assert(numIcons > 0, "Test did not iterate over any files");
end);

RegisterTest("Icons: Empty Find Query", function()
    -- An empty find query should always return all files.
    local numIcons = 0;
    for _ in LibRPMedia:FindIcons("") do
        numIcons = numIcons + 1;
    end

    Assertf(numIcons == LibRPMedia:GetNumIcons(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumIcons(), numIcons);
end);

RegisterTest("Icons: Find All (By Pattern)", function()
    -- We'll verify that when finding matching files all the data returned
    -- matches the stuff yielded from explicit lookups.
    local query = ".+";
    local options = { method = "pattern" };

    local numIcons = 0;
    local seenIcons = {};

    for index, name in LibRPMedia:FindIcons(query, options) do
        -- Verify return types.
        AssertType(index, "number", "Icon index is not numeric");
        AssertType(name, "string", "Icon name is not a string");

        local wantedIndex = LibRPMedia:GetIconIndexByName(name);
        Assertf(index == wantedIndex,
            "Icon index %d does not match index for name %q (%s)",
            index, name, wantedIndex or "<nil>");

        local wantedName = LibRPMedia:GetIconNameByIndex(index);
        Assertf(name == wantedName,
            "Icon name %s does not match name at index %d (%s)",
            name, index, wantedName or "<nil>");

        -- Verify this file hasn't been seen before.
        Assertf(not seenIcons[name],
            "Icon %s returned twice by iterator",
            name);

        numIcons = numIcons + 1;
        seenIcons[name] = true;
    end

    -- Verify each file was returned.
    Assertf(numIcons == LibRPMedia:GetNumIcons(),
        "Expected to find %d files, found %d",
        LibRPMedia:GetNumIcons(), numIcons);
end);
