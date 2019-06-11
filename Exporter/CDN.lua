#!/usr/bin/env lua
local socket = require("socket");

-- Local declarations.
local IterMIMELines;
local IterMIMEHeaders;
local ReadMIMELine;
local ReadMIMEHeader;
local Version;

--- CDN module.
local CDN = {};

--- Default region used for queries.
CDN.DEFAULT_REGION = "us";

--- Remote port used for contacting the CDN.
CDN.REMOTE_PORT = 1119;

--- Returns true if the given region code is valid.
function CDN.IsValidRegion(region)
    region = CDN.GetNormalizedRegionName(region);

    return region == "us" or region == "eu" or region == "tw"
        or region == "cn" or region == "kr";
end

--- Returns a normalized equivalent for the given region code. This does
--  not validate the region.
function CDN.GetNormalizedRegionName(region)
    return string.lower(region);
end

--- Returns a hostname for issuing requests to the CDN.
function CDN.GetHostnameForRegion(region)
    region = CDN.GetNormalizedRegionName(region);
    return string.format("%s.version.battle.net", region);
end

--- Returns a table describing the version data for a given product,
--  optionally scoped to the given region.
function CDN.GetProductVersion(product, region)
    region = CDN.GetNormalizedRegionName(region or CDN.DEFAULT_REGION);
    local hostname = CDN.GetHostnameForRegion(region);

    -- Connect out and issue the command against the endpoint.
    local client = assert(socket.connect(hostname, CDN.REMOTE_PORT));
    local command = string.format("v1/products/%s/versions\r\n", product);
    assert(client:send(command));

    -- Wait for a Content-Type header and extract the boundary marker.
    local boundary;
    for key, value in IterMIMEHeaders(client) do
        if key == "Content-Type" then
            boundary = string.match(value, [[boundary=(%b"")]]);
            boundary = string.sub(boundary, 2, -2);
        end
    end

    -- Once we're past the headers (which is why we don't break above),
    -- wait for a line matching the boundary marker.
    local contentDisposition;
    for line in IterMIMELines(client) do
        if line:match("^%-%-(.-)%-?%-?$") == boundary then
            contentDisposition = nil;

            -- Found a boundary; parse headers from this point.
            for key, value in IterMIMEHeaders(client) do
                if key == "Content-Disposition" then
                    contentDisposition = value;
                end
            end

            -- If the content disposition of the boundary we just found
            -- is that of version data, we're now positioned at its body.
            if contentDisposition == "version" then
                break;
            end
        end
    end

    -- If we don't have the right content disposition, something is off.
    if contentDisposition ~= "version" then
        error("failed to find version data in response");
    end

    -- Version data is represented as pipe-separated values on lines,
    -- finishing with a blank line. The first line is a header naming
    -- each column, so we'll check that for specific names.
    local header = ReadMIMELine(client);
    local columns = {};
    local columnCount = 0;

    -- Column names are in the form: <name>!<type>.
    for column in header:gmatch("([^!|]+)!?[^|]*|?") do
        columnCount = columnCount + 1;
        columns[columnCount] = column;
    end

    if not next(columns) then
        error(string.format("expected column data on line %q", header));
    end

    -- Iterate over the lines of the data table.
    for line in IterMIMELines(client) do
        -- Empty line means end of the data.
        if line == "" then
            break;
        end

        -- Lines might be commented, so skip those.
        if not line:find("^#") then
            local columnIndex = 0;
            local rowData = {};
            for value in line:gmatch("([^|]+)|?") do
                columnIndex = columnIndex + 1;
                rowData[columns[columnIndex]] = value;
            end

            -- If this was the target region, we're done.
            if rowData["Region"] == region then
                return setmetatable(rowData, Version);
            end

            -- If the row contained *nothing*, something is up.
            if not next(rowData) then
                error(string.format("expected row data on line %q", line));
            end
        end
    end

    -- If we get here, we couldn't find any version data.
    error(string.format("no version data for region %q", region));
end

--- Internal API
--  The below declarations are for internal use only.

--- Version class.
Version = {};
Version.__index = Version;

--- Returns the client version identifier, eg. "1.13.2".
function Version:GetClientVersion()
    return self["BuildId"];
end

--- Returns the build config hash.
function Version:GetBuildConfig()
    return self["BuildConfig"];
end

--- Returns the region for this version.
function Version:GetRegion()
    return self["Region"];
end

--- Returns an iterator for reading lines from a socket.
function IterMIMELines(sock)
    return ReadMIMELine, sock;
end

--- Returns an iterator for reading header key/value pairs from a socket.
function IterMIMEHeaders(sock)
    return ReadMIMEHeader, sock;
end

--- Reads the next line from the given socket. If an error occurs, it will
--  be raised unless the error indicates the socket has closed.
--
--  If no data is available, nil is returned.
function ReadMIMELine(sock)
    -- Read the next line, ignoring closed errors but raising all others.
    local line, err = sock:receive("*l");
    if err and err ~= "closed" then
        error(err, 2);
    end

    return line;
end

--- Reads the next line from the given socket, and parses it as a header
--  key/value pair.
--
--  If no line is available, or the line is empty, nil is returned.
function ReadMIMEHeader(sock)
    -- Grab the next line; if it's empty then it's the end of the header.
    local line = ReadMIMELine(sock);
    if not line or line == "" then
        return;
    end

    -- Expect "Key: Value" in a similar manner to HTTP headers.
    local key, value = string.match(line, "^([^:]+):%s*(.-)%s*$");
    if key and value then
        return key, value;
    end

    -- Other lines are totally invalid. This should never be reached.
    error(string.format("invalid line in header: %q", line));
end

-- Module exports.
return CDN;
