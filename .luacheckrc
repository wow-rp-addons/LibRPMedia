self = false;
max_line_length = 118;
max_code_line_length = 118;
max_string_line_length = 118;
max_comment_line_length = 118;

exclude_files = {
    ".release",
    "Exporter",
    "Libs",
};

globals = {
    -- The following globals are only read/written in non-packaged releases.
    "LibRPMedia_BrowserMixin",
    "LibRPMedia_BrowserTabMixin",
    "LibRPMedia_IconBrowserMixin",
    "LibRPMedia_IconContentMixin",
    "LibRPMedia_IconPreviewMixin",
    "LibRPMedia_MusicBrowserMixin",
    "LibRPMedia_MusicColumnDisplayMixin",
    "LibRPMedia_MusicItemRowMixin",
    "LibRPMedia_MusicScrollMixin",
    "LibRPMedia_PaginationBarMixin",
    "LibRPMedia_SearchOptionsDropDownMixin",
    -- "SLASH_LIBRPMEDIA_SLASHCMD1",
    -- "SlashCmdList",
    -- "UIPanelWindows",
};

read_globals = {
    bit = {
        fields = {
            "band",
            "rshift",
        },
    },

    C_Texture = {
        fields = {
            "GetAtlasInfo",
        },
    },

    table = {
       fields = {
           "wipe",
       },
    },

    "CallErrorHandler",
    "GetAtlasInfo",
    "GetFileIDFromPath",
    "LibStub",
    "Mixin",
    "nop",
    "PlayMusic",
    "PlaySoundFile",
    "strcmputf8i",
    "tInvert",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_TBCC",
};

std = "lua51"
