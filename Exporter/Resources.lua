-- This file is licensed under the terms expressed in the LICENSE file.
local Log = require "Exporter.Log";
local Utils = require "Exporter.Utils";

local casc = require "Exporter.casc";

local csv = require "csv";
local lfs = require "lfs";
local plpath = require "pl.path";

-- Upvalues.
local strformat = string.format;
local strlower = string.lower;

-- Enumeration of resource types.
local ResourceType = {
    FileList = 1,
    Database = 2,
    FileContent = 3,
    TactKeys = 4,
};

-- Base URL for the patch server.
local PATCH_SERVER_URL = "http://%s.patch.battle.net:1119/%s/";
-- Base URL for database requests.
local DATABASE_URL = "https://wow.tools/api/export/?name=%s&build=%s";
-- Base URL for filelist requests.
local FILELIST_URL = "https://wow.tools/casc/listfile/download/csv/build?buildConfig=%s";
-- Base URL for TACT keys.
local TACTKEYS_URL = "https://raw.githubusercontent.com/wowdev/TACTKeys/master/WoW.txt";

-- Resources module.
local Resources = {
    -- Directory used for caching obtained content.
    cacheDir = plpath.join(plpath.currentdir(), ".cache"),
    -- Name of the product to manage resources for.
    productName = "wow",
    -- Region of the patch server to contact.
    region = "us",

    -- Cached build info for this product/region.
    build = nil,
    -- CASC store handle for this product/region.
    store = nil,
    -- Cached filelist for this product.
    filelist = nil,
    -- Cached databases for this product.
    databases = {},

    -- Mapping of database names to version overrides.
    databaseVersions = {},
};

-- Returns the directory used for storing locally cached resources.
function Resources.GetCacheDirectory()
    return Resources.cacheDir;
end

-- Sets the directory used for storing locally cached resources.
function Resources.SetCacheDirectory(cacheDir)
    assert(type(cacheDir) == "string", "cacheDir must be a string");
    Resources.cacheDir = cacheDir;
end

-- Returns the product name for which resources are managed.
function Resources.GetProductName()
    return Resources.productName;
end

-- Sets the product name to manage resources for.
function Resources.SetProductName(productName)
    assert(type(productName) == "string", "productName must be a string");
    Resources.productName = productName;

    -- Invalidate all resources.
    Resources.build = nil;
    Resources.filelist = nil;
    Resources.databases = {};
    Resources.store = nil;
end

-- Returns the patch server/CDN region for obtaining resources.
function Resources.GetRegion()
    return Resources.region;
end

-- Sets the patch server/CDN region for obtaining resources.
function Resources.SetRegion(region)
    assert(type(region) == "string", "region must be a string");
    Resources.region = strlower(region);

    -- Invalidate anything that's region-sensitive.
    Resources.build = nil;
    Resources.store = nil;
end

-- Returns the override mapping of versions to use for database requests.
function Resources.GetDatabaseVersionOverrides()
    return Resources.databaseVersions;
end

-- Sets the override mapping of versions to use for database requests.
function Resources.SetDatabaseVersionOverrides(versions)
    assert(type(versions) == "table", "versions must be a table");
    Resources.databaseVersions = versions;
end

-- Returns a table of build information obtained from the patch servers
-- for the given product in the specified locale.
--
-- The returned table may be passed as-is to the embedded casc library to
-- open a remote storage container.
function Resources.GetBuildInfo()
    -- Check to see if build info is already cached.
    if Resources.build then
        return Resources.build;
    end

    -- Fetch latest information from the patch server.
    local region = Resources.region;
    local productName = Resources.productName;
    local url = strformat(PATCH_SERVER_URL, region, productName);

    Log.Info("Fetching build information...", { region = region, product = productName });

    local bkey, cdn, ckey, version = casc.cdnbuild(url, region);
    if not bkey then
        Utils.Errorf("error querying patch server: %s", cdn);
    end

    -- Structure the build data. The format is usable by the underlying
    -- casc library as-is.
    local build = {
        -- Build configuration hash.
        bkey = bkey,
        -- Product configuration hash.
        ckey = ckey,
        -- Product version string (eg. "1.2.3.4567").
        version = version,
        -- List of CDN servers.
        cdn = cdn,
    };

    Resources.build = build;
    return build;
end

-- Builds a table representing the file list for a given product version.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and the ".files"/".paths" arrays are the data for each
-- row in the file listing from indices 1 through ".size".
function Resources.GetFileList()
    -- Check to see if a filelist is already loaded.
    if Resources.filelist then
        return Resources.filelist;
    end

    -- Structure for our returned filelist.
    local filelist = {
        size  = 0,  -- Size of the file listing.
        files = {}, -- Array of IDs.
        paths = {}, -- Array of paths.
    };

    -- Fetch the resource.
    Log.Info("Fetching client file list...");

    local stream, err = Resources.OpenResource(ResourceType.FileList);
    if not stream then
        Utils.Errorf("error opening file list: %s", err);
    end

    -- The data is in a CSV-like format without headers, where each field
    -- is separated by a semicolon.
    local rows = csv.use(stream, { separator = ";", header = false });
    for row in rows:lines() do
        filelist.size = filelist.size + 1;
        filelist.files[filelist.size] = tonumber(row[1]);
        filelist.paths[filelist.size] = row[2];
    end

    Resources.CloseResource(stream);
    Resources.filelist = filelist;
    return filelist;
