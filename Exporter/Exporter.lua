-- This file is licensed under the terms expressed in the LICENSE file.

-- Fiddle with the package path a bit to allow our working directory to
-- be the root of the repository prior to loading packages.
package.path = package.path .. ";./Exporter/?.lua;./Exporter/?/init.lua";

local casc = require "casc";
local ftcsv = require "ftcsv";
local httprequest = require "http.request";
local lfs = require "lfs";
local md5 = require "md5";
local plpath = require "pl.path";

local floor = math.floor;
local min = math.min;
local strbyte = string.byte;
local strfind = string.find;
local strformat = string.format;
local strlower = string.lower;
local strrep = string.rep;
local strsub = string.sub;
local tconcat = table.concat;
local tinsert = table.insert;
local tsort = table.sort;

-- Options

local USAGE_TEXT = [[
%s [flags]
Exports databases based on information obtained from public dumps.

Flags:
    -c, --config        Path to a configuration file for the exporter.
    -m, --manifest      Path to a file where the manifest will be written.
    -o, --output        Path to a file where the databases will be written.
    -p, --product       Product to generate databases for.
    -r, --region        CDN region to obtain data from.
    -t, --template      Path to the template file for database generation.
]];

-- Cache directory.
local OptCacheDir = os.getenv("LUACASC_CACHE");
-- Config file path.
local OptConfig;
-- Manifest file path.
local OptManifest;
-- Output file path.
local OptOutput;
-- Product to generate data for.
local OptProduct;
-- CDN region to use.
local OptRegion = "us";
-- Template file path.
local OptTemplate;
-- If true, enable debug logging.
local OptVerbose = (os.getenv("DEBUG") == "1");

-- Read options in nice and early.
local argi = 1;
while argi < #arg do
    local argv = arg[argi];
    argi = argi + 1;

    if argv == "-c" or argv == "--config" then
        OptConfig = tostring(arg[argi]);
        argi = argi + 1;
    elseif argv == "-m" or argv == "--manifest" then
        OptManifest = tostring(arg[argi]);
        argi = argi + 1;
    elseif argv == "-o" or argv == "--output" then
        OptOutput = tostring(arg[argi]);
        argi = argi + 1;
    elseif argv == "-p" or argv == "--product" then
        OptProduct = tostring(arg[argi]);
        argi = argi + 1;
    elseif argv == "-r" or argv == "--region" then
        OptRegion = tostring(arg[argi]);
        argi = argi + 1;
    elseif argv == "-t" or argv == "--template" then
        OptTemplate = tostring(arg[argi]);
        argi = argi + 1;
    else
        print(strformat(USAGE_TEXT, arg[0]));
        print(strformat("Unknown option: %s", argv));
        os.exit(1);
    end
end

-- Validate options.
if not OptConfig or OptConfig == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No config file specified (--config)");
    os.exit(1);
elseif not OptManifest or OptManifest == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No manifest file specified (--manifest)");
    os.exit(1);
elseif not OptOutput or OptOutput == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No output file specified (--output)");
    os.exit(1);
elseif not OptProduct or OptProduct == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No product name specified (--output)");
    os.exit(1);
elseif not OptRegion or OptRegion == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No CDN region specified (--region)");
    os.exit(1);
elseif not OptTemplate or OptTemplate == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No template file specified (--region)");
    os.exit(1);
end

-- Utilities

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
local function BinarySearch(table, predicate, i, j)
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

--- Returns the length of the longest common prefix between two strings.
local function GetCommonPrefixLength(a, b)
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
local function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for k, v in pairs(mixin) do
            object[k] = v;
        end
    end

    return object;
end

-- Creates a new object from the specified mixins.
local function CreateFromMixins(...)
    return Mixin({}, ...);
end

-- Raises a formatted error message at the specified stack level. If no level
-- is given, it will default to the caller of the function.
local function Errorf(level, fmt, ...)
    if type(level) ~= "number" then
        -- Use level 2 since we want the caller of this function.
        return Errorf(2, level, fmt, ...);
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

