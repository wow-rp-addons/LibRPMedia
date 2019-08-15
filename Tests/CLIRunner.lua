-- This file is licensed under the terms expressed in the LICENSE file.

-- Options for execution via the CLI.
local options = {
    -- Project token for the WOW_PROJECT_ID constant. Required.
    project = nil,
};

-- Parse CLI options.
local offset = 1;
while offset < #arg do
    local opt = arg[offset];
    offset = offset + 1;

    if opt == "-p" or opt == "--project" then
        options.project = arg[offset];
        offset = offset + 1;
    else
        error(string.format("Unknown option: %s", tostring(opt)));
    end
end

-- Validate arguments.
if not options.project then
    error("No project token specified (--project). Aborting.");
end

-- Set up the environment with things required by our library/dependencies.
local env = setmetatable({
    -- Project ID constants to pass version checks.
    [options.project] = options.project,
    WOW_PROJECT_ID = options.project,
}, { __index = _G });

function env.CallErrorHandler(...)
    return ...;
end

function env.strmatch(...)
    return string.match(...);
end

function env.Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...);
            for k, v in pairs(mixin) do
                object[k] = v;
            end
        end

        return object;
    end

function env.tostringall(...)
    if select("#", ...) == 0 then
        return;
    end

    return tostring((...)), env.tostringall(select(2, ...));
end

-- Helper function for loading a script.
local function LoadScript(path, ...)
    local chunk = assert(loadfile(path));
    setfenv(chunk, env);
    return chunk(...);
end

-- Once everything is set up, we'll load the scripts in manually.
local addonName, addon = "LibRPMedia-1.0", {};

LoadScript("Libs/LibStub/LibStub.lua", addonName, addon);

LoadScript("LibRPMedia-1.0.lua", addonName, addon);
LoadScript("LibRPMedia-Classic-1.0.lua", addonName, addon);
LoadScript("LibRPMedia-Retail-1.0.lua", addonName, addon);

LoadScript("Tests/Lib.lua", addonName, addon);
LoadScript("Tests/Icons.lua", addonName, addon);
LoadScript("Tests/Music.lua", addonName, addon);

-- And then run the tests.
local LibRPMedia = env.LibStub:GetLibrary(addonName);
local pass = LibRPMedia.Test.RunTests();
if not pass then
    os.exit(1);
end
