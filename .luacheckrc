std = "lua51";
self = false;
unused_args = false;
max_line_length = 118;
max_code_line_length = 118;
max_string_line_length = 118;
max_comment_line_length = 118;

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

read_globals = {
    "CallbackRegistryMixin",
    "CallErrorHandler",
    "CallMethodOnNearestAncestor",
    "Clamp",
    "ColumnDisplayMixin",
    "CreateFramePool",
    "CreateFromMixins",
    "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll",
    "FauxScrollFrame_SetOffset",
    "FauxScrollFrame_Update",
    "GameTooltip_AddInstructionLine",
    "GameTooltip_AddNormalLine",
    "GameTooltip_SetTitle",
    "GameTooltip",
    "GetFileIDFromPath",
    "GetMouseFocus",
    "GREEN_FONT_COLOR",
    "HideUIPanel",
    "LibStub.GetLibrary",
    "LibStub.NewLibrary",
    "Mixin",
    "PanelTemplates_ResizeTabsToFit",
    "PanelTemplates_SetNumTabs",
    "PanelTemplates_SetTab",
    "PlayMusic",
    "PlaySound",
    "SecondsToTime",
    "SetPortraitToTexture",
    "ShowUIPanel",
    "SOUNDKIT",
    "StopMusic",
    "string.join",
    "string.split",
    "table.wipe",
    "tostringall",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_Initialize",
    "UIParent",
    "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WrapTextInColorCode",
};

-- The following globals are only written in non-packaged releases.
globals = {
    "LibRPMedia_BrowserFrame",
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
    "SLASH_LIBRPMEDIA_SLASHCMD1",
    "SlashCmdList",
    "UIPanelWindows",
};