-- Wraps the given text in an ANSI color escape sequence.
local function WrapTextInColorCode(text, color)
    return strformat("\27[%s%s\27[0m", color, text);
end

-- Logging

-- Start time for logging.
local LOG_START_TIME = os.time();

-- Enumeration of log levels.
local LogLevels = {
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4,
};

-- Mapping of log levels to ANSI color codes.
local LogLevelColors = {
    [LogLevels.Debug] = "32m",
    [LogLevels.Info] = "34m",
    [LogLevels.Warn] = "33m",
    [LogLevels.Error] = "31m",
};

-- Logs a message with the specified level to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogMessage(level, message, data)
    -- Get the color for this log message.
    local color = LogLevelColors[level] or "37m";

    -- Collect all the fields in the data table.
    local fields = {};
    if type(data) == "table" then
        for key, value in pairs(data) do
            local keyString = WrapTextInColorCode(tostring(key), color);
            local valueString = tostring(value);

            tinsert(fields, strformat("%s=%s", keyString, valueString));
        end
    end

    -- Sort the strings due to the use of pairs and it not being determinate.
    table.sort(fields);
    fields = tconcat(fields, " ");

    -- Format the final message content.
    local seconds = os.time() - LOG_START_TIME;
    seconds = strformat("[%03d]", seconds);
    seconds = WrapTextInColorCode(seconds, color);

    local output = strformat("%s %-36s %s", seconds, message, fields);
    io.stderr:write(output, "\n");
end

-- Logs a debug message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogDebug(message, data)
    if not OptVerbose then
        return;
    end

    return LogMessage(LogLevels.Debug, message, data);
end

-- Logs an informational message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogInfo(message, data)
    return LogMessage(LogLevels.Info, message, data);
end

-- Logs a warning message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogWarn(message, data)
    return LogMessage(LogLevels.Warn, message, data);
end

-- Logs an error message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogError(message, data)
    return LogMessage(LogLevels.Error, message, data);
end

-- Logs a fatal error message to the output stream, and then calls error.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
local function LogFatal(message, data)
    LogError(message, data);
    error(message, 2);
end

-- Serialization

-- Default options used by the serializer.
local SerializeOptionsDefault = {
    linePrefix = "",
    lineIndent = "",
    lineSuffix = "",
    trailingComma = false,
    keyValueSpace = false,
    indentDepth = 0,
};

-- Serializer options that'll produce a compact output on a single line
-- but with spacing around each record in a table.
local SerializeOptionsSingleLine = CreateFromMixins(SerializeOptionsDefault, {
    lineSuffix = " ",
    keyValueSpace = true,
});

-- Pretty version of the options used by the serializer.
local SerializeOptionsPretty = CreateFromMixins(SerializeOptionsDefault, {
    lineIndent = "    ",
    lineSuffix = "\n",
    trailingComma = true,
    keyValueSpace = true,
});

local SerializeValue;

-- Returns any custom serializer implementation on the given value.
local function GetCustomSerializer(value)
    local meta = getmetatable(value);
    if type(meta) == "table" then
        return rawget(meta, "__serialize");
    end
end

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

-- Serializes the contents of a table, without its surrounding braces. The
-- contents will be formatted according to the given options table.
local function SerializeTableEntries(table, options)
    local linePrefix = GetSerializerOption(options, "linePrefix");
    local lineIndent = GetSerializerOption(options, "lineIndent");
    local lineSuffix = GetSerializerOption(options, "lineSuffix");
    local trailingComma = GetSerializerOption(options, "trailingComma");
    local keyValueSpace = GetSerializerOption(options, "keyValueSpace");
    local indentDepth = GetSerializerOption(options, "indentDepth");
    local indentString = strrep(lineIndent, indentDepth);

    -- Work out the size of the array portion of the table.
    local narr = 0;
    while table[narr + 1] do
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
            keyString = strformat("[%s]", SerializeValue(key, options));
        end

        local value = table[key];
        local valueString = SerializeValue(value, options);

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
        local valueString = SerializeValue(value, options);

        -- Add in a trailing comma if needed.
        local entry = valueString;
        if i < narr or trailingComma then
            entry = entry .. ",";
        end

        tinsert(buffer, linePrefix .. indentString .. entry .. lineSuffix);
    end

    return tconcat(buffer, "");
