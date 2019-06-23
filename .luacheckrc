-- Disable unused self warnings.
self = false;

-- Allow unused arguments.
unused_args = false;

-- Limit line length to 78 characters.
max_line_length = 78;
max_code_line_length = 78;
max_string_line_length = 78;
max_comment_line_length = 78;

-- Ignore generated files.
exclude_files = {
    ".release",
    "Config",
    "LibRPMedia-*-1.0.lua",
    "Libs",
};

-- Add exceptions for external libraries.
std = "lua51+libstub+wow+wowstd"

stds.libstub = {
    read_globals = {
        "LibStub",
    },
};

stds.wow = {
    read_globals = {
        "CallErrorHandler",
        "nop",
    },
};

stds.wowstd = {
    read_globals = {
        string = {
            fields = {
                "join",
            },
        },
    },
};
