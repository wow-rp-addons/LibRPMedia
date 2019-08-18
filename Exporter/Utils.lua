-- This file is licensed under the terms expressed in the LICENSE file.

-- Upvalues.
local floor = math.floor;
local min = math.min;
local strbyte = string.byte;
local strformat = string.format;
local tinsert = table.insert;
local tremove = table.remove;

-- Utilities module.
local Utils = {};

-- Performs a binary search over the given table elements from the range
-- i, j (defaulting to 1, #table) if not given.
--
-- For each index tested, the given predicate will be called with the table
-- and current index.
--
-- This function returns the index of the found item if any, or it will
-- return the index where the item could be inserted. It is up to the
-- caller to test if table[n] matches the requested data if wanting to find
-- an exact match.
function Utils.BinaryIndex(table, predicate, i, j)
    local l = i or 1;
    local r = (j or #table) + 1;

    while l < r do
        local m = floor((l + r) / 2);
        if not predicate(table, m) then
            l = m + 1;
        else
            r = m;
        end
    end

    return l;
end

-- Performs a binary search for an exact value in a table, returning its
-- index if found.
--
-- The search assumes the table is sorted in ascending order, and that
-- elements can be compared with the >= and == operators.
function Utils.BinarySearch(table, value)
    local index = Utils.BinaryIndex(table, function(_, index)
        return table[index] >= value;
    end);

    if index <= #table and table[index] == value then
        return index;
    end
end

-- Inserts a given value into a table by performing a binary search. If
-- unique is true, the value will only be inserted if an exact match does
-- not already exist.
--
-- Returns the index the item was inserted at on success.
--
-- The search assumes the table is sorted in ascending order, and that
-- elements can be compared with the >= and == operators.
function Utils.BinaryInsert(table, value, unique)
    local index = Utils.BinaryIndex(table, function(_, index)
        return table[index] >= value;
    end);

    if unique and index <= #table and table[index] == value then
        Utils.Errorf("attempted to insert duplicate value into table: %s",
            tostring(value));
    end

    tinsert(table, index, value);
    return index;
end

-- Removes a given value from a table by performing a binary search. The
-- search removes only the first found matching value.
--
-- Returns the index the input was found at on success, otherwise nil.
--
-- The search assumes the table is sorted in ascending order, and that
-- elements can be compared with the >= and == operators.
function Utils.BinaryRemove(table, value)
    local index = Utils.BinarySearch(table, value);
    if index then
        tremove(table, index);
        return index;
    end
end

--- Returns the length of the longest common prefix between two strings.
function Utils.GetCommonPrefixLength(a, b)
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

-- Mixes in the given list of source objects into a target object.
function Utils.Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;
        end
    end

    return object;
end

-- Creates a new object from the specified mixins.
function Utils.CreateFromMixins(...)
    return Utils.Mixin({}, ...);
end

-- Raises a formatted error message at the specified stack level. If no level
-- is given, it will default to the caller of the function.
function Utils.Errorf(level, fmt, ...)
    if type(level) ~= "number" then
        -- Use level 2 since we want the caller of this function.
        return Utils.Errorf(2, level, fmt, ...);
    end

    -- Errors should appear to come from the caller.
    level = level + 1;

    local ok, result = pcall(strformat, fmt, ...);
    if not ok then
        error(strformat("unknown error (%s)", tostring(result)), level);
    else
        error(result, level);
    end
end

-- Recursively merges a given source table into a target table. This function
-- does not protect against infinite recursion.
function Utils.Merge(target, source)
    for k, v in pairs(source) do
        if type(target[k]) == "table" and type(v) == "table" then
            target[k] = Utils.Merge(target[k], v);
        else
            target[k] = v;
        end
    end

    return target;
end

-- Wraps the given text in an ANSI color escape sequence.
function Utils.WrapTextInColorCode(text, color)
    return strformat("\27[%s%s\27[0m", color, text);
end

-- Module exports.
return Utils;