end

-- Serializes the entirety of a table to a string, formatting it as specified
-- by the given options table.
local function SerializeTable(table, options)
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
    local suboptions = CreateFromMixins(options or SerializeOptionsDefault);
    suboptions.indentDepth = indentDepth + 1;

    -- Serialize the contents.
    tinsert(buffer, SerializeTableEntries(table, suboptions));

    -- Finish the table.
    tinsert(buffer, linePrefix .. indentString .. "}");
    return tconcat(buffer, "");
end

-- Serializes a generic Lua value to a string, formatting it as specified
-- by the given options table.
function SerializeValue(value, options)
    local serializer = GetCustomSerializer(value);
    if serializer then
        return serializer(value, options);
    end

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
        return SerializeTable(value, options);
    else
        return Errorf("cannot serialize given type: %s", valueType);
    end
end

-- Reads previously serialized data from the given file handle, returning
-- it. This will consume all contents of the file, but won't close it.
local function ReadSerializedData(file)
    local body, readErr = file:read("*a");
    if readErr then
        Errorf("error reading serialized data: %s", readErr);
    end

    -- Allow loading of data that wasn't written with a "return " expression.
    if not strfind(body, "^return ") then
        body = "return " .. body;
    end

    local chunk, loadErr = loadstring(body);
    if not chunk then
        Errorf("error parsing serialized data: %s", loadErr);
    end

    local env = setmetatable({}, { __newindex = false, __metatable = false });
    local ok, data = pcall(setfenv(chunk, env));
    if not ok then
        Errorf("error loading serialized data: %s", data);
    end

    return data;
end

-- Serializes the given data and writes it out to the given file handle,
-- allowing it to be later loaded via ReadSerializedData.
local function WriteSerializedData(file, data)
    local ok, content = pcall(SerializeValue, data, SerializeOptionsPretty);
    if not ok then
        Errorf("error serializing data: %s", content);
    end

    local written, writeErr = file:write("return ", content, ";");
    if writeErr then
        Errorf("error writing serailized data: %s", writeErr);
    end

    return written;
end

-- Loads serialized data from the file at the specified path.
local function LoadSerializedData(filePath)
    local file, fileErr = io.open(filePath, "rb");
    if not file then
        Errorf("error opening manifest for reading: %s", fileErr);
    end

    local ok, result = pcall(ReadSerializedData, file);
    file:close();

    if not ok then
        error(result);
    end

    return result;
end

-- Serializes the given data and writes it to the specified file path.
local function SaveSerializedData(filePath, data)
    local file, fileErr = io.open(filePath, "wb");
    if not file then
        Errorf("error opening file for writing: %s", fileErr);
    end

    local ok, result = pcall(WriteSerializedData, file, data);
    file:close();

    if not ok then
        error(result);
    end

    return result;
end

-- Serializable Structures

-- Serializer metatable that will force its applied table to be written
-- out in a compact form.
local CompactSerializer = {};

function CompactSerializer:__serialize()
    return SerializeTable(self, SerializeOptionsDefault);
end

-- Serializer metatable that will force its applied table to be written
-- out in a compact-but-pretty form on a single line with added spacing.
local SingleLineSerializer = {};

function SingleLineSerializer:__serialize()
    return SerializeTable(self, SerializeOptionsSingleLine);
end

-- Serializer metatable that will pretty-print the applied table.
local PrettySerializer = {};

function PrettySerializer:__serialize(options)
    -- We need to propagate the indent depth down.
    return SerializeTable(self, CreateFromMixins(SerializeOptionsPretty, {
        indentDepth = options.indentDepth,
    }));
end

-- Array metatable that will perform incremental encoding (front coding)
-- on serialized strings, storing a common prefix length and string delta
-- pair only.
local FrontCodedArray = {};

