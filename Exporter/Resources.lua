-- This file is licensed under the terms expressed in the LICENSE file.
local ftcsv = require "ftcsv";
local httprequest = require "http.request";
local md5 = require "md5";
local plpath = require "pl.path";
local url = require "socket.url";

local Log = require "Log";
local Serializer = require "Serializer";

-- Upvalues.
local strformat = string.format;
local strmatch = string.match;
local tconcat = table.concat;

-- Local declarations.
local FetchResource;
local IsProcessableFile;
local LoadOrFetchResource;
local ReadCacheData;
local WriteCacheData;

-- Directory for caching.
local CACHE_DIR = os.getenv("LUACASC_CACHE");

-- Maximum size of databases and filelists for caching. Any larger than ths
-- and we run into constant table overflow issues.
local MAX_CACHEABLE_TABLE_SIZE = 200000;

-- Base URL for requests against the public dump service.
local WOW_TOOLS_SCHEME = "https";
local WOW_TOOLS_HOST = "wow.tools";
-- Base URL for obtaining a filelist.
local WOW_TOOLS_FILELIST_PATH = "/casc/listfile/download/csv/build";
-- Base URL for obtaining a database dump.
local WOW_TOOLS_DATABASE_PATH = "/api/export/";

-- Module table.
local Resources = {};

-- Builds a table representing the file list for a given product version
-- as exposed by the Ribbit API.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and the ".files"/".paths" arrays are the data for each
-- row in the file listing from indices 1 through "".size".
function Resources.GetFileList(productVersion)
    -- Load the data from the cache if applicable.
    local cacheName = strformat("filelist.%s", productVersion.buildConfig);
    local cacheData = ReadCacheData(cacheName);
    if cacheData then
        return cacheData;
    end

    -- Structure for our returned filelist.
    local filelist = {
        size  = 0,  -- Size of the file listing.
        files = {}, -- Array of IDs.
        paths = {}, -- Array of paths.
    };

    -- Fetch the resource from the network instead.
    local sourceData = LoadOrFetchResource(url.build({
        scheme = WOW_TOOLS_SCHEME,
        host = WOW_TOOLS_HOST,
        path = WOW_TOOLS_FILELIST_PATH,
        query = tconcat({
            strformat("buildConfig=%s", productVersion.buildConfig),
        }, "&"),
    }));

    -- The data is in a CSV-like format without headers, where each field
    -- is separated by a semicolon.
    Log.Debug("Parsing file list...");
    local rows = ftcsv.parse(sourceData, ";", {
        loadFromString = true,
        headers = false,
    });

    -- Copy the data into the filelist.
    for _, row in ipairs(rows) do
        -- Due to the size of the filelist, we'll omit files that aren't
        -- likely to ever be of much use.
        if IsProcessableFile(row[2]) then
            filelist.size = filelist.size + 1;
            filelist.files[filelist.size] = tonumber(row[1]);
            filelist.paths[filelist.size] = row[2];
        end
    end

    Log.Debug("Parsed file list...", { rows = filelist.size });

    -- Write the data to the cache before yielding it.
    if filelist.size < MAX_CACHEABLE_TABLE_SIZE then
        WriteCacheData(cacheName, filelist);
    else
        Log.Warn("File list is too large for caching.");
    end

    return filelist;
end

