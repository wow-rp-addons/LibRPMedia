return {
    -- Expression that must evaluate to true for the generated file to load.
    loadexpr = "LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING",
    -- Product name for obtaining data from the patch/CDN servers.
    product = "wow_classic",
    -- Region to use when connecting to patch/CDN server.
    region = "us",

    -- Name of the database file to generate.
    database = "LibRPMedia-Wrath-1.0.lua",
    -- Name of the manifest file to generate.
    manifest = "Exporter/Data/Wrath.lua",

    -- Override mapping of DB2 names to explicit build versions to download.
    databaseOverrides = {
        soundkitname = "2.5.4.44833", -- Removed after this build.
    },

    -- Settings for icon database generation.
    icons = {
        -- List of icon name patterns to exclude from the database.
        excludeNames = {
            -- Non-icons.
            "^thrown_1h_",

            -- "Blizzard" branded icons.
            "^mail_gmicon$",

            -- Invisible icons.
            "^inv_mace_18$",
            "^inv_staff_37$",

            -- Icons that are clearly Retail-only and show up in the filelist
            -- for classic and are perfectly downloadable, but the client
            -- doesn't actually have because Classic is probably some sort of
            -- weird hackjob.
            "^ability_blackhand_",
            "^ability_deathwing_",
            "^ability_racial_viciousness",
            "^garr_currencyicon",
            "^inv_drink_31_embalmingfluid$",
            "^inv_misc_food_meat_raw_07$",
            "^sha_inv_misc_",
            "^spell_arcane_teleporthalloftheguardian",
            "^xpbonus_icon$",
        },
    },

    -- Settings for music database generation.
    music = {
        -- List of file IDs to exclude from the database.
        excludeFiles = {
            566236, -- Zone Music Kit "temp_mono" (1s duration)
        },

        -- List of file/soundkit name patterns to exclude from the database.
        excludeNames = {},
    },
};
