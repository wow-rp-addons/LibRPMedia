#!/usr/bin/env lua

-- Local declarations.
local GetTemplateEnvironment;

--- Template module.
local Template = {};

--- Renders a given source template string with the supplied data, writing
--  the result to the given stream.
function Template.Render(stream, source, data)
    local environment = GetTemplateEnvironment(stream, data);

    -- Perform replacements and render the document progressively.
    for line in source:lines() do
        -- We only allow single-line expression replacements for now.
        local first, code, last = string.match(line, "^()%-%-@(.+)()$");
        if not code or code == "" then
            first, code, last = string.match(line, "()%-%-%[%[@(.-)@%]%]()");
        end

        stream:write(string.sub(line, 1, (first or 1) - 1));

        if code and code ~= "" then
            -- Run the code inside the environment.
            local chunk = assert(loadstring(code));
            setfenv(chunk, environment);
            assert(pcall(chunk));
        end

        -- The line ending below gets normalized to your platform.
        stream:write(string.sub(line, last or 0), "\n");
    end
end

--- Internal API
--  The below declarations are for internal use only.

function GetTemplateEnvironment(stream, data)
    local environment = {};

    -- Properly formats any given value and writes it out.
    environment.WriteValue = function(value)
        if type(value) == "nil" then
            stream:write("nil");
        elseif type(value) == "number" then
            stream:write(tostring(value));
        elseif type(value) == "string" then
            stream:write(string.format("%q", value));
        elseif type(value) == "table" then
            stream:write("{");

            for i = 1, #value do
                environment.WriteValue(value[i]);

                if i < #value then
                    stream:write(",");
                end
            end

            for key, subvalue in pairs(value) do
                if type(key) ~= "number" or key <= 0 or key > #value then
                    stream:write("[");
                    environment.WriteValue(key);
                    stream:write("]=");
                    environment.WriteValue(subvalue);

                    if next(value, key) then
                        stream:write(",");
                    end
                end
            end

            stream:write("}");
        else
            error(string.format("unsupported value type: %s", type(value)));
        end
    end

    -- Writes a version check to reject untargetted interface versions.
    environment.WriteVersionConstraint = function(var)
        stream:write(tostring(var), " < ", data.interfaceVersion);
        if not data.maxInterfaceVersion then
            return;
        end

        stream:write(" or ", tostring(var), " >= ", data.maxInterfaceVersion);
    end

    return setmetatable(environment, { __index = data });
end

-- Module exports.
return Template;
