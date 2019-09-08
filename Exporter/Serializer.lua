-- This file is licensed under the terms expressed in the LICENSE file.
local Utils = require "Exporter.Utils";

-- Upvalues.
local strfind = string.find;
local strformat = string.format;
local strrep = string.rep;
local strsub = string.sub;
local tconcat = table.concat;
local tinsert = table.insert;
local tsort = table.sort;

-- Default serializer options.
local SerializeOptionsDefault = {
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

-- Returns a keyed option for the serializer from the given options table,
-- defaulting to the default options table if the key cannot be found.
local function GetSerializerOption(options, key)
    if type(options) ~= "table" then
        return SerializeOptionsDefault[key];
    end

    local value = options[key];
    if value == nil then
        return SerializeOptionsDefault[key];
    end

    return value;
end

-- Serializer module.
local Serializer = {};

-- Options table for compact output by the serializer. This uses no spacing
-- and all data is written out on one line.
Serializer.OptionsCompact = Utils.CreateFromMixins(SerializeOptionsDefault);

-- Options table for spaced output by the serializer. Output occurs on a
-- single line, but table contents will have spaces between entries.
Serializer.OptionsSpaced = Utils.CreateFromMixins(SerializeOptionsDefault, {
    lineSuffix = " ",
    keyValueSpace = true,
});

-- Options table for pretty output by the serializer. Output is broken onto
-- multiple lines with spacing and trailing commas.
Serializer.OptionsPretty = Utils.CreateFromMixins(SerializeOptionsDefault, {
    lineIndent = "    ",
    lineSuffix = "\n",
    trailingComma = true,
    keyValueSpace = true,
});


-- Returns any custom serializer implementation on the given value.
function Serializer.GetCustomSerializer(value)
    local meta = getmetatable(value);
    if type(meta) == "table" then
        return rawget(meta, "__serialize");
    end
end

-- Serializes a generic Lua value to a string, formatting it as specified
-- by the given options table.
function Serializer.Dump(value, options)
    local impl = Serializer.GetCustomSerializer(value);
    if impl then
        return impl(value, options or {});
    end

    return Serializer.DumpRaw(value, options);
end

-- Serializes a generic Lua value to a string, formatting it as specified
-- by the given options table.
--
-- This function will not trigger any custom serializer on the given value.
function Serializer.DumpRaw(value, options)
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
        return Serializer.DumpTable(value, options);
    else
        return Utils.Errorf("cannot serialize given type: %s", valueType);
    end
end

-- Serializes the entirety of a table to a string, formatting it as specified
-- by the given options table.
function Serializer.DumpTable(table, options)
    -- Shortcut for empty tables.
    if next(table) == nil then
        return "{}";
    end

    local linePrefix = GetSerializerOption(options, "linePrefix");
    local lineIndent = GetSerializerOption(options, "lineIndent");
    local lineSuffix = GetSerializerOption(options, "lineSuffix");
    local indentDepth = GetSerializerOption(options, "indentDepth");
    local indentString = strrep(lineIndent, indentDepth);

    -- Start the table.
    local buffer = {};
    tinsert(buffer, "{" .. lineSuffix);

    -- Copy the options and increment the indent depth.
    local suboptions = Utils.CreateFromMixins(options or {});
    suboptions.indentDepth = indentDepth + 1;

    -- Serialize the contents.
    tinsert(buffer, Serializer.DumpTableEntries(table, suboptions));

    -- Finish the table.
    tinsert(buffer, linePrefix .. indentString .. "}");
    return tconcat(buffer, "");
end

-- Serializes the contents of a table, without its surrounding braces. The
-- contents will be formatted according to the given options table.
function Serializer.DumpTableEntries(table, options)
    local linePrefix = GetSerializerOption(options, "linePrefix");
    local lineIndent = GetSerializerOption(options, "lineIndent");
    local lineSuffix = GetSerializerOption(options, "lineSuffix");
    local trailingComma = GetSerializerOption(options, "trailingComma");
    local keyValueSpace = GetSerializerOption(options, "keyValueSpace");
    local indentDepth = GetSerializerOption(options, "indentDepth");
    local indentString = strrep(lineIndent, indentDepth);

    -- Work out the size of the array portion of the table.
    local narr = 0;
    while table[narr + 1] ~= nil do
        narr = narr + 1;
    end

    -- Get the keys for the key/value records, ignoring array indices.
    local recordKeys = {};
    for key in pairs(table) do
        if type(key) ~= "number" or key < 0 or key > narr then
            tinsert(recordKeys, key);
        end
    end

    tsort(recordKeys, function(a, b) return tostring(a) < tostring(b); end);

    -- Handle the key/value records first.
    local buffer = {};
    for i = 1, #recordKeys do
        -- If the key isn't simple, we need to surround it in braces.
        local key = recordKeys[i];
        local keyString;
        if type(key) == "string" and strfind(key, "^[%a_][%w_]*$") then
            keyString = tostring(key);
        else
            keyString = strformat("[%s]", Serializer.Dump(key, options));
        end

        local value = table[key];
        local valueString = Serializer.Dump(value, options);

        -- Join the key/value into one string for the record.
        local entry;
        if keyValueSpace then
            entry = strformat("%s = %s", keyString, valueString);
        else
            entry = strformat("%s=%s", keyString, valueString);
        end

        -- Add in a trailing comma if needed.
        if i < #recordKeys or trailingComma then
            entry = entry .. ",";
        end

        tinsert(buffer, linePrefix .. indentString .. entry .. lineSuffix);
    end

    -- Handle the array portion of the table next.
    for i = 1, narr do
        local value = table[i];
        local valueString = Serializer.Dump(value, options);

        -- Add in a trailing comma if needed.
        local entry = valueString;
        if i < narr or trailingComma then
            entry = entry .. ",";
        end

        tinsert(buffer, linePrefix .. indentString .. entry .. lineSuffix);
    end

    return tconcat(buffer, "");
end

-- Reads previously serialized data from the given file handle, returning
-- it. This will consume all contents of the file, but won't close it.
function Serializer.ReadFile(file)
    local body, readErr = file:read("*a");
    if readErr then
        Utils.Errorf("error reading serialized data: %s", readErr);
    end

    -- Allow loading of data that wasn't written with a "return " expression.
    if not strfind(body, "^return ") then
        body = "return " .. body;
    end

    local chunk, loadErr = loadstring(body);
    if not chunk then
        Utils.Errorf("error parsing serialized data: %s", loadErr);
    end

    local env = setmetatable({}, { __newindex = false, __metatable = false });
    local ok, data = pcall(setfenv(chunk, env));
    if not ok then
        Utils.Errorf("error loading serialized data: %s", data);
    end

    return data;
end

-- Serializes the given data and writes it out to the given file handle,
-- allowing it to be later loaded via ReadSerializedData.
function Serializer.WriteFile(file, data, options)
    local ok, content = pcall(Serializer.Dump, data, options);
    if not ok then
        Utils.Errorf("error serializing data: %s", content);
    end

    local written, writeErr = file:write(content);
    if writeErr then
        Utils.Errorf("error writing serialized data: %s", writeErr);
    end

    return written;
end

-- Loads serialized data from the file at the specified path.
function Serializer.LoadFile(filePath)
    local file, fileErr = io.open(filePath, "rb");
    if not file then
        Utils.Errorf("error opening file for reading: %s", fileErr);
    end

    local ok, result = pcall(Serializer.ReadFile, file);
    file:close();

    if not ok then
        error(result);
    end

    return result;
end

-- Serializes the given data and writes it to the specified file path.
function Serializer.SaveFile(filePath, data, options)
    local file, fileErr = io.open(filePath, "wb");
    if not file then
        Utils.Errorf("error opening file for writing: %s", fileErr);
    end

    local ok, result = pcall(function()
        local content = Serializer.Dump(data, options);

        local _, err = file:write("return ", content, ";");
        if err then
            Utils.Errorf("error writing serialized data: %s", err);
        end
    end);

    if not ok then
        error(result);
    end
end

-- Serializer Mixins

-- Serializer mixin that will force its applied table to be written
-- out in a compact form.
local CompactSerializer = {};

-- Creates a new table that will serialize its contents in a compact format.
--
-- If a table is given, the metatable of it is replaced wit that of the
-- CompactSerializer serializer.
function Serializer.CreateCompactTable(t)
    return setmetatable(t or {}, CompactSerializer);
end

function CompactSerializer:__serialize(options)
    options = Utils.CreateFromMixins(Serializer.OptionsCompact, {
        indentDepth = GetSerializerOption(options, "indentDepth"),
    });

    return Serializer.DumpRaw(self, options);
end

-- Serializer mixin that will force its applied table to be written
-- out in a compact-but-pretty form on a single line with added spacing.
local SpacedSerializer = {};

-- Creates a new table that will serialize its contents in a spaced format.
--
-- If a table is given, the metatable of it is replaced wit that of the
-- SpacedSerializer serializer.
function Serializer.CreateSpacedTable(t)
    return setmetatable(t or {}, SpacedSerializer);
end

function SpacedSerializer:__serialize(options)
    options = Utils.CreateFromMixins(Serializer.OptionsSpaced, {
        indentDepth = GetSerializerOption(options, "indentDepth"),
    });

    return Serializer.DumpRaw(self, options);
end

-- Serializer mixin that will pretty-print the applied table.
local PrettySerializer = {};

-- Creates a new table that will serialize its contents in a pretty format.
--
-- If a table is given, the metatable of it is replaced with that of the
-- PrettySerializer serializer.
function Serializer.CreatePrettyTable(t)
    return setmetatable(t or {}, PrettySerializer);
end

function PrettySerializer:__serialize(options)
    options = Utils.CreateFromMixins(Serializer.OptionsPretty, {
        indentDepth = GetSerializerOption(options, "indentDepth"),
    });

    return Serializer.DumpRaw(self, options);
end

-- Serializer mixin that will perform incremental encoding (front coding)
-- on serialized strings, storing a common prefix length and string delta
-- pair only.
local FrontCodedStringList = {};

-- Creates a new front-coded string array. If a table is given, the metatable
-- of it is replaced wit that of the FrontCodedStringList serializer.
function Serializer.CreateFrontCodedStringList(t)
    return setmetatable(t or {}, FrontCodedStringList);
end

function FrontCodedStringList:__serialize(options)
    -- Collect all the items into a temporary table, calculating the
    -- differences between them and then serialize that instead.
    local encoded = {};
    for i = 1, #self do
        local previous = self[i - 1] or "";
        local current = self[i];

        local commonLength = Utils.GetCommonPrefixLength(previous, current);
        tinsert(encoded, commonLength);
        tinsert(encoded, strsub(current, commonLength + 1));
    end

    return Serializer.DumpRaw(encoded, options);
end

--- Sentinel value that can be inserted into arrays for serialization as nil
--  values.
local NilSentinel = setmetatable({}, {
    __serialize = function() return "nil"; end,
});

-- Module exports.
Serializer.CompactSerializer = CompactSerializer;
Serializer.SpacedSerializer = SpacedSerializer;
Serializer.PrettySerializer = PrettySerializer;
Serializer.FrontCodedStringList = FrontCodedStringList;
Serializer.NilSentinel = NilSentinel;

return Serializer;