end

-- Builds a table representing an exported client database for a given
-- product version.
--
-- The table is structured as an SoA style table; the ".size" field is the
-- number of entries, and each column in the database has its own array-like
-- table with indices from 1 through ".size" for the row contents.
function Resources.GetDatabase(name)
    -- Check to see if this database is already loaded.
    if Resources.databases[name] then
        return Resources.databases[name];
    end

    -- Base structure for our resulting database.
    local database = {
        size = 0,
    };

    -- Fetch the resource.
    Log.Info("Fetching client database...", {
        name = name,
        version = Resources.GetDatabaseVersion(name),
    });

    local stream, err = Resources.OpenResource(ResourceType.Database, name);
    if not stream then
        Utils.Errorf("error opening database: %s", err);
    end

    -- Database exports are CSV data delimited by commas, and have headers.
    local rows = csv.use(stream, { separator = ",", header = true });
    for row in rows:lines() do
        -- Ignore rows that have only one field and are empty. These seem
        -- to sometimes get spat out by the CSV library.
        local firstKey, firstValue = next(row);
        if firstValue ~= "" or next(row, firstKey) then
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
    end

    Resources.CloseResource(stream);
    Resources.databases[name] = database;
    return database;
end

-- Returns the version for a named database. This will consult the versions
-- set by SetDatabaseVersions first, and if fails will instead use the version
-- of the current build.
function Resources.GetDatabaseVersion(name)
    local overrides = Resources.GetDatabaseVersionOverrides();
    if overrides[name] then
        return overrides[name];
    end

    local build = Resources.GetBuildInfo();
    return build.version;
end

-- Returns a table of locale variants for the given file ID.
function Resources.GetFileVariants(fileID)
    local store = Resources.GetCASCStore();
    local variants, err = store:getFileVariants(fileID);

    if not variants then
        Utils.Errorf("error obtaining file variants: %s", err);
    end

    return variants;
end

-- Returns the content hash for a file identified by the given file ID,
-- optionally scoped to the given locale variant.
function Resources.GetFileContentHash(fileID, locale)
    local store = Resources.GetCASCStore();
    local hash, err = store:getFileContentHash(fileID, locale);

    if not hash then
        Utils.Errorf("error obtaining file content hash: %s", err);
    end

    return hash;
end

-- Returns the file path for the given file. The path may or may not exist,
-- use IsFileContentDownloaded to check for existence of the file.
function Resources.GetFileContentPath(fileID, locale)
    local fileHash = Resources.GetFileContentHash(fileID, locale);
    return Resources.GetResourceFilePath(ResourceType.FileContent, fileHash);
end

-- Reads in the content of a file identified by the given file ID, optionally
-- scoped to the given locale variant.
function Resources.GetFileContent(fileID, locale)
    -- If the file hasn't been downloaded, get it.
    os.remove(Resources.GetFileContentPath(fileID, locale));
    if not Resources.IsFileContentDownloaded(fileID, locale) then
        Resources.DownloadFileContent(fileID, locale);
    end

    -- Open the file up.
    local filePath = Resources.GetFileContentPath(fileID, locale);
    local file, err = io.open(filePath, "rb");
    if not file then
        -- Failed to open the file.
        Utils.Errorf("error opening file for reading: %s", err);
    end

    -- Read the content in.
    local content, cerr = file:read("*a");
    if not content then
        -- Failed to read the content.
        file:close();
        Utils.Errorf("error reading file: %s", cerr);
    end

    file:close();
    return content;
end

-- Returns true if the refernced file has been locally downloaded.
function Resources.IsFileContentDownloaded(fileID, locale)
    local filePath = Resources.GetFileContentPath(fileID, locale);
    if lfs.attributes(filePath, "mode") ~= "file" then
        return false;
    end

    return true;
end

-- Downloads the referenced file, storing it locally. Does nothing if the
-- file has already been downloaded.
function Resources.DownloadFileContent(fileID, locale)
    -- No-op if already downloaded.
    if Resources.IsFileContentDownloaded(fileID, locale) then
        return;
    end

    -- Get the content from the CASC store.
    Log.Debug("Fetching file content...", { file = fileID, locale = locale });

    local store = Resources.GetCASCStore();
    local content, cerr = store:readFile(fileID, locale);
    if not content then
        -- Failed to read the file content.
        Utils.Errorf("error reading file from storage: %s", cerr);
    end

    -- Open the file for writing and write the contents out.
    local filePath = Resources.GetFileContentPath(fileID, locale);
    local file, err = io.open(filePath, "wb");
    if not file then
        -- Failed to open the file.
        Utils.Errorf("error opening file for writing: %s", err);
    end

    local written, werr = file:write(content);
    if not written then
        -- Failed to write the file. Close and remove it.
        file:close();
        os.remove(filePath);

        Utils.Errorf("error writing to file: %s", werr);
    end

    file:close();
