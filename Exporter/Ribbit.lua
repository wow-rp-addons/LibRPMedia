-- This file is licensed under the terms expressed in the LICENSE file.
local httpheaders = require "http.headers";
local socket = require "socket";
local ftcsv = require "ftcsv";

-- Upvalues.
local strformat = string.format;
local strgmatch = string.gmatch;
local strgsub = string.gsub;
local strlower = string.lower;
local strmatch = string.match;
local tconcat = table.concat;
local tinsert = table.insert;
local unpack = table.unpack or unpack; -- Lua 5.1+ compat.

-- Local declarations.
local CreateLineIterator;
local FindResponsePart;
local FixupCSVHeader;
local GetOptionValue;
local ReadMultipartBody;
local ReadResponseHeaders;
local ReadResponseParts;
local SendRequest;
local StripCSVComments;
local SplitStringByPattern;

-- MIME type for a multipart content response.
local MIME_TYPE_MULTIPART = "multipart/alternative";
-- Pattern for reading MIME headers as key, value pairs.
local PATTERN_MIME_HEADER = "^([^:]+): (.+)$";
-- Pattern for reading the Content-Type header.
local PATTERN_CONTENT_TYPE = "^([^;]-);.*boundary=\"([^\"]+)\"";

-- Module table.
local Ribbit = {};

-- Default options used by requests through this module. The default values
-- here define what'll be used in the event that an "options" table is not
-- passed (or has incomplete data) to the public API functions.
Ribbit.DefaultOptions = {
    region = "us",
    host = "version.battle.net",
    port = 1119,
};

-- Returns a table defining the CDNs available for a specified product name.
function Ribbit.GetProductCDNs(productName, options)
    -- Issue the request.
    local endpoint = strformat("v1/products/%s/cdns", productName);
    local response = SendRequest(endpoint, options);

    -- Parse the response as a CSV document.
    local part = FindResponsePart(response, "cdn");
    local rows = ftcsv.parse(StripCSVComments(part.body), "|", {
        loadFromString = true,
        headers = true,
        headerFunc = FixupCSVHeader,
    });

    -- Find the matching row for the specified region.
    local region = GetOptionValue(options, "region");
    for _, row in ipairs(rows) do
        if row["name"] == region then
            -- Do a few transforms before finishing up. The hosts and
            -- servers are space-separated strings, so make them tables.
            row["hosts"] = { SplitStringByPattern(row["hosts"], "%S+") };
            row["servers"] = { SplitStringByPattern(row["servers"], "%S+") };
            return row;
        end
    end
end

-- Returns a table defining the latest versions available for a specified
-- product name.
function Ribbit.GetProductVersion(productName, options)
    -- Issue the request.
    local endpoint = strformat("v1/products/%s/versions", productName);
    local response = SendRequest(endpoint, options);

    -- Parse the response as a CSV document.
    local part = FindResponsePart(response, "version");
    local rows = ftcsv.parse(StripCSVComments(part.body), "|", {
        loadFromString = true,
        headers = true,
        headerFunc = FixupCSVHeader,
    });

    -- Find the matching row for the specified region.
    local region = GetOptionValue(options, "region");
    for _, row in ipairs(rows) do
        if row["region"] == region then
            return row;
        end
    end
end

-- Returns the hostname for the API that will be queried when the given
-- option set is passed.
function Ribbit.GetRegionHostname(options)
    local region = GetOptionValue(options, "region");
    local host = GetOptionValue(options, "host");

    return strformat("%s.%s", tostring(region), tostring(host));
end

-- Internal functions.

-- Returns a named option value from the given options table, or a suitable
-- default if no value can be obtained.
function GetOptionValue(options, key)
    if type(options) ~= "table" then
        return Ribbit.DefaultOptions[key];
    end

    local value = options[key];
    if value == nil then
        return Ribbit.DefaultOptions[key];
    end

    return value;
end

-- Returns a stateful iterator that yields lines separated by \r\n characters
-- from the given string.
function CreateLineIterator(text)
    return strgmatch(text, "(.-)\r\n");
end

