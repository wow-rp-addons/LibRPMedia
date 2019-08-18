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
            "^achievement_character_human_",
            "^achievement_dungeon_naxxramas",
            "^garr_currencyicon",
            "^inv_drink_31_embalmingfluid$",
            "^inv_misc_bone_humanskull_02$",
            "^inv_misc_bone_skull_01$",
            "^inv_misc_eye_02$",
            "^inv_misc_eye_04$",
            "^inv_misc_firedancer_01$",
            "^inv_misc_food_meat_raw_07$",
            "^inv_misc_head_nerubian_01$",
            "^quest_12252_icon$",
            "^sha_inv_misc_",
            "^spell_arcane_teleporthalloftheguardian",
            "^spell_deathknight_",
            "^spell_shadow_brainwash",
            "^xp_icon$",
            "^xpbonus_icon$",
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
