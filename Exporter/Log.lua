-- This file is licensed under the terms expressed in the LICENSE file.
local Utils = require "Exporter.Utils";

-- Upvalues.
local strformat = string.format;
local tconcat = table.concat;
local tinsert = table.insert;

-- Enumeration of log levels.
local LogLevel = {
    Debug = 1,
    Info = 2,
    Warn = 3,
    Error = 4,
};

-- Mapping of log levels to ANSI color codes.
local LogLevelColors = {
    [LogLevel.Debug] = "32m",
    [LogLevel.Info] = "34m",
    [LogLevel.Warn] = "33m",
    [LogLevel.Error] = "31m",
};

-- Logging module.
local Log = {
    -- Public enumerations.
    Level = LogLevel,

    -- Current minimum logging level for messages.
    level = LogLevel.Info,
    -- Time at which the module was initialized.
    start = os.time(),
};

-- Returns the current minimum logging level for messages.
function Log.GetLogLevel()
    return Log.level;
end

-- Sets the minimum logging level for messages.
function Log.SetLogLevel(level)
    Log.level = tonumber(level) or LogLevel.Info;
end

-- Logs a debug message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Debug(message, data)
    return Log.Write(LogLevel.Debug, message, data);
end

-- Logs an informational message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Info(message, data)
    return Log.Write(LogLevel.Info, message, data);
end

-- Logs a warning message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Warn(message, data)
    return Log.Write(LogLevel.Warn, message, data);
end

-- Logs an error message to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Error(message, data)
    return Log.Write(LogLevel.Error, message, data);
end

-- Logs an error message to the output stream, and then calls error.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Fatal(message, data)
    Log.Error(message, data);
    error(message, 2);
end

-- Logs a message with the specified level to the output stream.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Write(level, message, data)
    -- Filter messages below the requested level.
    if level < Log.GetLogLevel() then
        return;
    end

    -- Get the color for this log message.
    local color = LogLevelColors[level] or "37m";

    -- Collect all the fields in the data table.
    local fields = {};
    if type(data) == "table" then
        for key, value in pairs(data) do
            local keyString = Utils.WrapTextInColorCode(tostring(key), color);
            local valueString = tostring(value);

            tinsert(fields, strformat("%s=%s", keyString, valueString));
        end
    end

    -- Sort the strings due to the use of pairs and it not being determinate.
    table.sort(fields);
    fields = tconcat(fields, " ");

    -- Format the final message content.
    local seconds = os.time() - Log.start;
    seconds = strformat("[%03d]", seconds);
    seconds = Utils.WrapTextInColorCode(seconds, color);

    local output = strformat("%s %-36s %s", seconds, message, fields);
    io.stderr:write(output, "\n");
end

-- Module exports.
return Log;
