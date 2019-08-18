-- This file is licensed under the terms expressed in the LICENSE file.
local LibRPMedia = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true);
if not LibRPMedia then
    return;
end

-- Upvalues.
local debugprofilestop = debugprofilestop;
local strfind = string.find;
local strformat = string.format;
local strgsub = string.gsub;
local strjoin = string.join;
local strmatch = string.match;
local tconcat = table.concat;
local WrapTextInColorCode = WrapTextInColorCode;

-- Local declarations.
local COLOR_BLUE;
local COLOR_GRAY;
local COLOR_GREEN;
local COLOR_RED;
local COLOR_YELLOW;
local GetStackFrameSource;
local HandleTestError;
local IsInGame;
local LOG_DURATION;
local LOG_INDENT;
local LOG_PREFIX_FAIL;
local LOG_PREFIX_PASS;
local LOG_PREFIX_SKIP;
local LOG_PREFIX_TEST;

-- Test module.
local Test = {
    -- Registry of known test functions.
    tests = {},
};

--- Registers a test for execution.
function Test.RegisterTest(name, func)
    table.insert(Test.tests, { Name = name, Func = func });
end

--- Wrapper around assert that, well, asserts.
function Test.Assert(value, msg)
    if value then
        return value;
    end

    error(msg or "Assertion failed!", 2);
end

--- Wrapper around assert that formats its error message on failure.
function Test.Assertf(value, fmt, ...)
    if value then
        return value;
    end

    error(strformat(fmt, ...), 2);
end

--- Assertion that triggers if the given function errors when called.
--
--  If the function is a table, the second argument is used as the key to
--  look up a function within the table, which will be called as a method.
function Test.AssertError(fn, ...)
    -- If fn is a table, assume the first parameter is a name to look up
    -- to obtain a function to be called as a method.
    local arg1 = (...);
    if type(fn) == "table" then
        fn, arg1 = fn[(...)], fn;
    end

    -- Validate the function - do this before the call so we can better
    -- report an invalid use of the assertion function.
    if type(fn) ~= "function" then
        error(strformat("Expected function, got: %s", type(fn)), 2);
    end

    -- Execute the function, if it fails then return the error.
    local result = { pcall(fn, arg1, select(2, ...)) };
    if not result[1] then
        return unpack(result, 2);
    end

    -- Otherwise, assertion gone bad.
    local returns = strjoin(", ", tostringall(unpack(result, 2)));
    error(strformat("Expected error, got: %s", returns), 2);
end


--- Assertion that triggers if the given function does not error when called.
--
--  If the function is a table, the second argument is used as the key to
--  look up a function within the table, which will be called as a method.
function Test.AssertNoError(fn, ...)
    -- If fn is a table, assume the first parameter is a name to look up
    -- to obtain a function to be called as a method.
    local arg1 = (...);
    if type(fn) == "table" then
        fn, arg1 = fn[(...)], fn;
    end

    -- Validate the function - do this before the call so we can better
    -- report an invalid use of the assertion function.
    if type(fn) ~= "function" then
        error(strformat("Expected function, got: %s", type(fn)), 2);
    end

    -- Execute the function, if it succeeds then return the values.
    local result = { pcall(fn, arg1, select(2, ...)) };
    if result[1] then
        return unpack(result, 2);
    end

    -- Otherwise, assertion gone bad.
    error(strformat("Expected no error, got: %s", tostring(result[2])), 2);
end

--- Assertion that raises an error if a given values type does not match
--  the expected type name.
function Test.AssertType(value, want, err)
    if type(value) == want then
        return value;
    end

    if not err then
        err = strformat("Expected type %s, got %s", want, type(value));
    end

    error(err, 2);
end

--- Logs a message for the current test.
function Test.Log(...)
    local source = WrapTextInColorCode(GetStackFrameSource(2), COLOR_BLUE);
    print(strjoin("", LOG_INDENT, source, " ", strjoin(" ", ...)));
end

--- Logs a formatted message for the current test.
function Test.Logf(fmt, ...)
    local source = WrapTextInColorCode(GetStackFrameSource(2), COLOR_BLUE);
    print(strjoin("", LOG_INDENT, source, " ", strformat(fmt, ...)));
end