function FrontCodedArray:__serialize(options)
    -- Collect all the items into a temporary table, calculating the
    -- differences between them and then serialize that instead.
    local encoded = {};
    for i = 1, #self do
        local previous = self[i - 1] or "";
        local current = self[i];

        local commonLength = GetCommonPrefixLength(previous, current);
        tinsert(encoded, commonLength);
        tinsert(encoded, strsub(current, commonLength + 1));
    end

    return CompactSerializer.__serialize(encoded, options);
end

-- CDN query functions.

-- Returns the URL for querying the patch server for the specified product
-- and locale.
local function GetProductPatchServerURL(product, locale)
    return strformat("http://%s.patch.battle.net:1119/%s/", locale, product);
end

-- Returns a table of build information obtained from the patch servers
-- for the given product in the specified locale.
local function GetProductBuildInfo(product, locale)
    local endpoint = GetProductPatchServerURL(product, locale);
    local bkey, cdn, ckey, version = casc.cdnbuild(endpoint, locale);
    if not bkey then
        Errorf("error querying CDN: %s", cdn);
    end

    return {
        bkey = bkey,
        ckey = ckey,
        version = version,
        cdn = cdn,
    };
end

-- Resources

-- Base URL for resource requests.
local RESOURCE_URL = "https://wow.tools";
-- Base URL for database requests.
local DATABASE_URL = RESOURCE_URL .. "/api/export/?name=%s&build=%s";
-- Base URL for filelist requests.
local FILELIST_URL =
    RESOURCE_URL .. "/casc/listfile/download/csv/build?buildConfig=%s";

-- Returns a file path that can be used to store the resource pointed to
-- by the given URL.
--
-- Returns nil if caching is disabled, or if the cache directory doesn't
-- exist.
local function GetResourceFilePath(url)
    if lfs.attributes(OptCacheDir, "mode") ~= "directory" then
        return;
    end

    local fileName = strformat("resource.%s", md5.sumhexa(url));
    return plpath.join(OptCacheDir, fileName);
end

-- Attempts to load a resource identified from the given URL from the
-- local cache, returning its data if found or nil if the file doesn't
-- exist.
local function LoadResourceFromCache(url)
    local filePath = GetResourceFilePath(url);
    if not filePath then
        return;
    end

    if lfs.attributes(filePath, "mode") ~= "file" then
        return;
    end

    return LoadSerializedData(filePath);
end

-- Saves the given resource to the cache in a file identified by the given
-- resource URL.
local function SaveResourceToCache(resource, url)
    local filePath = GetResourceFilePath(url);
    if not filePath then
        return;
    end

    SaveSerializedData(filePath, resource);
end

-- Fetches a resource from a remote server identified by the given resource
-- URL.
local function FetchRemoteResource(url)
    -- Issue a request and check the response.
    local headers, stream = httprequest.new_from_uri(url):go();
    if not headers then
        -- No headers means something fundamental went wrong, such as
        -- a failed DNS lookup.
        Errorf("error fetching resource (%s): %s", url, stream);
    elseif headers:get(":status") ~= "200" then
        -- Expected a HTTP status 200 response.
        local status = headers:get(":status");
        Errorf("error fetching resource (%s): status code %s", url, status);
    end

    -- Read it into memory and shut down the stream.
    local data, err = stream:get_body_as_string();
    if not data then
        Errorf("error fetching resource (%s): %s", url, err);
    end

    stream:shutdown();
    return data;
end

-- Attempts to load any cached data for a given resource URL and returns its
-- data, before falling back to obtaining it from the network.
--
-- If a network request is issued, the data is cached before being returned.
local function LoadOrFetchResource(url)
    local data = LoadResourceFromCache(url);
    if data ~= nil then
        LogDebug("Loaded resource from cache.", { url = url });
        return data;
    end

    LogDebug("Downloading remote resource...", { url = url });
    data = FetchRemoteResource(url);

    if data ~= nil then
        LogDebug("Writing resource to cache...", { url = url });
        SaveResourceToCache(data, url);
    end

    return data;