-- Builds a table representing an exported client database for a given
-- product version as exposed by the Ribbit API.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and each column in the database has its own array-like
-- table with indices from 1 through ".size" for the row contents.
function Resources.GetDatabase(name, productVersion)
    -- Load the data from the cache if applicable.
    local cacheName = strformat("%s.%s", name, productVersion.buildConfig);
    local cacheData = ReadCacheData(cacheName);
    if cacheData then
        return cacheData;
    end

    -- Base structure for our resulting database.
    local database = {
        size = 0,
    };

    -- Fetch the resource from the network instead.
    local sourceData = LoadOrFetchResource(url.build({
        scheme = WOW_TOOLS_SCHEME,
        host = WOW_TOOLS_HOST,
        path = WOW_TOOLS_DATABASE_PATH,
        query = tconcat({
            strformat("name=%s", name),
            strformat("build=%s", productVersion.versionName),
        }, "&"),
    }));

    -- Database exports are CSV data delimited by commas, and have headers.
    Log.Debug("Parsing database...", { name = name });
    local rows = ftcsv.parse(sourceData, ",", {
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

    Log.Debug("Parsed database.", { rows = database.size });

    -- Write the data to the cache before yielding it.
    if database.size < MAX_CACHEABLE_TABLE_SIZE then
        WriteCacheData(cacheName, database);
    else
        Log.Warn("Database is too large for caching.");
    end

    return database;
end

-- Internal functions.

-- Returns true if the given file path is of interest to the exporter
-- based upon its type.
function IsProcessableFile(filePath)
    -- Filter out extensions.
    local ext = plpath.extension(filePath);
    if ext ~= ".blp"
    and ext ~= ".mp3"
    and ext ~= ".ogg"
    and ext ~= ".tga" then
        return false;
    end

    -- Filter out directory paths.
    if strmatch(filePath, "^character/")
    or strmatch(filePath, "^creature/")
    or strmatch(filePath, "^dungeons/")
    or strmatch(filePath, "^environments/")
    or strmatch(filePath, "^item/")
    or strmatch(filePath, "^particles/")
    or strmatch(filePath, "^screeneffects/")
    or strmatch(filePath, "^sound/ambience/")
    or strmatch(filePath, "^sound/character/")
    or strmatch(filePath, "^sound/creature/")
    or strmatch(filePath, "^sound/doodad/")
    or strmatch(filePath, "^sound/emitters/")
    or strmatch(filePath, "^sound/item/")
    or strmatch(filePath, "^sound/spells/")
    or strmatch(filePath, "^sound/vehicles/")
    or strmatch(filePath, "^spells/")
    or strmatch(filePath, "^test/")
    or strmatch(filePath, "^textures/")
    or strmatch(filePath, "^tileset/")
    or strmatch(filePath, "^users/")
    or strmatch(filePath, "^world/")
    or strmatch(filePath, "^xtextures/") then
        return false;
    end

    return true;
end

-- Reads data previously serialized to the cache, returning it as a Lua value.
--
-- If no cached data can be retrieved, nil is returned.
function ReadCacheData(fileName)
    -- Try to load the file in as a function.
    local filePath = plpath.join(CACHE_DIR, fileName);
    local file = io.open(filePath, "rb");
    if not file then
        -- File doesn't exist.
        return;
    end

    Log.Debug("Reading resource from cache...", { file = fileName });
    local content, rerr = file:read("*a");
    if not content then
        -- IO error; don't purge the content.
        Log.Warn("Error reading resource from cache.", { err = rerr });
        return;
    end

    local chunk, lerr = loadstring(content);
    if not chunk then
        -- Parse error reading the content; purge it.
        Log.Warn("Error loading resource from cache.", { err = lerr });
        os.remove(filePath);
        return;
    end

    -- Execute it in an empty environment.
    local env = setmetatable({}, { __newindex = false, __metatable = false });
    local ok, result = pcall(setfenv(chunk, env));
    if not ok then
        -- The data raised an error; purge it from the cache.
        Log.Warn("Error evaluating resource from cache.", { err = result });
        os.remove(filePath);
        return;
    end

    Log.Debug("Read resource from cache.");
    return result;
end

-- Writes arbitrary data into the cache, serializing it. This can later be
-- reloaded via ReadCacheData to speed up resource processing.
function WriteCacheData(fileName, data)
    -- Attempt to open the file for writing.
    local filePath = plpath.join(CACHE_DIR, fileName);
    local file = assert(io.open(filePath, "wb+"));

    Log.Debug("Writing resource to cache...", { file = fileName });

    -- Serialize the data and write it out.
    assert(file:write("return "));
    assert(file:write(Serializer.Dump(data, {
        lineIndent = "    ",
        lineSuffix = "\n",
        trailingComma = true,
        keyValueSpace = true,
    })));

    assert(file:write(";"));
    assert(file:close());

    Log.Debug("Wrote resource to cache.");
end

-- Fetches a resource from the given URL, returning its content as a string.
--
-- It is recommended to cache the result of this function.
function FetchResource(resourceUrl)
    Log.Debug("Fetching remote resource...", { url = resourceUrl });

    -- Issue a request and check the response.
    local headers, stream = httprequest.new_from_uri(resourceUrl):go();
    if not headers then
        -- No headers means something fundamental went wrong, such as
        -- a failed DNS lookup.
        error(strformat("error fetching resource (%s): %s",
            resourceUrl, stream));
    elseif headers:get(":status") ~= "200" then
        -- Expected a HTTP status 200 response.
        local status = headers:get(":status");
        local message = stream:get_body_as_string();
        if not message or message == "" then
            message = status;
        end

        error(strformat("error fetching resource (%s): error %s: %s",
            resourceUrl, status, message));
    end

    -- Read it into memory and shut down the stream.
    local data = assert(stream:get_body_as_string());
    stream:shutdown();

    Log.Debug("Fetched remote resource.", { bytes = #data });
    return data;
end

-- Attempts to load a networked resource from the cache, and if that
-- fails will instead fetch it from the network.
function LoadOrFetchResource(resourceUrl)
    -- Try to read the resource from the cache.
    local cacheName = strformat("resource.%s", md5.sumhexa(resourceUrl));
    local cacheData = ReadCacheData(cacheName);
    if cacheData then
        return cacheData;
    end

    -- Fetch and then cache it instead.
    local resourceData = FetchResource(resourceUrl);
    if resourceData ~= nil then
        WriteCacheData(cacheName, resourceData);
    end

    return resourceData;
end

-- Module exports.
return Resources;
