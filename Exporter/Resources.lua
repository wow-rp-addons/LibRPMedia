-- This file is licensed under the terms expressed in the LICENSE file.
local csv = require "csv";
local httprequest = require "http.request";
local md5 = require "md5";
local lfs = require "lfs";
local plpath = require "pl.path";
local url = require "socket.url";

-- Upvalues.
local strformat = string.format;
local tconcat = table.concat;

-- Local declarations.
local GetDatabaseURL;
local GetFileListURL;
local OpenResourceStream;

-- Base directory for caching.
local BASE_CACHE_DIR = plpath.join(lfs.currentdir(), ".cache");

-- Base URL for requests against the public dump service.
local WOW_TOOLS_SCHEME = "https";
local WOW_TOOLS_HOST = "wow.tools";
-- Base URL for obtaining a filelist.
local WOW_TOOLS_FILELIST_PATH = "/casc/listfile/download/csv/build"; --?buildConfig=%s";
-- Base URL for obtaining a database dump.
local WOW_TOOLS_DATABASE_PATH = "/api/export/"; --?name=achievement&build=8.2.5.31337";

-- Module table.
local Resources = {};

-- Builds a table representing the file list for a given product version
-- as exposed by the Ribbit API.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and the ".files"/".paths" arrays are the data for each
-- row in the file listing from indices 1 through "".size".
function Resources.GetFileList(productVersion)
    -- Open the resource.
    local resourceUrl = GetFileListURL(productVersion);
    local file = OpenResourceStream(resourceUrl);

    -- Structure for our returned filelist.
    local filelist = {
        size  = 0,  -- Size of the file listing.
        files = {}, -- Array of IDs.
        paths = {}, -- Array of paths.
    };

    -- The data is in a CSV-like format without headers, where each field
    -- is separated by a semicolon.
    local rows = csv.use(file, { separator = ";" });
    for row in rows:lines() do
        filelist.size = filelist.size + 1;
        filelist.files[filelist.size] = tonumber(row[1]);
        filelist.paths[filelist.size] = row[2];
    end

    file:close();
    return filelist;
end

-- Builds a table representing an exported client database for a given
-- product version as exposed by the Ribbit API.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and each column in the database has its own array-like
-- table with indices from 1 through ".size" for the row contents.
function Resources.GetDatabase(name, productVersion)
    -- Open the resource.
    local resourceUrl = GetDatabaseURL(name, productVersion);
    local file = OpenResourceStream(resourceUrl);

    -- Base structure for our resulting database.
    local database = {
        size = 0,
    };

    -- Database exports are CSV data delimited by commas, and have headers.
    local rows = csv.use(file, { separator = ",", header = true });
    for row in rows:lines() do
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

    file:close();
    return database;
end

-- Internal functions.

-- Returns a URL for fetching a file list resource.
function GetFileListURL(productVersion)
    return url.build({
        scheme = WOW_TOOLS_SCHEME,
        host = WOW_TOOLS_HOST,
        path = WOW_TOOLS_FILELIST_PATH,
        query = tconcat({
            strformat("buildConfig=%s", productVersion.buildConfig),
        }, "&"),
    });
end

-- Returns a URL for fetching a database resource.
function GetDatabaseURL(name, productVersion)
    return url.build({
        scheme = WOW_TOOLS_SCHEME,
        host = WOW_TOOLS_HOST,
        path = WOW_TOOLS_DATABASE_PATH,
        query = tconcat({
            strformat("name=%s", name),
            strformat("build=%s", productVersion.versionName),
        }, "&"),
    });
end

-- Opens a stream containing the data for the resource hosted at the specified
-- URL. The stream has an interface identical to Lua's file type.
--
-- If the resource is locally cached, the file stored will be used. If not
-- locally stored, it will be fetched from the network first and then opened.
function OpenResourceStream(resourceUrl)
    -- Check if the file locally exists in the cache.
    local fileName = md5.sumhexa(resourceUrl);
    local filePath = plpath.join(BASE_CACHE_DIR, fileName);

    local file = io.open(filePath, "rb");
    if not file then
        -- Ensure the cache directory exists.
        if not lfs.attributes(BASE_CACHE_DIR, "mode") then
            assert(lfs.mkdir(BASE_CACHE_DIR));
        end

        -- File isn't cached; attempt to fetch it from the network.
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

        -- Store it locally before yielding.
        file = assert(io.open(filePath, "wb+"));
        assert(stream:save_body_to_file(file));
        stream:shutdown();
        file:close();

        -- Re-open the file in read-only mode once more.
        file = assert(io.open(filePath, "rb"));
    end

    return file;
end

-- Module exports.
return Resources;


