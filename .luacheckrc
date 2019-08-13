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
    "Exporter/casc",
    "Exporter/Config",
    "Exporter/Data",
    "Exporter/Templates",
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
    globals = {
        "SLASH_LIBRPMEDIA_SLASHCMD1",
        "SlashCmdList",
    },
    read_globals = {
        "CallErrorHandler",
        "debugprofilestop",
        "debugstack",
        "Mixin",
        "tostringall",
        "WrapTextInColorCode",
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
