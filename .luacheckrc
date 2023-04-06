std = "lua51";
self = false;
unused_args = false;
max_line_length = 118;
max_code_line_length = 118;
max_string_line_length = 118;
max_comment_line_length = 118;

exclude_files = {
    ".release",
    "LibRPMediaData_*.lua",
    "Libs",
};

read_globals = {
    "bit.band",
    "bit.rshift",
    "C_Texture.GetAtlasInfo",
    "CallbackRegistryMixin",
    "CallMethodOnNearestAncestor",
    "Clamp",
    "ColumnDisplayMixin",
    "CreateFrame",
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
    "GetAtlasInfo",
    "GetFileIDFromPath",
    "GetMouseFocus",
    "GREEN_FONT_COLOR",
    "LibStub.GetLibrary",
    "LibStub.NewLibrary",
    "PanelTemplates_ResizeTabsToFit",
    "PanelTemplates_SetNumTabs",
    "PanelTemplates_SetTab",
    "PlayMusic",
    "PlaySound",
    "PlaySoundFile",
    "SecondsToTime",
    "SetPortraitToTexture",
    "SOUNDKIT",
    "StopMusic",
    "table.wipe",
    "UIDropDownMenu_AddButton",
    "UIDropDownMenu_SetInitializeFunction",
    "UIParent",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
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
};
