return {
    -- Expression that must evaluate to true for the generated file to load.
    loadexpr = "WOW_PROJECT_ID == WOW_PROJECT_MAINLINE",
    -- Product name for obtaining data from the patch/CDN servers.
    product = "wowt",
    -- Region to use when connecting to patch/CDN server.
    region = "us",

    -- Name of the database file to generate.
    database = "LibRPMedia-Retail-1.0.lua",
    -- Name of the manifest file to generate.
    manifest = "Exporter/Data/Retail.lua",

    -- Override mapping of DB2 names to explicit build versions to download.
    databaseOverrides = {
        soundkitname = "8.3.0.32218", -- Removed after this build.
    },

    -- Settings for icon database generation.
    icons = {
        -- List of icon name patterns to exclude from the database.
        excludeNames = {
            -- Non-icons.
            "^7fx_alphamask_glow_teal_blend$",
            "^6ih_ironhorde_stone_base_stonewalledge$",
            "^6or_garrison_",
            "^cape_draenorcraftedcaster_d_",
            "^cape_draenorraid_",
            "^organic_reflect01$",
            "^shield_draenorraid_",
            "^sword_1h_artifactfelomelorn_d_",
            "^sword_2h_ebonblade_b_",
            "^thrown_1h_",

            -- "Blizzard" branded icons.
            "^mail_gmicon$",
            "^ui_shop_bcv$",

            -- Encrypted files; these require file ID support.
            "^inv_redbird$",
            "^inv_snowkid$",
            "^inv_skiff$",
            "^inv_explorergyrocopter$",
            "^inv_camelmount2$",
            "^inv_aetherbase$", -- Shadowlands prepurchase rewards.
            "^inv_aetherserpentmount$",
            "^inv_aetherserpentpet$",
            "^inv_hearthstone_aether$",
            "^inv_%a+_armor_oribos_d_01$",
            "^inv_armor_explorer_d_01_%a+$", -- RaF rewards.
            "^inv_marmosetpet$",
            "^inv_hand_1h_naga_c_01 %- copy$",
            "^inv_%a+_armor_faeriedragon_d_01$",
            "^inv_ratmount2$",
            "^inv_ancientmount$",
            "^inv_bearmountblizzard$",
            "^inv_oxmount$",
            "^inv_slothpet$",
            "^inv_warpstalkermount$",
            "^inv_bookmount$",
            "^inv_catmount$",
            "^inv_phoenix2mount_%a+$",
            "^inv_ratmounthearthstone$",
            "^inv_.*encrypted%d+",
            "^inv_armor_murlocbackpack_cape_392289[7-9]",
            "^inv_babyfaeriedragon",
            "^inv_tigermount",
            "^inv_%w+_armor_celestial$",
            "^inv_cape_special_dragon_d_02_%w+$",
            "^inv_catslimemount$",
            "^inv_drakemountemerald$",
            "^inv_drakonidpet$",
            "^inv_helm_cloth_sindragosa_d_01$",
            "^inv_murkyalexstrasza$",
            "^inv_murlocbabyblueblack$",
            "^inv_nethergorgedgreatwyrm$",
            "^inv_ursocpet$",
            "^inv_frostbroodprotowyrm$",
            "^inv_murlocmount$",
        },

        -- List of atlas name patterns to include.
        includeAtlases = {
            -- Race icons. Disabled for now until atlas support is set up.
            -- "^raceicon%-",
            -- "^classicon%-",
        },
    },

    -- Settings for music database generation.
    music = {
        -- Mapping of soundkit IDs to be explicitly included or excluded.
        -- The value of each entry should be false to omit the soundkit,
        -- true to include it, or a string to include it with a custom name.
        --
        -- If a kit is included, a name must be obtainable from the client
        -- databases; if not, it will be skipped and a debug message logged.
        --
        -- Custom names take priority over those found within the client
        -- databases.
        --
        -- Soundkits present within this mapping will be overridden and
        -- excluded if matching any of the files or names present in the
        -- excludeFiles and excludeNames lists.
        overrideKits = {},

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
            642256, -- Used by soundkit 30582, file doesn't exist.
        },

        -- List of file/soundkit name patterns to exclude from the database.
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
