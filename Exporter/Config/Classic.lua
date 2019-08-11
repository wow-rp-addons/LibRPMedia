return {
    -- Project token for this game variant.
    project = "WOW_PROJECT_CLASSIC",
    -- Product name for obtaining data from the patch/CDN servers.
    product = "wow_classic",
    -- Region to use when connecting to patch/CDN server.
    region = "eu",

    -- Name of the database file to generate.
    database = "LibRPMedia-Classic-1.0.lua",
    -- Name of the manifest file to generate.
    manifest = "Exporter/Data/Classic.lua",

    -- Settings for icon database generation.
    icons = {
        -- List of icon name patterns to exclude from the database.
        excludeNames = {
            -- "Blizzard" branded icons.
            "^mail_gmicon$",
        },
    },

    -- Settings for music database generation.
    music = {
        -- List of file IDs to exclude from the database.
        excludeFiles = {},

        -- List of file/sound kit name patterns to exclude from the database.
        excludeNames = {},
    },
};
