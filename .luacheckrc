-- Disable unused self warnings.
self = false;

-- Allow unused arguments.
unused_args = false;

-- Limit line length to 78 characters.
max_line_length = 78;
max_code_line_length = 78;
max_string_line_length = 78;
max_comment_line_length = 78;

-- Add exceptions for external libraries.
std = "lua51+libstub+wow"

stds.libstub = {
    read_globals = {
        "LibStub",
    },
};

stds.wow = {
    read_globals = {
        "CallErrorHandler",
    },
};