--- Runs a named test function, capturing its errors and returning a true
--  or false value if it passes or fails.
function Test.RunTest(name, func)
    print(strjoin(" ", LOG_PREFIX_TEST, name));

    -- Capture execution and forward errors appropriately.
    local start = debugprofilestop();
    local ok, err = xpcall(func, HandleTestError);
    local finish = debugprofilestop();

    -- Print some messages indicating the result of the test.
    local duration = strformat(LOG_DURATION, (finish - start) / 1000);
    if not ok then
        if err then
            print(strjoin("", LOG_INDENT, tostring(err)));
        end

        print(strjoin(" ", LOG_PREFIX_FAIL, name, duration));
        return false;
    else
        print(strjoin(" ", LOG_PREFIX_PASS, name, duration));
        return true;
    end
end

--- Runs all registered tests that optionally pass a given name filter.
function Test.RunTests(filter)
    -- Run all the tests in-order.
    local pass, fail, skip = 0, 0, 0;
    for _, test in ipairs(Test.tests) do
        if strfind(test.Name, filter or "", 1, true) then
            local ok = Test.RunTest(test.Name, test.Func);
            if ok then
                pass = pass + 1;
            else
                fail = fail + 1;
            end
        else
            print(strjoin(" ", LOG_PREFIX_SKIP, test.Name));
            skip = skip + 1;
        end
    end

    -- Sum the tests up and generate a summary.
    local total = pass + fail;
    local prefix = LOG_PREFIX_PASS;
    local summary = strformat("%d tests passed", pass);

    -- If the test failed, change the summary format a bit.
    if fail > 0 then
        prefix = LOG_PREFIX_FAIL;
        summary = strformat("%d/%d tests passed", pass, total);
    end

    -- The summary should include skipped tests if any happened.
    if skip > 0 then
        summary = strformat("%s (%d skipped)", summary, skip);
    end

    -- Dump out the final summary and return true if everything passed.
    print(strjoin(" ", prefix, summary));
    return (fail == 0);
end

-- Returns true if the test script is being run in-game.
function IsInGame()
    return not debug and not package and not os;
end

-- API polyfills.
if not IsInGame() then
    function debugprofilestop()
        return os.time() * 1000;
    end

    function strjoin(delim, ...)
        return tconcat({ ... }, delim);
    end

    function WrapTextInColorCode(text, color)
        return strformat("\27[%sm%s\27[0m", color, text);
    end
end

-- Color constants used for output messages.
COLOR_BLUE = IsInGame() and "ff44cefc" or "1;34";
COLOR_GREEN = IsInGame() and "ff44fc81" or "1;32";
COLOR_YELLOW = IsInGame() and "fffce344" or "1;33";
COLOR_RED = IsInGame() and "fffc4447" or "1;31";
COLOR_GRAY = IsInGame() and "ff808080" or "1;30";

-- Log prefixes and format strings for output messages.
LOG_DURATION = WrapTextInColorCode("(%.2fs)", COLOR_GRAY);
LOG_INDENT = IsInGame() and "" or "    ";
LOG_PREFIX_FAIL = WrapTextInColorCode("--- FAIL:", COLOR_RED);
LOG_PREFIX_PASS = WrapTextInColorCode("--- PASS:", COLOR_GREEN);
LOG_PREFIX_SKIP = WrapTextInColorCode("--- SKIP:", COLOR_YELLOW);
LOG_PREFIX_TEST = WrapTextInColorCode("=== TEST:", COLOR_BLUE);

--- Returns a string representing the file/line of the function at a certain
--  level of the stack, relative to the caller.
function GetStackFrameSource(depth)
    local source;
    if IsInGame() then
        local trace = debugstack(depth + 1, 1, 0);
        source = strmatch(trace, "^.+:%d+:") or "<unknown>:0:";
        source = strgsub(source, "^Interface\\AddOns\\", "");
    else
        local info = debug.getinfo(depth + 1, "Sl");
        source = strformat("%s:%d:", info.short_src, info.currentline);
    end

    return source;
end

--- Called when an error occurs in a test. This will forward the error to the
--  global error handler, and format it for our own report. The formatted
--  error is returned.
function HandleTestError(err)
    -- Forward the error to the default error handler for reporting.
    CallErrorHandler(err);

    -- For our own sake, strip part of the path off and color the error.
    return strgsub(err, "^.-:%d+:", function(source)
        source = strgsub(source, "^Interface\\AddOns\\", "");
        return WrapTextInColorCode(source, COLOR_YELLOW);
    end);
end

-- Module exports.
LibRPMedia.Test = Test;
