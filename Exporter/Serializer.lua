-- This file is licensed under the terms expressed in the LICENSE file.

-- Upvalues.
local strformat = string.format;
local strmatch = string.match;
local strrep = string.rep;
local tconcat = table.concat;
local tinsert = table.insert;
local tsort = table.sort;

-- Local declarations.
local CopyTable;
local DumpTable;
local DumpTableArray;
local DumpTablePair;
local DumpTablePairs;
local FormatTableLine;
local GetCustomSerializer;
local GetOptionValue;
local IsHashTable;
local JoinString;

-- Module table.
local Serializer = {};

-- Default options used by the serializer.
Serializer.DefaultOptions = {
	-- Prefix to prepend to the start of each line. This is appended for
	-- each key/value pair within a table, as well as the table end (}).
    linePrefix = "",
	-- Indentation string, repeated for each level of depth. This is placed
	-- after LinePrefix on each suitable line.
    lineIndent = "",
	-- Suffix to append to the end of each line. This is applied to the end
	-- of each table start ({), and any key/value pairs within tables.
    lineSuffix = "",
    -- If true, include a trailing comma on the last entry in a table.
    trailingComma = false,
    -- If true, include spaces around "=" in table assignments.
    keyValueSpace = false,
	-- Indentation depth. Defaults to zero. Incremented each time a new table
	-- is started.
    indentDepth = 0,
};

-- Dumps a given Lua value in a serializable form, optionally with the given
-- options corresponding to those defined in Serializer.DefaultOptions.
function Serializer.Dump(value, options)
    -- Check for a __serialize metamethod first.
    local serializer = GetCustomSerializer(value);
    if serializer then
        return serializer(value, options);
    end

    -- Otherwise dispatch based upon type.
    local valueType = type(value);
    if valueType == "string" then
        return strformat("%q", value);
    elseif valueType == "number" then
        return tostring(value);
    elseif valueType == "boolean" then
        return value and "true" or "false";
    elseif valueType == "nil" then
        return "nil";
    elseif valueType == "table" then
        return DumpTable(value, options);
    else
        error(strformat("cannot serialize given type: %s", valueType), 2);
    end
end

-- Internal functions.

-- Returns a named option value from the given options table, or a suitable
-- default if no value can be obtained.
function GetOptionValue(options, key)
    if type(options) ~= "table" then
        return Serializer.DefaultOptions[key];
    end

    local value = options[key];
    if value == nil then
        return Serializer.DefaultOptions[key];
    end

    return value;
end

-- Joins a string with the given delimiter.
function JoinString(delim, ...)
    return tconcat({ ... }, delim);
end

-- Returns true if the given table is an associated hash table.
function IsHashTable(table)
    for key in pairs(table) do
        -- Non-numeric keys, or keys outside the range 1 through #value will
        -- flag this as being a hash table when serialized.
        if type(key) ~= "number" or key < 0 or key > #table then
            return true;
        end
    end

    return false;
end

-- Performs a shallow copy on the given table, returning its duplicate.
function CopyTable(table)
    local out = {};
    for k, v in pairs(table) do
        out[k] = v;
    end

    return out;
end

-- Dumps the given table recursively with the given options.
function DumpTable(table, options)
    -- Shortcut for empty tables.
    if not next(table) then
        return "{}";
    end

    -- Extract the options for this table.
    local linePrefix = GetOptionValue(options, "linePrefix");
    local lineIndent = GetOptionValue(options, "lineIndent");
    local lineSuffix = GetOptionValue(options, "lineSuffix");
    local indentDepth = GetOptionValue(options, "indentDepth");
    local indentString = strrep(lineIndent, indentDepth);

    -- Start writing out the table.
    local output = {};
    tinsert(output, JoinString("", "{", lineSuffix));

    -- Copy the options and increment the indent depth.
    local suboptions = CopyTable(options);
    suboptions.indentDepth = indentDepth + 1;

    if not IsHashTable(table) then
        -- Writing an array.
        DumpTableArray(output, table, suboptions);
    else
        -- Writing key/value pairs as a hash table.
        DumpTablePairs(output, table, suboptions);
    end

    -- Finish off the table.
    tinsert(output, JoinString("", linePrefix, indentString, "}"))
    return tconcat(output, "");
end

-- Formats a given line string for a table entry (pair or array item) with
-- the proper prefix, indent, and suffix strings according to the given
-- options.
function FormatTableLine(line, options)
    local linePrefix = GetOptionValue(options, "linePrefix");
    local lineIndent = GetOptionValue(options, "lineIndent");
    local lineSuffix = GetOptionValue(options, "lineSuffix");
    local indentDepth = GetOptionValue(options, "indentDepth");
    local indentString = strrep(lineIndent, indentDepth);

    return JoinString("", linePrefix, indentString, line, lineSuffix);
end

-- Dumps an array-like table, writing each individual item string to the
-- given output table.
function DumpTableArray(output, table, options)
    -- Grab options for dumping.
    local trailingComma = GetOptionValue(options, "trailingComma");

    for i = 1, #table do
        local value = table[i];
        local itemString = Serializer.Dump(value, options);

        -- Add a trailing comma if needed.
        if i < #table or trailingComma then
            itemString = itemString .. ",";
        end

        tinsert(output, FormatTableLine(itemString, options));
    end
end

-- Dumps all key/value pairs in the given table, writing each individual
-- pair string to the given output table.
function DumpTablePairs(output, table, options)
    -- Grab options for dumping.
    local trailingComma = GetOptionValue(options, "trailingComma");

    -- We'll sort the keys alphabetically for stability.
    local sortedKeys = {};
    for key in pairs(table) do
        tinsert(sortedKeys, key);
    end

    tsort(sortedKeys, function(a, b)
        return tostring(a) < tostring(b);
    end);

    -- Iterate in order of the sorted keys.
    for i = 1, #sortedKeys do
        local key = sortedKeys[i];
        local value = table[key];
        local pairString = DumpTablePair(key, value, options);

        -- Add a trailing comma if needed.
        if i < #sortedKeys or trailingComma then
            pairString = pairString .. ",";
        end

        tinsert(output, FormatTableLine(pairString, options));
    end
end

-- Dumps a table key value pair to a string.
function DumpTablePair(key, value, options)
    local keyValueSpace = GetOptionValue(options, "keyValueSpace");

    -- If the key is basic, we can get away with "key = value" type
    -- serialization; otherwise it'll need to be "[key] = value".
    local keyString;
    if strmatch(tostring(key), "^[%a_][%w_]*$") then
        keyString = tostring(key);
    else
        keyString = Serializer.Dump(key, options);
        keyString = strformat("[%s]", keyString);
    end

    -- The value is straightforward.
    local valueString = Serializer.Dump(value, options);

    -- Join the key/value to a single line for this pair.
    if keyValueSpace then
        return strformat("%s = %s", keyString, valueString);
    else
        return strformat("%s=%s", keyString, valueString);
    end
end

-- Returns any custom serializer function attached to the given value.
function GetCustomSerializer(value)
    -- Rather than complicate checks, just do it in a pcall.
    local ok, result = pcall(function()
        local metatable = getmetatable(value);
        return metatable.__serialize;
    end);

    return ok and result or nil;
end

-- Module exports.
return Serializer;
