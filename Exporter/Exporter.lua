#!/usr/bin/env lua
local CDN = require("Exporter.CDN");
local Music = require("Exporter.Music");
local Template = require("Exporter.Template");

-- Local declarations.
local print;
local printf;
local tostringall;

local USAGE_TEXT = string.format([[
Usage: %s [options]

Compiles data for LibRPMediaDB based on externally sourced databases.

Options:
    -d, --database              Database to export.
    -i, --interface-version     Interface (TOC) version for the build.
    -m, --max-interface-version Maximum supported interface (TOC) version.
    -p, --product-id            Product ID that we're building data for.
    -r, --region                Region to query patch information from.
    -t, --template              Template file to render.
]], arg[0]);

--- Utility functions

--- Prints a message.
function print(...)
    io.stderr:write(table.concat({ tostringall(...) }, "\t"), "\n");
end

--- Formats the given string and prints it.
function printf(format, ...)
    print(string.format(format, ...));
end

--- Converts all given values to strings, and returns them.
function tostringall(v, ...)
    if select("#", ...) == 0 then
        return tostring(v);
    end

    return tostring(v), tostringall(...);
end

--- Exporter Script

-- Default options.
local database = nil;
local interfaceVersion = nil;
local maxInterfaceVersion = nil;
local productID = nil;
local region = CDN.DEFAULT_REGION;
local template = nil;

-- Parse the command line options.
do
    local argi = 1
    local argv = arg;

    while argi < #arg do
        local arg = argv[argi];
        argi = argi + 1;

        if arg == "-d" or arg == "--database" then
            database = string.lower(argv[argi]);
            argi = argi + 1;
        elseif arg == "-i" or arg == "--interface-version" then
            interfaceVersion = tonumber(argv[argi]);
            argi = argi + 1;
        elseif arg == "-m" or arg == "--max-interface-version" then
            maxInterfaceVersion = tonumber(argv[argi]);
            argi = argi + 1;
        elseif arg == "-p" or arg == "--product-id" then
            productID = argv[argi];
            argi = argi + 1;
        elseif arg == "-r" or arg == "--region" then
            region = argv[argi];
            argi = argi + 1;
        elseif arg == "-t" or arg == "--template" then
            template = argv[argi];
            argi = argi + 1;
        else
            print(USAGE_TEXT);
            printf("Invalid argument: %s", arg);
            return os.exit(1);
        end
    end
end

-- Validate the options.
if not database then
    print(USAGE_TEXT);
    print("No database specified.");
    return os.exit(1);
end

if not interfaceVersion then
    print(USAGE_TEXT);
    print("No interface version specified.");
    return os.exit(1);
end

if not productID then
    print(USAGE_TEXT);
    print("No product ID specified.");
    return os.exit(1);
end

if not region then
    print(USAGE_TEXT);
    print("No CDN region specified.");
    return os.exit(1);
elseif not CDN.IsValidRegion(region) then
    print(USAGE_TEXT);
    printf("CDN region is not valid: %s", region);
    return os.exit(1);
end

if not template then
    print(USAGE_TEXT);
    print("No template file specified.");
    return os.exit(1);
end

-- Once the options are sorted, query the CDN for product versioning.
local version = CDN.GetProductVersion(productID, region);

-- Export the requested database.
local databaseContent;
if database == "music" then
    databaseContent = Music.GetDatabase(version);
else
    print(USAGE_TEXT);
    printf("Selected database is not valid: %s", database);
    return os.exit(1);
end

-- And then finally render the template.
local templateFile = assert(io.open(template, "r"));
Template.Render(io.stdout, templateFile, {
    [database] = databaseContent,

    -- Include some of the CLI parameters too.
    interfaceVersion = interfaceVersion,
    maxInterfaceVersion = maxInterfaceVersion,
    productID = productID,
    region = region,
});

templateFile:close();
