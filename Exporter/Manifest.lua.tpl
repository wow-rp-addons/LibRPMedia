return {
    build = {
        bkey = [[@ string.format("%q", build.bkey) @]],
        version = [[@ string.format("%q", build.version) @]],
    },
    icons = {
--@ for _, info in ipairs(icons) do
        {
            file = [[@ info.file @]],
            hash = [[@ string.format("%q", info.hash) @]],
            name = [[@ string.format("%q", info.name) @]],
            size = { h = [[@ info.size.w @]], w = [[@ info.size.h @]] },
            type = [[@ info.type @]],
        },
--@ end
    },
    music = {
--@ for _, info in ipairs(music) do
        {
            file = [[@ info.file @]],
            hash = [[@ string.format("%q", info.hash) @]],
--@ if #info.name > 0 then
            name = {
--@ for _, name in ipairs(info.name) do
                [[@ string.format("%q", name) @]],
--@ end
            },
--@ else
            name = {},
--@ end
            path = [[@ info.path and string.format("%q", info.path) or "nil" @]],
            time = [[@ info.time @]],
        },
--@ end
    },
};