end

-- Builds a table representing the file list for a given product version.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and the ".files"/".paths" arrays are the data for each
-- row in the file listing from indices 1 through ".size".
local function GetClientFileList(build)
    -- Structure for our returned filelist.
    local filelist = {
        size  = 0,  -- Size of the file listing.
        files = {}, -- Array of IDs.
        paths = {}, -- Array of paths.
    };

    -- Fetch the data.
    local url = strformat(FILELIST_URL, build.bkey);
    local data = LoadOrFetchResource(url);

    -- The data is in a CSV-like format without headers, where each field
    -- is separated by a semicolon.
    local rows = ftcsv.parse(data, ";", {
        loadFromString = true,
        headers = false,
    });

    -- Copy the data into the filelist.
    for _, row in ipairs(rows) do
        filelist.size = filelist.size + 1;
        filelist.files[filelist.size] = tonumber(row[1]);
        filelist.paths[filelist.size] = row[2];
    end

    return filelist;
end

-- Builds a table representing an exported client database for a given
-- product version.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and each column in the database has its own array-like
-- table with indices from 1 through ".size" for the row contents.
local function GetClientDatabase(name, build)
    LogInfo("Fetching client database...", {
        name = name,
        version = build.version,
    });

    -- Base structure for our resulting database.
    local database = {
        size = 0,
    };

    -- Fetch the resource from the network instead.
    local url = strformat(DATABASE_URL, name, build.version);
    local data = LoadOrFetchResource(url);

    -- Database exports are CSV data delimited by commas, and have headers.
    local rows = ftcsv.parse(data, ",", {
        loadFromString = true,
        headers = true,
    });

    -- Copy the data into the database.
    for _, row in ipairs(rows) do
        database.size = database.size + 1;

        -- Copy the fields into their appropriate tables.
        for field, value in pairs(row) do
            local values = database[field];
            if not database[field] then
                values = {};
                database[field] = values;
            end

            values[database.size] = value;
        end
    end

    return database;
end

-- Shared Resources
--
-- The following declarations are upvalues to be used by the rest of the
-- script and will be initialized later.

-- Configuration table as loaded from the config file.
local Config;
-- Versioning data for this product build.
local BuildInfo;
-- CASC storage container.
local CASCStore;
-- File list for the configured build.
local FileList;
-- Manifest root being generated for this build.
local Manifest;
-- Database root being generated for this build.
local Database;

-- Magic table for accessing client database dumps in a cached manner.
-- Simply index the table with the name of the database.
local DBC = setmetatable({}, {
    __index = function(self, name)
        LogInfo("Fetching client database...", { name = name });
        rawset(self, name, GetClientDatabase(name, BuildInfo));
        return rawget(self, name);
    end,
});

-- Icon Database

-- Enumeration of icon types. Entries here must be present in the library.
local IconType = {
    File = 1,
    Atlas = 2,
};

-- Returns the name for an icon based on its file path.
local function GetIconNameFromFile(path)
    local name = plpath.splitext(plpath.basename(path));
    return strlower(name);
end

-- Returns true if the given file path is valid as an icon.
local function IsValidIconFile(path)
    -- Reject paths not in the icons folder.
    if not strfind(strlower(path), "^interface/icons/") then
        return false;
    end

    -- Check the name against the blacklist patterns.
    local name = GetIconNameFromFile(path);
    for _, pattern in ipairs(Config.icons.blacklist) do
        if strfind(name, pattern) then
            return false;
        end
    end

    return true;
end

-- Returns the index that the named icon should be located at in the given
-- manifest table.
local function FindIconIndexByName(manifest, name)
    return BinarySearch(manifest, function(_, index)
        return manifest[index].name >= name;
    end);
end

-- Inserts the given icon into the manifest. Raises an error if another
-- icon with the same name already exists.
local function InsertIconIntoManifest(manifest, icon)
    local index = FindIconIndexByName(manifest, icon.name);
    if index <= #manifest and manifest[index].name == icon.name then
        Errorf("duplicate icon in manifest: %s", icon.name);
    end

    tinsert(manifest, index, icon);