-- Returns a http.headers object filled with headers parsed from the given
-- line iterator.
--
-- When this function returns, the line iterator will be advanced to the
-- body section of a response.
function ReadResponseHeaders(lines)
    local headers = httpheaders.new();
    for line in lines do
        -- Empty lines are the divider between header and body content.
        if line == "" then
            break;
        end

        local key, value = strmatch(line, PATTERN_MIME_HEADER);
        if not key then
            error(strformat("invalid key in header line: %q", line), 2);
        end

        headers:append(strlower(key), value);
    end

    return headers;
end

-- Reads a multipart response body from the given line iterator, terminating
-- when the specified boundary is found.
--
-- If the final boundary is an end-of-document marker (trailing "--"), then
-- an additional boolean will be returned as true noting this.
function ReadMultipartBody(lines, boundary)
    local body = {};

    local boundaryBreakLine = "--" .. boundary;
    local boundaryFinalLine = boundaryBreakLine .. "--";
    local isFinalPart = false;

    for line in lines do
        if line == boundaryBreakLine or line == boundaryFinalLine then
            isFinalPart = (line == boundaryFinalLine);
            break;
        end

        tinsert(body, line);
    end

    return tconcat(body, "\r\n"), isFinalPart;
end

-- Returns a stateful iterator that yields multipart response parts from the
-- given response string as tables.
--
-- When the final part is yielded, the iterator will return nil.
function ReadResponseParts(response)
    -- Read the initial header from the response to determine the boundary.
    local lines = CreateLineIterator(response);
    local headers = ReadResponseHeaders(lines);

    local contentType = headers:get("content-type");
    local ctype, boundary = strmatch(contentType, PATTERN_CONTENT_TYPE);
    if ctype ~= MIME_TYPE_MULTIPART then
        error(strformat("invalid content type in response: %q", ctype), 2);
    elseif not boundary then
        error(strformat("no multipart boundary found: %q", contentType), 2);
    end

    -- Discard the initial body up to the first boundary. Note that atEnd
    -- here should always be false unless we got a weird response where the
    -- first boundary marker was a finish marker.
    local _, atEnd = ReadMultipartBody(lines, boundary);

    -- Now return an iterator for accessing the individual parts.
    return function()
        -- Don't do anything if we're at the end.
        if atEnd then
            return;
        end

        local partHeaders = ReadResponseHeaders(lines);
        local partBody, isFinalPart = ReadMultipartBody(lines, boundary);

        atEnd = isFinalPart;

        return {
            headers = partHeaders,
            final = isFinalPart,
            body = partBody,
        };
    end
end

-- Reads a response and scans the parts for a specific one that contains
-- a Content-Disposition header matching the given value.
--
-- Returns the part if found, else returns nil.
function FindResponsePart(response, disposition)
    for part in ReadResponseParts(response) do
        if part.headers:get("content-disposition") == disposition then
            return part;
        end
    end
end

-- Issues a request for the specified endpoint, delivering it to the server
-- specified in the given options table.
--
-- Returns the response as a full text string on success, or raises an error
-- if the request can't be sent, or the response can't be read.
function SendRequest(endpoint, options)
    local host = Ribbit.GetRegionHostname(options);
    local port = GetOptionValue(options, "port");

    local client = socket.try(socket.connect(host, port));
    local written, werr = client:send(endpoint .. "\r\n");

    if not written then
        client:close();
        error(werr);
    end

    local data, rerr = client:receive("*a");
    if not data then
        client:close();
        error(rerr);
    end

    client:close();
    return data;
end

-- Fixes up a CSV header in a response, stripping type information and
-- lowercasing the string,
function FixupCSVHeader(header)
    return strlower(strmatch(header, "^([^!]+)"));
end

-- Removes all CSV comments from the given text block.
function StripCSVComments(text)
    return strgsub(text, "\n?##.-\n?", "");
end

-- Splits a string by a given pattern, returning the parts as a variadic list.
function SplitStringByPattern(s, pattern)
    local parts = {};
    for part in strgmatch(s, pattern) do
        tinsert(parts, part);
    end

    return unpack(parts);
end

-- Module exports.
return Ribbit;
