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
};

-- Base URL for the patch server.
local PATCH_SERVER_URL = "http://%s.patch.battle.net:1119/%s/";
-- Base URL for database requests.
local DATABASE_URL = "https://wow.tools/api/export/?name=%s&build=%s";
-- Base URL for filelist requests.
local FILELIST_URL =
    "https://wow.tools/casc/listfile/download/csv/build?buildConfig=%s";

-- Mapping of CASC content encryption keys.
local ENCRYPTION_KEYS;

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
    -- Cached databases for this prodict.
    databases = {},
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

    Log.Info("Fetching build information...",
        { region = region, product = productName });

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
    Log.Info("Fetching client database...", { name = name });

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
        keys = ENCRYPTION_KEYS,
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
        local build = Resources.GetBuildInfo();
        return strformat(DATABASE_URL, (...), build.version);
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

-- Encryption key table definition;
ENCRYPTION_KEYS = {
    ["fa505078126acb3e"] = "bdc51862abed79b2de48c8e7e66c6200",
    ["ff813f7d062ac0bc"] = "aa0b5c77f088ccc2d39049bd267f066d",
    ["d1e9b5edf9283668"] = "8e4a2579894e38b4ab9058ba5c7328ee",
    ["b76729641141cb34"] = "9849d1aa7b1fd09819c5c66283a326ec",
    ["ffb9469ff16e6bf8"] = "d514bd1909a9e5dc8703f4b8bb1dfd9a",
    ["23c5b5df837a226c"] = "1406e2d873b6fc99217a180881da8d62",
    ["e2854509c471c554"] = "433265f0cdeb2f4e65c0ee7008714d9e",
    ["8ee2cb82178c995a"] = "da6afc989ed6cad279885992c037a8ee",
    ["5813810f4ec9b005"] = "01be8b43142dd99a9e690fad288b6082",
    ["7f9e217166ed43ea"] = "05fc927b9f4f5b05568142912a052b0f",
    ["c4a8d364d23793f7"] = "d1ac20fd14957fabc27196e9f6e7024a",
    ["40a234aebcf2c6e5"] = "c6c5f6c7f735d7d94c87267fa4994d45",
    ["9cf7dfcfcbce4ae5"] = "72a97a24a998e3a5500f3871f37628c0",
    ["4e4bdecab8485b4f"] = "3832d7c42aac9268f00be7b6b48ec9af",
    ["94a50ac54eff70e4"] = "c2501a72654b96f86350c5a927962f7a",
    ["ba973b0e01de1c2c"] = "d83bbcb46cc438b17a48e76c4f5654a3",
    ["494a6f8e8e108bef"] = "f0fde1d29b274f6e7dbdb7ff815fe910",
    ["918d6dd0c3849002"] = "857090d926bb28aeda4bf028cacc4ba3",
    ["0b5f6957915addca"] = "4dd0dc82b101c80abac0a4d57e67f859",
    ["794f25c6cd8ab62b"] = "76583bdacd5257a3f73d1598a2ca2d99",
    ["a9633a54c1673d21"] = "1f8d467f5d6d411f8a548b6329a5087e",
    ["5e5d896b3e163dea"] = "8ace8db169e2f98ac36ad52c088e77c1",
    ["0ebe36b5010dfd7f"] = "9a89cc7e3acb29cf14c60bc13b1e4616",
    ["01e828cffa450c0f"] = "972b6e74420ec519e6f9d97d594aa37c",
    ["4a7bd170fe18e6ae"] = "ab55ae1bf0c7c519aff028c15610a45b",
    ["69549cb975e87c4f"] = "7b6fa382e1fad1465c851e3f4734a1b3",
    ["460c92c372b2a166"] = "946d5659f2faf327c0b7ec828b748adb",
    ["8165d801cca11962"] = "cd0c0ffaad9363ec14dd25ecdd2a5b62",
    ["a3f1c999090adac9"] = "b72fef4a01488a88ff02280aa07a92bb",
    ["094e9a0474876b98"] = "e533bb6d65727a5832680d620b0bc10b",
    ["3db25cb86a40335e"] = "02990b12260c1e9fdd73fe47cbab7024",
    ["0dcd81945f4b4686"] = "1b789b87fb3c9238d528997bfab44186",
    ["486a2a3a2803be89"] = "32679ea7b0f99ebf4fa170e847ea439a",
    ["71f69446ad848e06"] = "e79aeb88b1509f628f38208201741c30",
    ["211fcd1265a928e9"] = "a736fbf58d587b3972ce154a86ae4540",
    ["0adc9e327e42e98c"] = "017b3472c1dee304fa0b2ff8e53ff7d6",
    ["bae9f621b60174f1"] = "38c3fb39b4971760b4b982fe9f095014",
    ["34de1eeadc97115e"] = "2e3a53d59a491e5cd173f337f7cd8c61",
    ["e07e107f1390a3df"] = "290d27b0e871f8c5b14a14e514d0f0d9",
    ["32690bf74de12530"] = "a2556210ae5422e6d61edaaf122cb637",
    ["bf3734b1dcb04696"] = "48946123050b00a7efb1c029ee6cc438",
    ["74f4f78002a5a1be"] = "c14eec8d5aeef93fa811d450b4e46e91",
    ["78482170e4cfd4a6"] = "768540c20a5b153583ad7f53130c58fe",
    ["b1eb52a64bfaf7bf"] = "458133aa43949a141632c4f8596de2b0",
    ["fc6f20ee98d208f6"] = "57790e48d35500e70df812594f507be7",
    ["402cfabf2020d9b7"] = "67197bcd9d0ef0c4085378faa69a3264",
    ["6fa0420e902b4fbe"] = "27b750184e5329c4e4455cbd3e1fd5ab",
    ["1076074f2b350a2d"] = "88bf0cd0d5ba159ae7cb916afbe13865",
    ["816f00c1322cdf52"] = "6f832299a7578957ee86b7f9f15b0188",
    ["ddd295c82e60db3c"] = "3429cc5927d1629765974fd9afab7580",
    ["83e96f07f259f799"] = "91f7d0e7a02cde0de0bd367fabcb8a6e",
    ["49fbfe8a717f03d5"] = "c7437770cf153a3135fa6dc5e4c85e65",
    ["c1e5d7408a7d4484"] = "a7d88e52749fa5459d644523f8359651",
    ["e46276eb9e1a9854"] = "ccca36e302f9459b1d60526a31be77c8",
    ["d245b671dd78648c"] = "19dcb4d45a658b54351db7ddc81de79e",
    ["4c596e12d36ddfc3"] = "b8731926389499cbd4adbf5006ca0391",
    ["0c9abd5081c06411"] = "25a77cd800197ee6a32dd63f04e115fa",
    ["3c6243057f3d9b24"] = "58ae3e064210e3edf9c1259cde914c5d",
    ["7827fbe24427e27d"] = "34a432042073cd0b51627068d2e0bd3e",
    ["faf9237e1186cf66"] = "ae787840041e9b4198f479714dad562c",
    ["0b68a7af5f85f7ee"] = "27aa011082f5e8bbbd71d1ba04f6aba4",
    ["76e4f6739a35e8d7"] = "05cf276722e7165c5a4f6595256a0bfb",
    ["66033f28dc01923c"] = "9f9519861490c5a9ffd4d82a6d0067db",
    ["fcf34a9b05ae7e6a"] = "e7c2c8f77e30ac240f39ec23971296e5",
    ["e2f6bd41298a2ab9"] = "c5dc1bb43b8cf3f085d6986826b928ec",
    ["14c4257e557b49a1"] = "064a9709f42d50cb5f8b94bc1acfdd5d",
    ["1254e65319c6eeff"] = "79d2b3d1ccb015474e7158813864b8e6",
    ["c8753773adf1174c"] = "1e0e37d42ee5ce5e8067f0394b0905f2",
    ["08717b15bf3c7955"] = "4b06bf9d17663ceb3312ea3c69fbc5dd",
    ["9fd609902b4b2e07"] = "abe0c5f9c123e6e24e7bea43c2bf00ac",
    ["259ee68cd9e76dba"] = "465d784f1019661ccf417fe466801283",
    ["cf72fd04608d36ed"] = "a0a889976d02fa8d00f7af0017ad721f",
    ["17f07c2e3a45db3d"] = "6d3886bdb91e715ae7182d9f3a08f2c9",
    ["c050fa06bb0538f6"] = "c552f5d0b72231502d2547314e6015f7",
    ["ab5cdd3fc321831f"] = "e1384f5b06ebbcd333695aa6ffc68318",
    ["a7b7d1f12395040e"] = "36ad3b31273f1ebcee8520aaa74b12f2",
};

-- Module exports.
return Resources;
