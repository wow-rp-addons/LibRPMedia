return {
    -- Project token for this game variant.
    project = "WOW_PROJECT_MAINLINE",
    -- Product name for obtaining data from the patch/CDN servers.
    product = "wow",
    -- Region to use when connecting to patch/CDN server.
    region = "eu",

    -- Name of the database file to generate.
    database = "LibRPMedia-Retail-1.0.lua",
    -- Name of the manifest file to generate.
    manifest = "Exporter/Data/Retail.lua",

    -- Settings for icon database generation.
    icons = {
        -- List of icon name patterns to exclude from the database.
        excludeNames = {
            -- Non-icons.
            "^6ih_ironhorde_stone_base_stonewalledge$",
            "^6or_garrison_",
            "^cape_draenorcraftedcaster_d_",
            "^cape_draenorraid_",
            "^organic_reflect01$",
            "^shield_draenorraid_",
            "^sword_1h_artifactfelomelorn_d_",
            "^sword_2h_ebonblade_b_",
            "^thrown_1h_",
            "^thumbsdown$",
            "^thumbsup$",
            "^thumbup$",

            -- "Blizzard" branded icons.
            "^mail_gmicon$",
            "^ui_shop_bcv$",

            -- Encrypted icon files.
            "inv_8xp_encrypted07",
            "inv_encrypted14",
            "inv_encrypted15",
        },

        -- List of atlas name patterns to include.
        includeAtlases = {
            -- Race icons.
            "^raceicon%-",
        },
    },

    -- Settings for music database generation.
    music = {
        -- List of file IDs to exclude from the database.
        excludeFiles = {
            538910, -- Sound test file ("sound/soundtest06.ogg").
            538911, -- Sound test file ("sound/soundtest01.ogg").
            538917, -- Sound test file ("sound/soundtest02.ogg").
            538925, -- Sound test file ("sound/soundtest05.ogg").
            538942, -- Sound test file ("sound/soundtest07.ogg").
            538945, -- Sound test file ("sound/soundtest03.ogg").
            538949, -- Sound test file ("sound/soundtest10.ogg").
            538952, -- Sound test file ("sound/soundtest09.ogg").
            538953, -- Sound test file ("sound/soundtest08.ogg").
            538960, -- Sound test file ("sound/soundtest04.ogg").
            566236, -- Placeholder file ("sound/doodad/tempmono.ogg").
            567481, -- quest - kezan - "cruising" - duck the music
            629319, -- Sound test file ("mus_soundtest_music01.mp3").
            629320, -- Sound test file ("mus_soundtest_music02.mp3").
            629321, -- Sound test file ("mus_soundtest_music03.mp3").
            642256, -- Used by sound kit 30582, file doesn't exist.
        },

        -- List of file/sound kit name patterns to exclude from the database.
        excludeNames = {
            -- Any soundkits with these tags should be skipped.
            "^%[not used%]",
            "^%[ph%]",

            -- Files with short durations/aren't actually music.
            "^battleforazeroth/rtc_",
            "^clientscene_60_auchindoun_terongor_portalopen$",
            "^clientscene_60_highmaul_chogall_portalopen$",
            "^clientscene_60_highmaul_chogall_spellcast$",
            "^clientscene_70_artif_wr_prot_bossreveal_roar$",
            "^clientscene_70_demonhunter_oh_campaign_immortalsoul_spawnfx",
            "^clientscene_70_suramar_manatree_treefx$",
            "^clientscene_70_suramar_moonfallwave_intro_spidersounds$",
            "^clientscene_70_suramar_moonfallwave_outro_pullarcandor$",
            "^clientscene_70_suramar_reversal_silencespell",
            "^clientscene_725_chromiegetsblasted_missile",
            "^rtc_82_",
            "^russell_testsound_",
            "^russell's test ducking sound",
        },
    },
};