end

-- Builds the manifest for icons. The manifest exports all the data that
-- is then compacted into the database in a later stage.
local function BuildIconManifest()
    -- Wipe the existing manifest data as we don't cache anything useful.
    local manifest = {};

    -- Iterate over the filelist and find icons in the known directory,
    -- filtering out those in the blacklist.
    LogInfo("Collecting icon files...");

    for i = 1, FileList.size do
        local path = FileList.paths[i];
        local name = GetIconNameFromFile(path);

        if IsValidIconFile(path) then
            -- Update/create the icon data.
            local icon = setmetatable({}, SingleLineSerializer);
            icon.name = name;
            icon.type = IconType.File;

            InsertIconIntoManifest(manifest, icon);
        end
    end

    return manifest;
end

-- Builds the database for icons as a compacted representation of the
-- given manifest for use by the library.
local function BuildIconDatabase(manifest)
    -- Create the initial database.
    local database = {};
    database.size = #manifest;
    database.data = {
        name = setmetatable({}, FrontCodedArray),
        type = setmetatable({}, CompactSerializer),
    };

    -- Copy the data from the manifest to the database.
    LogInfo("Building icon database...", { entries = database.size });

    for index, icon in ipairs(manifest) do
        tinsert(database.data.name, icon.name);

        -- Due to the sparseness of atlases vs files, we'll omit files and
        -- treat the type table as a map of indices => non-file-types.
        if icon.type ~= IconType.File then
            database.data.type[index] = icon.type;
        end
    end

    return database;
end

-- Entrypoint

-- TODO: Remove.
OptManifest = "Test.manifest.lua";
OptOutput = "Test.database.lua";
OptProduct = "wowt";

local function Main()
    -- Warn if caching can't take place.
    if lfs.attributes(OptCacheDir, "mode") ~= "directory" then
        LogWarn("Cache directory not found.", { path = OptCacheDir });
    end

    -- Load the configuration file.
    LogInfo("Loading configuration...", { path = OptConfig });
    Config = LoadSerializedData(OptConfig);

    -- Load the manifest if one exists.
    if lfs.attributes(OptManifest, "mode") == "file" then
        LogInfo("Loading manifest...", { path = OptManifest });
        local ok, result = pcall(LoadSerializedData, OptManifest);
        if not ok then
            LogWarn("Error loading manifest.", { err = result });
        else
            Manifest = result;
        end
    end

    -- Create a manifest if one wasn't loaded.
    if not Manifest then
        Manifest = setmetatable({}, PrettySerializer);
    end

    -- Obtain the latest build information.
    LogInfo("Fetching build information...", { product = OptProduct });
    BuildInfo = GetProductBuildInfo(OptProduct, OptRegion);

    -- Persist build information in the manifest.
    Manifest.build = { hash = BuildInfo.bkey, version = BuildInfo.version };
    LogInfo("Obtained build information.", Manifest.build);

    -- Load the file list for this build.
    LogInfo("Fetching client file list...");
    FileList = GetClientFileList(BuildInfo);

    -- Open the CASC storage container.
    CASCStore = assert(casc.open(BuildInfo));

    -- Update the manifest for each database type.
    LogInfo("Building icon manifest...");
    Manifest.icons = BuildIconManifest(Manifest.icons or {});

    -- Write the manifest out.
    LogInfo("Writing manifest file...", { path = OptManifest });
    SaveSerializedData(OptManifest, Manifest);

    -- Generate the actual database contents.
    Database = setmetatable({}, PrettySerializer);
    Database.icons = BuildIconDatabase(Manifest.icons);

    -- TODO: Template.
    LogInfo("Writing database contents...", { path = OptOutput });
    SaveSerializedData(OptOutput, Database);
end

local ok, err = pcall(Main);
if not ok then
    LogFatal("Error exporting databases.", { err = err });
end
