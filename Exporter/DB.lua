#!/usr/bin/env lua
local pl = {
    data = require("pl.data"),
    dir = require("pl.dir"),
    path = require("pl.path"),
};

-- Local declarations.
local DB2DataSource;
local FileListDataSource;
local IssueHTTPRequest;
local OpenOrFetchDatabase;
local OpenOrFetchFile;
local OpenOrFetchFileList;
local ParseCSVLine;

--- Local directory where we'll cache retrieved files. This is so the brains
--  behind the remote source don't complain about bandwidth.
local CACHE_DIR = ".cache";

--- Remote API URL that we'll grab exports from.
local REMOTE_SOURCE_URL = "https://wow.tools";

--- URL from which we can get CSV exports of databases.
local DATABASE_URL_PATH = "/api/export/?name=%s&build=%s";
local DATABASE_URL_FORMAT = REMOTE_SOURCE_URL .. DATABASE_URL_PATH;

--- URL from which we can get a filelist for a specific build.
local FILELIST_URL_PATH = "/casc/listfile/download/csv/build?buildConfig=%s";
local FILELIST_URL_FORMAT = REMOTE_SOURCE_URL .. FILELIST_URL_PATH;

--- DB module.
local DB = {};

--- Returns a file list data source for the given build, downloading it
--  from a remote source if needed.
--
--  If a build cannot be obtained, an error is raised. Hopefully.
function DB.OpenFileList(version)
    local stream = OpenOrFetchFileList(version);
    return setmetatable({ stream = stream }, FileListDataSource);
end

function DB.OpenDatabase(database, version)
    local stream = OpenOrFetchDatabase(database, version);
    return setmetatable({ stream = stream, transforms = {} }, DB2DataSource);
end

--- Data source class representing a client database (DBC/DB2).
DB2DataSource = {};
DB2DataSource.__index = DB2DataSource;

--- Closes the source and the underlying data stream, as well as resetting
--  current row information.
--
--  This function is idempotent and may be called multiple times.
function DB2DataSource:Close()
    local stream = self.stream;

    self.stream = nil;

    if stream then
        stream:close();
    end
end

--- Returns true if the data source is closed.
function DB2DataSource:IsClosed()
    return self.stream == nil;
end

--- Returns an iterator that yields each row from the data source.
function DB2DataSource:IterRows()
    return function()
        if not self:Next() then
            return;
        end

        return self:GetCurrentRow();
    end
end

--- Advances the data source to the next row, returning true if a row is
--  available.
function DB2DataSource:Next()
    -- Read the columns if they're still missing.
    local columns = self:GetOrReadColumns();

    local line = self.stream:read("*l");
    if not line or line == "" then
        self:Close();
        return false;
    end

    local row = {};
    for i, value in ipairs(ParseCSVLine(line)) do
        -- Apply any type transforms to obtained values if we have some.
        local column = columns[i];
        if self.transforms and self.transforms[column] then
            value = self.transforms[column](value);
        end

        row[column] = value;
    end

    self.row = row;
    return true;
end

--- Returns a table listing the columns in order present within the data.
--
--  This will return nil if the column data has not yet been read.
function DB2DataSource:GetColumns()
    return self.columns;
end

