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
    "bit.bor",
    "bit.lshift",
    "bit.rshift",
    "C_Texture.GetAtlasExists",
    "GetFileIDFromPath",
    "LibStub.GetLibrary",
    "LibStub.NewLibrary",
    "PlayMusic",
    "PlaySound",
    "PlaySoundFile",
    "SOUNDKIT",
    "table.create",
    "table.wipe",
    "UIParent",
};