end

-- Returns the CASC storage container handle for this module.
function Resources.GetCASCStore()
    -- Check to see if a store has already been opened.
    if Resources.store then
        return Resources.store;
    end

    -- Add the cache directory and keys to the configuration if set.
    local config = Utils.CreateFromMixins(Resources.GetBuildInfo(), {
        -- Cache directory path must be absolute.
        cache = plpath.abspath(Resources.GetCacheDirectory()),
        keys = Resources.GetTactKeys(),
    });

    -- Open the container.
    local store, err = casc.open(config);
    if not store then
        Utils.Errorf("error opening CASC store: %s", err);
    end

    Resources.store = store;
    return store;
end

-- Returns the remote URL that can be used to fetch a given resource. If no
-- URL is available for this resource type, nil is returned.
function Resources.GetResourceURL(resourceType, ...)
    -- Dispatch based on the requested resource.
    if resourceType == ResourceType.FileList then
        local build = Resources.GetBuildInfo();
        return strformat(FILELIST_URL, build.bkey);
    elseif resourceType == ResourceType.Database then
        -- Input should be the database name.
        local version = Resources.GetDatabaseVersion((...));
        return strformat(DATABASE_URL, (...), version);
    elseif resourceType == ResourceType.TactKeys then
        return TACTKEYS_URL;
    end

    -- Invalid resource type, or the given type isn't fetchable.
    return nil;
end

-- Returns the cache filepath for a given resource. If caching is disabled,
-- this will return nil.
function Resources.GetResourceFilePath(resourceType, ...)
    -- If caching is flat out disabled then we can't possibly work it out.
    local cacheDir = Resources.GetCacheDirectory();
    if not cacheDir then
        return nil;
    end

    -- The filename is derived from the type of the resources.
    local fileName;
    if resourceType == ResourceType.FileList then
        local build = Resources.GetBuildInfo();
        fileName = strformat("filelist.%s", build.bkey);
    elseif resourceType == ResourceType.Database then
        -- Input should be the database name.
        local build = Resources.GetBuildInfo();
        fileName = strformat("database.%s.%s", (...), build.bkey);
    elseif resourceType == ResourceType.FileContent then
        -- Input should be the content hash.
        fileName = strformat("file.%s", (...));
    else
        -- Unknown resource type.
        return nil;
    end

    return plpath.join(cacheDir, fileName);
end

-- Opens a resource identified by the given type and parameters, returning
-- a file handle that can be read for its contents.
--
-- It is the responsibility of the caller to close the returned file handle
-- either by calling its close() method or CloseResource(file).
--
-- On success, returns a file handle. On failure, returns nil and an error.
function Resources.OpenResource(resourceType, ...)
    -- A resource with no URL is impossible to source.
    local url = Resources.GetResourceURL(resourceType, ...);
    if not url then
        return nil, "resource has no source url";
    end

    -- Try and open any cached file first.
    local filePath = Resources.GetResourceFilePath(resourceType, ...);
    if filePath then
        local file = io.open(filePath, "rb");
        if file then
            -- File exists locally, return the handle.
            return file, nil;
        end
    end

    -- Failed to open; grab it from the network.
    local pipe, perr = io.popen(strformat("curl -s %q", url), "r");
    if not pipe then
        -- Failed to run the command.
        return nil, strformat("error running command: %s", perr);
    end

    -- Otherwise open the file in write/update mode and copy the data there.
    local file = filePath and io.open(filePath, "wb+") or nil;
    if not file then
        -- Failed to open for writing; yield the pipe.
        return pipe, nil;
    end

    -- Read in the contents and write them out.
    local content, cerr = pipe:read("*a");
    if not content then
        -- Read error; assume the pipe is busted.
        pipe:close();
        file:close();
        os.remove(filePath);

        return nil, strformat("error while reading data: %s", cerr);
    end

    -- Close the pipe now since we don't need it beyond this point.
    pipe:close();

    local written, werr = file:write(content);
    if not written then
        -- Write error; the pipe has already been consumed.
        file:close();
        os.remove(filePath);

        return nil, strformat("error while writing data: %s", werr);
    end

    -- Seek to the start of the file and yield the handle.
    local spos, serr = file:seek("set", 0);
    if not spos then
        -- Seek error; we'll close and discard this attempt.
        file:close();
        os.remove(filePath);

        return nil, strformat("error while seeking file: %s", serr);
    end

    return file;
end

-- Closes a resource that was previously opened by OpenResource.
--
-- This is the same as calling the close method on the file object, but
-- exists for symmetry in the API.
function Resources.CloseResource(file)
    return file:close();
end

function Resources.GetTactKeys()
    Log.Info("Downloading encryption keys", { url = TACTKEYS_URL });

    local tactkeys = {};

    local stream = Resources.OpenResource(ResourceType.TactKeys);
    local rows = csv.use(stream, { separator = " ", header = false });

    for row in rows:lines() do
        local lookup = string.lower(row[1]);
        local hexkey = string.lower(row[2]);

        tactkeys[lookup] = hexkey;
    end

    Resources.CloseResource(stream);

    return tactkeys;
end

-- Module exports.
return Resources;
