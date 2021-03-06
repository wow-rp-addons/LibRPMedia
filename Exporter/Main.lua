-- This file is licensed under the terms expressed in the LICENSE file.

-- Fiddle with the package path a bit to allow our working directory to
-- be the root of the repository prior to loading packages.
package.path = package.path .. ";./Exporter/?.lua;./Exporter/?/init.lua";

local Icons = require "Exporter.Icons";
local Log = require "Exporter.Log";
local Music = require "Exporter.Music";
local Resources = require "Exporter.Resources";
local Serializer = require "Exporter.Serializer";
local Utils = require "Exporter.Utils";

local etlua = require "etlua";
local lfs = require "lfs";

-- Upvalues.
local strformat = string.format;
local strmatch = string.match;
local strsub = string.sub;

-- Script usage text.
local USAGE_TEXT = [[
%s [flags]
Exports databases based on information obtained from public dumps.

Flags:
    -c, --config        Path to the configuration file for the exporter.
]];

-- Command line options table.
local options = {
    -- Configuration file path.
    config = nil,
};

-- Read options from the command line.
local argi = 1;
while argi < #arg do
    local argv = arg[argi];
    argi = argi + 1;

    if argv == "-c" or argv == "--config" then
        options.config = tostring(arg[argi]);
        argi = argi + 1;
    else
        print(strformat(USAGE_TEXT, arg[0]));
        print(strformat("Unknown option: %s", argv));
        os.exit(1);
    end
end

-- Validate options.
if not options.config or options.config == "" then
    print(strformat(USAGE_TEXT, arg[0]));
    print("No config file specified (--config)");
    os.exit(1);
end

-- Product configuration table. This represents the default configuration of
-- the exporter and is merged into by the user-specific config.
local config = {
    -- Project token for this game variant.
    project = nil,
    -- Product name for obtaining data from the patch/CDN servers.
    product = nil,
    -- Region to use when connecting to patch/CDN server.
    region = nil,

    -- Name of the database file to generate.
    database = nil,
    -- Name of the manifest file to generate.
    manifest = nil,
    -- Name of the template file to use for the database output.
    template = "Exporter/Templates/Database.lua.tpl",

    -- Override mapping of DB2 names to explicit build versions to download.
    databaseOverrides = {},

    -- Settings for icon database generation.
    icons = {
        -- List of icon name patterns to exclude from the database.
        excludeNames = {},
        -- List of atlas name patterns to include.
        includeAtlases = {},
    },

    -- Settings for music database generation.
    music = {
        -- Mapping of soundkit IDs to be explicitly included or excluded.
        -- The value of each entry should be false to omit the soundkit,
        -- true to include it, or a string to include it with a custom name.
        --
        -- If a kit is included, a name must be obtainable from the client
        -- databases; if not, it will be skipped and a warning logged.
        --
        -- Custom names take priority over those found within the client
        -- databases.
        --
        -- Soundkits present within this mapping will be overridden and
        -- excluded if matching any of the files or names present in the
        -- excludeFiles and excludeNames lists.
        overrideKits = {},

        -- List of file IDs to exclude from the database.
        excludeFiles = {},
        -- List of file/soundkit name patterns to exclude from the database.
        excludeNames = {},
    },

    -- If true, enable debug logging in the exporter.
    verbose = os.getenv("DEBUG") == "1",
    -- Path to a directory for storing cached content.
    cacheDir = Resources.GetCacheDirectory(),
};

-- Extracts the major and minor version components from the library script.
local function GetLibraryVersion()
    local libraryFile = assert(io.open("LibRPMedia-1.0.lua", "rb"));
    local library = assert(libraryFile:read("*a"));
    libraryFile:close();

    local versionMajor = strmatch(library, "MODULE_MAJOR = (%b\"\")");
    if not versionMajor then
        error("Failed to extract major version from library.");
    end

    local versionMinor = strmatch(library, "MODULE_MINOR = (%d+)");
    if not versionMinor then
        error("Failed to extract minor version from library.");
    end

    return strsub(versionMajor, 2, -2), tonumber(versionMinor);
end

-- Run the actual script in protected mode so we can log fatal errors cleanly.
local ok, err = pcall(function()
    -- Read in the user configuration and merge it.
    Log.Info("Loading configuration file...", options.config);
    config = Utils.Merge(config, Serializer.LoadFile(options.config));

    -- Configure modules.
    Log.Info("Configuring exporter...");
    Log.SetLogLevel(config.verbose and Log.Level.Debug or Log.Level.Info);

    Resources.SetCacheDirectory(config.cacheDir);
    Resources.SetDatabaseVersionOverrides(config.databaseOverrides);
    Resources.SetProductName(config.product);
    Resources.SetRegion(config.region);

    Icons.SetExcludedNames(config.icons.excludeNames);
    Icons.SetIncludedAtlases(config.icons.includeAtlases);

    Music.SetOverrideKits(config.music.overrideKits);
    Music.SetExcludedFiles(config.music.excludeFiles);
    Music.SetExcludedNames(config.music.excludeNames);

    -- Load the manifest if one exists.
    local manifest;
    if lfs.attributes(config.manifest, "mode") == "file" then
        Log.Info("Loading manifest...", { path = config.manifest });
        local ok, result = pcall(Serializer.LoadFile, config.manifest);
        if not ok then
            Log.Warn("Failed to load manifest.", { err = result });
        else
            manifest = result;
        end
    end

    -- Create a manifest if one wasn't loaded.
    if not manifest then
        Log.Info("Creating new manifest...");
        manifest = {};
    end

    -- Persist build information in the manifest.
    local build = Resources.GetBuildInfo();
    manifest.build = { bkey = build.bkey, version = build.version };
    Log.Info("Obtained build information.", manifest.build);

    -- Update the manifest for each database type.
    manifest.music = Music.GetManifest(manifest.music or {});
    manifest.icons = Icons.GetManifest(manifest.icons or {});

    -- Write the manifest out.
    Log.Info("Writing manifest file...", { path = config.manifest });
    Serializer.SaveFile(config.manifest, manifest, Serializer.OptionsPretty);

    -- Generate the actual database contents.
    local database = {};
    database.music = Music.GetDatabase(manifest.music);
    database.icons = Icons.GetDatabase(manifest.icons);

    -- Read in the main script to obtain the library version.
    Log.Info("Fetching library version...");
    local versionMajor, versionMinor = GetLibraryVersion();

    -- Read in the template file and render the database.
    Log.Info("Loading template file...", { path = config.template });
    local templateFile = assert(io.open(config.template, "rb"));
    local template = assert(templateFile:read("*a"));
    templateFile:close();

    Log.Info("Rendering template contents...");
    local content = assert(etlua.render(template, {
        -- Data.
        build = build,
        config = config,
        database = database,
        manifest = manifest,

        -- Versioning.
        versionMajor = versionMajor,
        versionMinor = versionMinor,

        -- Functions.
        Dump = Serializer.Dump,
    }));

    -- Write the rendered template out.
    Log.Info("Writing database contents...", { path = config.database });
    local databaseFile = assert(io.open(config.database, "wb"));
    assert(databaseFile:write(content));
    databaseFile:close();
end);

if not ok then
    Log.Fatal("Fatal error during export.", { err = err });
end
