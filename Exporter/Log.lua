-- This file is licensed under the terms expressed in the LICENSE file.

-- Upvalues.
local strformat = string.format;
local tconcat = table.concat;
local tinsert = table.insert;

-- Local declarations.
local ColorText;
local WriteLogMessage;

-- Empty table for unspecified fields.
local EMPTY_DATA = {};

-- Mapping of log level strings to ANSI escape sequence color codes.
local LEVEL_COLORS = {
    debug = "32m", -- Green
    info = "34m", -- Blue
    warn = "33m", -- Yellow
    error = "31m", -- Red
    fatal = "1;31m", -- Red (bold)
};

-- Time at which the module was initialized.
local LOG_START_TIME = os.time();

-- Module table.
local Log = {};

-- Logs a debug message to stderr.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Debug(message, data)
    local debug = os.getenv("DEBUG");
    if not debug or debug == "" or debug == "0" then
        return;
    end

    return WriteLogMessage("debug", message, data or EMPTY_DATA);
end

-- Logs an informational message to stderr.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Info(message, data)
    return WriteLogMessage("info", message, data or EMPTY_DATA);
end

-- Logs a warning message to stderr.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Warn(message, data)
    return WriteLogMessage("warn", message, data or EMPTY_DATA);
end

-- Logs an error message to stderr.
--
-- The data parameter may be a table of key/value pairs to include in the
-- message as a form of structured logging.
function Log.Error(message, data)
    return WriteLogMessage("error", message, data or EMPTY_DATA);
end

-- Logs a fatal error message to stderr, calling error afterwards.
function Log.Fatal(message, data)
    WriteLogMessage("fatal", message, data or EMPTY_DATA);
    error(message, 2);
end

-- Internal functions.

-- Wraps a given piece of text in an ANSI color code seequence.
function ColorText(text, color)
    return strformat("\27[%s%s\27[0m", color, text);
end

-- Writes a formatted log message to stderr. The message will be colored
-- based upon the given level and, if a given table of fields is specified,
-- those fields will be appended to the end of the message.
function WriteLogMessage(level, message, data)
    local color = LEVEL_COLORS[level] or "37m";

    -- Collect all the fields in the data table.
    local fieldStrings = {};
    for key, value in pairs(data) do
        local keyString = ColorText(tostring(key), color);
        local valueString = tostring(value);

        local entry = strformat("%s=%s", keyString, valueString);
        tinsert(fieldStrings, entry);
    end

    -- Sort the strings due to the use of pairs and it not being determinate.
    table.sort(fieldStrings);

    -- Format the final message content.
    local seconds = os.time() - LOG_START_TIME;
    local secondsString = ColorText(strformat("[%03d]", seconds), color);
    local fields = tconcat(fieldStrings, " ");

    local output = strformat("%s %-36s %s\n", secondsString, message, fields);
    io.stderr:write(output);
end

-- Module exports.
return Log;