--- Returns a table listing the columns in order present within the data.
--
--  This will read from the stream if the column data has not yet been read.
function DB2DataSource:GetOrReadColumns()
    if self.columns then
        return self.columns;
    elseif self:IsClosed() then
        return;
    end

    self.columns = {};

    local line = self.stream:read("*l");
    if not line or line == "" then
        self:Close();
        return;
    end

    for _, column in ipairs(ParseCSVLine(line)) do
        if column ~= "" then
            self.columns[#self.columns + 1] = column;
        end
    end

    return self.columns;
end

--- Returns a table of information representing data in the current row.
function DB2DataSource:GetCurrentRow()
    return self.row;
end

--- Sets the transformation function for a named function. Each row read
--  will call the given function for the value contained within the named
--  column.
function DB2DataSource:SetColumnTransform(column, transformFunction)
    self.transforms[column] = transformFunction;
end

--- Data source class representing a file list.
FileListDataSource = {};
FileListDataSource.__index = FileListDataSource;

--- Closes the source and the underlying data stream, as well as resetting
--  current row information.
--
--  This function is idempotent and may be called multiple times.
function FileListDataSource:Close()
    local stream = self.stream;

    self.currentFileID = nil;
    self.currentFilePath = nil;
    self.stream = nil;

    if stream then
        stream:close();
    end
end

--- Returns true if the data source is closed.
function FileListDataSource:IsClosed()
    return self.stream == nil;
end

--- Returns an iterator that yields each row from the data source.
function FileListDataSource:IterRows()
    return function()
        if not self:Next() then
            return;
        end

        return self:GetCurrentRow();
    end
end

--- Advances the data source to the next row, returning true if a row is
--  available.
function FileListDataSource:Next()
    local line = self.stream:read("*l");
    if not line or line == "" then
        self:Close();
        return false;
    end

    local fileID, filePath = string.match(line, "^(%d+);([^;]*)");
    self.currentFileID = tonumber(fileID);
    self.currentFilePath = filePath ~= "" and filePath or nil;
    return true;
end

--- Returns the file information present within the current row.
function FileListDataSource:GetCurrentRow()
    return self.currentFileID, self.currentFilePath;
end

--- Internal API
--  The below declarations are for internal use only.

--- Issues a HTTP GET request against the given URL, returning a file
--  descriptor that can be read to obtain the response body.
function IssueHTTPRequest(url)
    -- Rather than bother with luarocks on Windows and its myriad of libraries
    -- that don't bloody work, we're just gonna assume that every system has
    -- curl installed.
    local command = string.format("curl -s %q", url);
    return assert(io.popen(command, "r"));
end

--- Opens or retrieves the named database for the given client version.
--  This will issue a HTTP request if the database is not stored locally.
function OpenOrFetchDatabase(database, version)
    local clientVersion = version:GetClientVersion();
    local fileName = string.format("%s_%s.csv", clientVersion, database);
    local filePath = pl.path.join(CACHE_DIR, fileName);
    local url = string.format(DATABASE_URL_FORMAT, database, clientVersion);

    return OpenOrFetchFile(filePath, url);
end

--- Opens a named file at the given path, or downloads it from the given
--  URL.
--
--  If the file is not present locally, the data will be downloaded to the
--  local disk from the given URL into a file at the named path, and the
--  local file then returned post-write.
function OpenOrFetchFile(filePath, url)
    -- Try to open the cached data first, if it exists.
    local stream = io.open(filePath, "r");
    if stream then
        return stream;
    end

    -- Fetch the data from the source URL and cache it locally.
    local request = IssueHTTPRequest(url);

    pl.dir.makepath(pl.path.dirname(filePath));
    stream = assert(io.open(filePath, "w"));

    for chunk in function() return request:read(128) end do
        assert(stream:write(chunk));
    end

    stream:close();
    request:close();

    -- Re-open the cached stream.
    return assert(io.open(filePath, "r"));
end

--- Opens or retrieves the filelist for the given build hash.
--  This will issue a HTTP request if the filelist is not stored locally.
function OpenOrFetchFileList(version)
    local buildConfig = version:GetBuildConfig();
    local fileName = string.format("%s_filelist.csv", buildConfig);
    local filePath = pl.path.join(CACHE_DIR, fileName);
    local url = string.format(FILELIST_URL_FORMAT, buildConfig);

    return OpenOrFetchFile(filePath, url);
end

--- Parses a line from a CSV file, returning a table of all comma-separated
--  values.
--
--  Based off the implementation in the wiki:
--  http://lua-users.org/wiki/LuaCsv
function ParseCSVLine(line)
    local res = {};
    local pos = 1;

    while true do
        local c = string.sub(line, pos, pos);
        if c == "" then
            break;
        end

        if c == '"' then
            -- Quoted value (ignore separator within).
            local txt = "";
            repeat
                local startp, endp = string.find(line, '^%b""', pos);
                txt = txt .. string.sub(line, startp + 1, endp - 1);
                pos = endp + 1;
                c = string.sub(line, pos, pos);

                if c == '"' then
                    txt = txt .. '"';
                end
            until c ~= '"'

            table.insert(res, txt);
            assert(c == "," or c == "");
            pos = pos + 1;
        else
            -- No quotes used, just look for the first separator.
            local startp, endp = string.find(line, ",", pos)
            if startp then
                table.insert(res, string.sub(line, pos, startp - 1));
                pos = endp + 1;
            else
                -- No separator found -> use rest of string and terminate.
                table.insert(res,string.sub(line,pos));
                break;
            end
        end
    end

    return res;
end

-- Module exports.
return DB;
