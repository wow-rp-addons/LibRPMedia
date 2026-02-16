local Constants = {};

local iota do
    local next = 0;

    ---@param value integer?
    ---@return integer value
    function iota(value)
        value = value or next;
        next = value + 1;
        return value;
    end
end

Constants.IconCategory = setmetatable({
    Achievement            = iota(0),
    Ability                = iota(),
    Housing                = iota(),
    Item                   = iota(),
    Drink                  = iota(),
    Food                   = iota(),
    Mount                  = iota(),
    Pet                    = iota(),
    Potion                 = iota(),
    TradeGoods             = iota(),
    Warrior                = iota(),
    Paladin                = iota(),
    Hunter                 = iota(),
    Rogue                  = iota(),
    Priest                 = iota(),
    DeathKnight            = iota(),
    Shaman                 = iota(),
    Mage                   = iota(),
    Warlock                = iota(),
    Monk                   = iota(),
    Druid                  = iota(),
    DemonHunter            = iota(),
    Evoker                 = iota(),
    Weapon                 = iota(),
    WeaponTypeAxe          = iota(),
    WeaponTypeDagger       = iota(),
    WeaponTypeMace         = iota(),
    WeaponTypePolearm      = iota(),
    WeaponTypeStaff        = iota(),
    WeaponTypeSword        = iota(),
    WeaponTypeFists        = iota(),
    WeaponTypeWarglaive    = iota(),
    WeaponTypeAmmo         = iota(),
    WeaponTypeBow          = iota(),
    WeaponTypeCrossbow     = iota(),
    WeaponTypeGun          = iota(),
    WeaponTypeThrown       = iota(),
    WeaponTypeWand         = iota(),
    Armor                  = iota(),
    Jewelry                = iota(),
    ClothArmor             = iota(),
    LeatherArmor           = iota(),
    MailArmor              = iota(),
    PlateArmor             = iota(),
    InventorySlotHead      = iota(),
    InventorySlotBack      = iota(),
    InventorySlotChest     = iota(),
    InventorySlotFeet      = iota(),
    InventorySlotHands     = iota(),
    InventorySlotLegs      = iota(),
    InventorySlotShirt     = iota(),
    InventorySlotShoulders = iota(),
    InventorySlotTabard    = iota(),
    InventorySlotWaist     = iota(),
    InventorySlotWrists    = iota(),
    InventorySlotOffHand   = iota(),
    InventorySlotShield    = iota(),
    InventorySlotNeck      = iota(),
    InventorySlotRing      = iota(),
    InventorySlotTrinket   = iota(),
    ArcaneMagic            = iota(),
    FelMagic               = iota(),
    FireMagic              = iota(),
    FrostMagic             = iota(),
    HolyMagic              = iota(),
    NatureMagic            = iota(),
    ShadowMagic            = iota(),
    VoidMagic              = iota(),
    Alliance               = iota(),
    Horde                  = iota(),
    OtherFactions          = iota(),
    Professions            = iota(),
    Alchemy                = iota(),
    Archaeology            = iota(),
    Blacksmithing          = iota(),
    Cooking                = iota(),
    Enchanting             = iota(),
    Engineering            = iota(),
    FirstAid               = iota(),
    Herbalism              = iota(),
    Inscription            = iota(),
    Jewelcrafting          = iota(),
    Leatherworking         = iota(),
    Mining                 = iota(),
    Skinning               = iota(),
    Tailoring              = iota(),
    Fishing                = iota(),
    Human                  = iota(),
    Dwarven                = iota(),
    Elven                  = iota(),
    Gnomish                = iota(),
    Draenei                = iota(),
    Worgen                 = iota(),
    Orcish                 = iota(),
    Undead                 = iota(),
    Tauren                 = iota(),
    Troll                  = iota(),
    Goblin                 = iota(),
    Vulpera                = iota(),
    Pandaren               = iota(),
    Dracthyr               = iota(),
    Haranir                = iota(),
}, { __index = function(_, k) error("unknown category: " .. k); end });

Constants.IconCategoryParents = {
    [Constants.IconCategory.WeaponTypeAmmo] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeAxe] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeBow] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeCrossbow] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeDagger] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeFists] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeGun] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeMace] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypePolearm] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeStaff] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeSword] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeThrown] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeWand] = Constants.IconCategory.Weapon,
    [Constants.IconCategory.WeaponTypeWarglaive] = Constants.IconCategory.Weapon,

    [Constants.IconCategory.ClothArmor] = Constants.IconCategory.Armor,
    [Constants.IconCategory.LeatherArmor] = Constants.IconCategory.Armor,
    [Constants.IconCategory.MailArmor] = Constants.IconCategory.Armor,
    [Constants.IconCategory.PlateArmor] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotHead] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotBack] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotChest] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotFeet] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotHands] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotLegs] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotShirt] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotShoulders] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotTabard] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotWaist] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotWrists] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotOffHand] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotShield] = Constants.IconCategory.Armor,
    [Constants.IconCategory.InventorySlotNeck] = Constants.IconCategory.Jewelry,
    [Constants.IconCategory.InventorySlotRing] = Constants.IconCategory.Jewelry,
    [Constants.IconCategory.InventorySlotTrinket] = Constants.IconCategory.Jewelry,

    [Constants.IconCategory.Potion] = Constants.IconCategory.Item,
    [Constants.IconCategory.Food] = Constants.IconCategory.Item,
    [Constants.IconCategory.Drink] = Constants.IconCategory.Item,
    [Constants.IconCategory.TradeGoods] = Constants.IconCategory.Item,
};

local function All(...)
    local funcs = { ... };
    local count = #funcs;

    return function(n)
        for i = 1, count do
            if not funcs[i](n) then
                return false;
            end
        end

        return true;
    end;
end

local function Any(...)
    local funcs = { ... };
    local count = #funcs;

    return function(n)
        for i = 1, count do
            if funcs[i](n) then
                return true;
            end
        end

        return false;
    end;
end

local function Not(a)
    return function(n) return not a(n); end;
end

local function Match(p)
    return function(n) return string.find(n, p) ~= nil; end;
end

local function Prefix(word)
    return Match("^" .. word);
end

local function Suffix(word)  -- luacheck: no unused
    return Match(word .. "$");
end

local function Substring(str)
    return Match(str);
end

local function Word(word)
    return Match("%f[%w]" .. word .. "%f[%W]");
end

local function WordPrefix(prefix)
    return Match("%f[%w]" .. prefix);
end

local function WordSuffix(suffix)
    return Match(suffix .. "%f[%W]");
end

local function WordBoundary(str)
    return Any(WordPrefix(str), WordSuffix(str));
end

-- luacheck: push ignore

Constants.IconCategoryPatterns = {
    -- Spell & Abilities
    { predicate = Word "ability", tags = { Constants.IconCategory.Ability } },
    { predicate = Word "spell", tags = { Constants.IconCategory.Ability } },
    { predicate = Word "raidability", tags = { Constants.IconCategory.Ability } },

    -- Achievements
    { predicate = Word "achieve?ment", tags = { Constants.IconCategory.Achievement } },

    -- Items
    { predicate = Word "item", tags = { Constants.IconCategory.Item } },
    { predicate = All ( Prefix "inv", Not ( Any ( Word "ability", Word "spell" ) ) ), tags = { Constants.IconCategory.Item } },
    { predicate = All ( Prefix "inv", Word "drink" ), tags = { Constants.IconCategory.Drink } },
    { predicate = All ( Prefix "inv", Word "food", Not ( Word "armor" ) ), tags = { Constants.IconCategory.Food } },
    { predicate = Substring "mount", tags = { Constants.IconCategory.Mount } },
    { predicate = WordBoundary "charger", tags = { Constants.IconCategory.Mount } },
    { predicate = WordBoundary "petbattle", tags = { Constants.IconCategory.Pet } },
    { predicate = WordBoundary "petfamily", tags = { Constants.IconCategory.Pet } },
    { predicate = WordBoundary "upgradestone", tags = { Constants.IconCategory.Pet } },
    { predicate = WordBoundary "pet", tags = { Constants.IconCategory.Pet } },

    -- Housing
    { predicate = Word "endeavor", tags = { Constants.IconCategory.Housing } },
    { predicate = Word "homestone", tags = { Constants.IconCategory.Housing } },
    { predicate = Word "house", tags = { Constants.IconCategory.Housing } },
    { predicate = Word "housing", tags = { Constants.IconCategory.Housing } },
    { predicate = Word "neighborhood", tags = { Constants.IconCategory.Housing } },

    -- Armor
    { predicate = All ( Prefix "inv", Word "armor" ), tags = { Constants.IconCategory.Armor } },
    { predicate = All ( Prefix "inv", Word "jewelry" ), tags = { Constants.IconCategory.Jewelry } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "cloth" ), tags = { Constants.IconCategory.ClothArmor } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "leather" ), tags = { Constants.IconCategory.LeatherArmor } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "mail" ), tags = { Constants.IconCategory.MailArmor } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "plate" ), tags = { Constants.IconCategory.PlateArmor } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "head" ), tags = { Constants.IconCategory.InventorySlotHead } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "helm" ), tags = { Constants.IconCategory.InventorySlotHead } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "helmet" ), tags = { Constants.IconCategory.InventorySlotHead } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "amulet" ), tags = { Constants.IconCategory.InventorySlotNeck } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "necklace" ), tags = { Constants.IconCategory.InventorySlotNeck } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "shoulders?" ), tags = { Constants.IconCategory.InventorySlotShoulders } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "back" ), tags = { Constants.IconCategory.InventorySlotBack } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "cape" ), tags = { Constants.IconCategory.InventorySlotBack } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "cloak" ), tags = { Constants.IconCategory.InventorySlotBack } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "chest" ), tags = { Constants.IconCategory.InventorySlotChest } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "robe" ), tags = { Constants.IconCategory.InventorySlotChest } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "shirt" ), tags = { Constants.IconCategory.InventorySlotShirt } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "tabard" ), tags = { Constants.IconCategory.InventorySlotTabard } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "bracers?" ), tags = { Constants.IconCategory.InventorySlotWrists } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "gauntlets?", Not ( Word "weapon" ) ), tags = { Constants.IconCategory.InventorySlotHands } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "gloves?", Not ( Word "weapon" ) ), tags = { Constants.IconCategory.InventorySlotHands } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "hands?", Not ( Word "weapon" ) ), tags = { Constants.IconCategory.InventorySlotHands } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "belt" ), tags = { Constants.IconCategory.InventorySlotWaist } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "buckle"), tags = { Constants.IconCategory.InventorySlotWaist } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "pants?" ), tags = { Constants.IconCategory.InventorySlotLegs } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "boots?" ), tags = { Constants.IconCategory.InventorySlotFeet } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "ring" ), tags = { Constants.IconCategory.InventorySlotRing } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "trinkets?" ), tags = { Constants.IconCategory.InventorySlotTrinket } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "offhand" ), tags = { Constants.IconCategory.InventorySlotOffHand } },
    { predicate = All ( Any ( Prefix "inv", Word "armor" ), WordBoundary "jewelrytrinkets?" ), tags = { Constants.IconCategory.InventorySlotTrinket } },

    -- Weapons
    { predicate = All ( Prefix "inv", Word "weapon" ), tags = { Constants.IconCategory.Weapon } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "arrow" ), tags = { Constants.IconCategory.WeaponTypeAmmo } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "axe" ), tags = { Constants.IconCategory.WeaponTypeAxe } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "bow" ), tags = { Constants.IconCategory.WeaponTypeBow } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "bullet" ), tags = { Constants.IconCategory.WeaponTypeAmmo } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "chakr[au]m" ), tags = { Constants.IconCategory.WeaponTypeThrown } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "crossbow" ), tags = { Constants.IconCategory.WeaponTypeCrossbow } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "dagger" ), tags = { Constants.IconCategory.WeaponTypeDagger } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "firearm" ), tags = { Constants.IconCategory.WeaponTypeGun } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "flail" ), tags = { Constants.IconCategory.WeaponTypeMace } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "glaive" ), tags = { Constants.IconCategory.WeaponTypeSword, Constants.IconCategory.WeaponTypeWarglaive } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "gun" ), tags = { Constants.IconCategory.WeaponTypeGun } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "halberd" ), tags = { Constants.IconCategory.WeaponTypePolearm } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "knife" ), tags = { Constants.IconCategory.WeaponTypeDagger } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "mace" ), tags = { Constants.IconCategory.WeaponTypeMace } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "pike" ), tags = { Constants.IconCategory.WeaponTypePolearm } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "polearm" ), tags = { Constants.IconCategory.WeaponTypePolearm } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "rifle" ), tags = { Constants.IconCategory.WeaponTypeGun } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "shield" ), tags = { Constants.IconCategory.InventorySlotShield } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "shortblade" ), tags = { Constants.IconCategory.WeaponTypeSword } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "staff" ), tags = { Constants.IconCategory.WeaponTypeStaff } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "stave" ), tags = { Constants.IconCategory.WeaponTypeStaff } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "sword" ), tags = { Constants.IconCategory.WeaponTypeSword } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "throwingaxe" ), tags = { Constants.IconCategory.WeaponTypeThrown } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "throwingknife" ), tags = { Constants.IconCategory.WeaponTypeThrown } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "thrown" ), tags = { Constants.IconCategory.WeaponTypeThrown } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "wand" ), tags = { Constants.IconCategory.WeaponTypeWand } },
    { predicate = All ( Any ( Prefix "inv", Word "weapon", WordBoundary "[12]h" ), WordBoundary "warglaive" ), tags = { Constants.IconCategory.WeaponTypeSword, Constants.IconCategory.WeaponTypeWarglaive } },
    { predicate = All ( Prefix "inv", Substring "weapon", WordBoundary "gauntlets?" ), tags = { Constants.IconCategory.WeaponTypeFists } },
    { predicate = All ( Prefix "inv", Substring "weapon", WordBoundary "gloves?" ), tags = { Constants.IconCategory.WeaponTypeFists } },
    { predicate = All ( Prefix "inv", Substring "weapon", WordBoundary "hands?" ), tags = { Constants.IconCategory.WeaponTypeFists } },
    { predicate = All ( WordBoundary "stave", WordBoundary "tarecgosa" ), tags = { Constants.IconCategory.WeaponTypeStaff } },

    -- Cultures
    { predicate = Word "bloodknight", tags = { Constants.IconCategory.Elven } },
    { predicate = Word "bloodelf", tags = { Constants.IconCategory.Elven } },
    { predicate = Word "darkiron", tags = { Constants.IconCategory.Dwarven } },
    { predicate = Word "darkirondwarf", tags = { Constants.IconCategory.Dwarven } },
    { predicate = Word "dracthyr", tags = { Constants.IconCategory.Dracthyr } },
    { predicate = Word "draenei", tags = { Constants.IconCategory.Draenei } },
    { predicate = Word "dwarf", tags = { Constants.IconCategory.Dwarven } },
    { predicate = Word "earthen", tags = { Constants.IconCategory.Dwarven } },
    { predicate = Word "gnome", tags = { Constants.IconCategory.Gnomish } },
    { predicate = Word "goblin", tags = { Constants.IconCategory.Goblin } },
    { predicate = Word "haranir", tags = { Constants.IconCategory.Haranir } },
    { predicate = Word "harr?onir", tags = { Constants.IconCategory.Haranir } },
    { predicate = Word "highmountain", tags = { Constants.IconCategory.Tauren } },
    { predicate = Word "highmountaintauren", tags = { Constants.IconCategory.Tauren } },
    { predicate = Word "human", tags = { Constants.IconCategory.Human } },
    { predicate = Word "kultiran", tags = { Constants.IconCategory.Human } },
    { predicate = Word "kultiras", tags = { Constants.IconCategory.Human } },
    { predicate = Word "lightforged", tags = { Constants.IconCategory.Draenei } },
    { predicate = Word "lightforgeddraenei", tags = { Constants.IconCategory.Draenei } },
    { predicate = Word "maghar", tags = { Constants.IconCategory.Orcish } },
    { predicate = Word "magharorc", tags = { Constants.IconCategory.Orcish } },
    { predicate = Word "mechagnome", tags = { Constants.IconCategory.Gnomish } },
    { predicate = Word "nightborne?", tags = { Constants.IconCategory.Elven } },
    { predicate = Word "nightelf", tags = { Constants.IconCategory.Elven } },
    { predicate = Word "orc", tags = { Constants.IconCategory.Orcish } },
    { predicate = Word "pandaren", tags = { Constants.IconCategory.Pandaren } },
    { predicate = Word "pandaria", tags = { Constants.IconCategory.Pandaren } },
    { predicate = Word "tauren", tags = { Constants.IconCategory.Tauren } },
    { predicate = Word "troll", tags = { Constants.IconCategory.Troll } },
    { predicate = Word "undead", tags = { Constants.IconCategory.Undead } },
    { predicate = Word "voidelf", tags = { Constants.IconCategory.Elven } },
    { predicate = Word "vulpera", tags = { Constants.IconCategory.Vulpera } },
    { predicate = Word "worgen", tags = { Constants.IconCategory.Worgen } },
    { predicate = Word "zandalari", tags = { Constants.IconCategory.Troll } },
    { predicate = Word "zandalaritroll", tags = { Constants.IconCategory.Troll } },
    { predicate = Substring "eversong", tags = { Constants.IconCategory.Elven } },
    { predicate = WordBoundary "amani", tags = { Constants.IconCategory.Troll } },
    { predicate = All ( Word "majorfactions?", Word "candle" ), tags = { Constants.IconCategory.Dwarven } },
    { predicate = All ( Word "majorfactions?", Word "flame" ), tags = { Constants.IconCategory.Human } },
    { predicate = All ( Word "majorfactions?", Word "storm" ), tags = { Constants.IconCategory.Dwarven } },
    { predicate = All ( Word "majorfactions?", Word "rocket" ), tags = { Constants.IconCategory.Dwarven } },
    { predicate = All ( Word "majorfactions?", Word "web" ), tags = { Constants.IconCategory.OtherFactions } },
    { predicate = All ( Word "majorfactions?", Word "sky" ), tags = { Constants.IconCategory.Elven } },
    { predicate = All ( Word "majorfactions?", Word "flames" ), tags = { Constants.IconCategory.Troll } },
    { predicate = All ( Word "majorfactions?", Word "gold" ), tags = { Constants.IconCategory.Elven } },
    { predicate = All ( Word "majorfactions?", Word "vines" ), tags = { Constants.IconCategory.Haranir } },

    -- Racials
    { predicate = Prefix "pandarenracial", tags = { Constants.IconCategory.Ability, Constants.IconCategory.Pandaren } },

    -- Classes
    { predicate = Word "deathknight", tags = { Constants.IconCategory.DeathKnight } },
    { predicate = Word "demonhunter", tags = { Constants.IconCategory.DemonHunter } },
    { predicate = WordBoundary "voiddh", tags = { Constants.IconCategory.DemonHunter } },
    { predicate = All ( Word "dh", Word "void" ), tags = { Constants.IconCategory.DemonHunter } },
    { predicate = Word "druid", tags = { Constants.IconCategory.Druid } },
    { predicate = Word "evoker", tags = { Constants.IconCategory.Evoker } },
    { predicate = Word "hunter", tags = { Constants.IconCategory.Hunter } },
    { predicate = Word "mage", tags = { Constants.IconCategory.Mage } },
    { predicate = Word "monk", tags = { Constants.IconCategory.Monk } },
    { predicate = Word "paladin", tags = { Constants.IconCategory.Paladin } },
    { predicate = Word "priest", tags = { Constants.IconCategory.Priest } },
    { predicate = Word "rogue", tags = { Constants.IconCategory.Rogue } },
    { predicate = Word "shaman", tags = { Constants.IconCategory.Shaman } },
    { predicate = Word "warlock", tags = { Constants.IconCategory.Warlock } },
    { predicate = Word "warrior", tags = { Constants.IconCategory.Warrior } },

    -- Class Equipment
    { predicate = All ( Prefix "inv", Substring "deathknight" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.DeathKnight } },
    { predicate = All ( Prefix "inv", Substring "demonhunter" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.DemonHunter } },
    { predicate = All ( Prefix "inv", Substring "druid" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Druid } },
    { predicate = All ( Prefix "inv", Substring "evoker" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Evoker } },
    { predicate = All ( Prefix "inv", Substring "hunter"), Not ( Substring "demonhunter" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Hunter } },
    { predicate = All ( Prefix "inv", Substring "mage"), Not ( Substring "mageweave" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Mage } },
    { predicate = All ( Prefix "inv", Substring "monk" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Monk } },
    { predicate = All ( Prefix "inv", Substring "paladin" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Paladin } },
    { predicate = All ( Prefix "inv", Substring "priest" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Priest } },
    { predicate = All ( Prefix "inv", Substring "rogue" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Rogue } },
    { predicate = All ( Prefix "inv", Substring "shaman" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Shaman } },
    { predicate = All ( Prefix "inv", Substring "warlock" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warlock } },
    { predicate = All ( Prefix "inv", Substring "warrior" ), tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warrior } },
    { predicate = Substring "dungeondeathknight", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DeathKnight } },
    { predicate = Substring "dungeondemonhunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DemonHunter } },
    { predicate = Substring "dungeondruid", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Druid } },
    { predicate = Substring "dungeonevoker", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Evoker } },
    { predicate = Substring "dungeonhunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Hunter } },
    { predicate = Substring "dungeonmage", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Mage } },
    { predicate = Substring "dungeonmonk", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Monk } },
    { predicate = Substring "dungeonpaladin", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Paladin } },
    { predicate = Substring "dungeonpriest", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Priest } },
    { predicate = Substring "dungeonrogue", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Rogue } },
    { predicate = Substring "dungeonshaman", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Shaman } },
    { predicate = Substring "dungeonwarlock", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warlock } },
    { predicate = Substring "dungeonwarrior", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warrior } },
    { predicate = Substring "pvpdeathknight", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DeathKnight } },
    { predicate = Substring "pvpdemonhunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DemonHunter } },
    { predicate = Substring "pvpdruid", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Druid } },
    { predicate = Substring "pvpevoker", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Evoker } },
    { predicate = Substring "pvphunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Hunter } },
    { predicate = Substring "pvpmage", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Mage } },
    { predicate = Substring "pvpmonk", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Monk } },
    { predicate = Substring "pvppaladin", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Paladin } },
    { predicate = Substring "pvppriest", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Priest } },
    { predicate = Substring "pvprogue", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Rogue } },
    { predicate = Substring "pvpshaman", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Shaman } },
    { predicate = Substring "pvpwarlock", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warlock } },
    { predicate = Substring "pvpwarrior", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warrior } },
    { predicate = Substring "raiddeathknight", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DeathKnight } },
    { predicate = Substring "raiddemonhunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.DemonHunter } },
    { predicate = Substring "raiddruid", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Druid } },
    { predicate = Substring "raidevoker", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Evoker } },
    { predicate = Substring "raidhunter", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Hunter } },
    { predicate = Substring "raidmage", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Mage } },
    { predicate = Substring "raidmonk", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Monk } },
    { predicate = Substring "raidpaladin", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Paladin } },
    { predicate = Substring "raidpriest", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Priest } },
    { predicate = Substring "raidrogue", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Rogue } },
    { predicate = Substring "raidshaman", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Shaman } },
    { predicate = Substring "raidwarlock", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warlock } },
    { predicate = Substring "raidwarrior", tags = { Constants.IconCategory.Armor, Constants.IconCategory.Warrior } },
    { predicate = All ( Word "armor", Substring "deathknight" ), tags = { Constants.IconCategory.PlateArmor, Constants.IconCategory.DeathKnight } },
    { predicate = All ( Word "armor", Substring "demonhunter" ), tags = { Constants.IconCategory.LeatherArmor, Constants.IconCategory.DemonHunter } },
    { predicate = All ( Word "armor", Substring "druid" ), tags = { Constants.IconCategory.LeatherArmor, Constants.IconCategory.Druid } },
    { predicate = All ( Word "armor", Substring "evoker" ), tags = { Constants.IconCategory.MailArmor, Constants.IconCategory.Evoker } },
    { predicate = All ( Word "armor", Substring "hunter" ), tags = { Constants.IconCategory.MailArmor, Constants.IconCategory.Hunter } },
    { predicate = All ( Word "armor", Substring "mage" ), tags = { Constants.IconCategory.ClothArmor, Constants.IconCategory.Mage } },
    { predicate = All ( Word "armor", Substring "monk" ), tags = { Constants.IconCategory.LeatherArmor, Constants.IconCategory.Monk } },
    { predicate = All ( Word "armor", Substring "paladin" ), tags = { Constants.IconCategory.PlateArmor, Constants.IconCategory.Paladin } },
    { predicate = All ( Word "armor", Substring "priest" ), tags = { Constants.IconCategory.ClothArmor, Constants.IconCategory.Priest } },
    { predicate = All ( Word "armor", Substring "rogue" ), tags = { Constants.IconCategory.LeatherArmor, Constants.IconCategory.Rogue } },
    { predicate = All ( Word "armor", Substring "shaman" ), tags = { Constants.IconCategory.MailArmor, Constants.IconCategory.Shaman } },
    { predicate = All ( Word "armor", Substring "warlock" ), tags = { Constants.IconCategory.ClothArmor, Constants.IconCategory.Warlock } },
    { predicate = All ( Word "armor", Substring "warrior" ), tags = { Constants.IconCategory.PlateArmor, Constants.IconCategory.Warrior } },
    { predicate = All ( Word "weapon", Substring "deathknight" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.DeathKnight } },
    { predicate = All ( Word "weapon", Substring "demonhunter" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.DemonHunter } },
    { predicate = All ( Word "weapon", Substring "druid" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Druid } },
    { predicate = All ( Word "weapon", Substring "evoker" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Evoker } },
    { predicate = All ( Word "weapon", Substring "hunter" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Hunter } },
    { predicate = All ( Word "weapon", Substring "mage" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Mage } },
    { predicate = All ( Word "weapon", Substring "monk" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Monk } },
    { predicate = All ( Word "weapon", Substring "paladin" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Paladin } },
    { predicate = All ( Word "weapon", Substring "priest" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Priest } },
    { predicate = All ( Word "weapon", Substring "rogue" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Rogue } },
    { predicate = All ( Word "weapon", Substring "shaman" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Shaman } },
    { predicate = All ( Word "weapon", Substring "warlock" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Warlock } },
    { predicate = All ( Word "weapon", Substring "warrior" ), tags = { Constants.IconCategory.Weapon, Constants.IconCategory.Warrior } },

    -- Class Spells
    { predicate = All ( Prefix "artifactability", Substring "deathknight" ), tags = { Constants.IconCategory.DeathKnight } },
    { predicate = All ( Prefix "artifactability", Substring "demonhunter" ), tags = { Constants.IconCategory.DemonHunter } },
    { predicate = All ( Prefix "artifactability", Substring "druid" ), tags = { Constants.IconCategory.Druid } },
    { predicate = All ( Prefix "artifactability", Substring "evoker" ), tags = { Constants.IconCategory.Evoker } },
    { predicate = All ( Prefix "artifactability", Substring "hunter" ), tags = { Constants.IconCategory.Hunter } },
    { predicate = All ( Prefix "artifactability", Substring "mage" ), tags = { Constants.IconCategory.Mage } },
    { predicate = All ( Prefix "artifactability", Substring "monk" ), tags = { Constants.IconCategory.Monk } },
    { predicate = All ( Prefix "artifactability", Substring "paladin" ), tags = { Constants.IconCategory.Paladin } },
    { predicate = All ( Prefix "artifactability", Substring "priest" ), tags = { Constants.IconCategory.Priest } },
    { predicate = All ( Prefix "artifactability", Substring "rogue" ), tags = { Constants.IconCategory.Rogue } },
    { predicate = All ( Prefix "artifactability", Substring "shaman" ), tags = { Constants.IconCategory.Shaman } },
    { predicate = All ( Prefix "artifactability", Substring "warlock" ), tags = { Constants.IconCategory.Warlock } },
    { predicate = All ( Prefix "artifactability", Substring "warrior" ), tags = { Constants.IconCategory.Warrior } },

    -- Factions
    { predicate = Word "alliance", tags = { Constants.IconCategory.Alliance } },
    { predicate = Word "allianceicon", tags = { Constants.IconCategory.Alliance } },
    { predicate = Word "horde", tags = { Constants.IconCategory.Horde } },
    { predicate = Word "hordeicon", tags = { Constants.IconCategory.Horde } },
    { predicate = WordBoundary "valdrakken", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "niffen", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "ardenweald", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "bastion", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "kyrian", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "maldraxxus", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "necrolord", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "nightfae", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "venthyr", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "progenitor", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "revendreth", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "thegeneral", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "thevizier", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "theweaver", tags = { Constants.IconCategory.OtherFactions } },
    { predicate = WordBoundary "majorfactions?", tags = { Constants.IconCategory.OtherFactions } },

    -- Spell Schools
    { predicate = Word "arcane", tags = { Constants.IconCategory.ArcaneMagic } },
    { predicate = Word "fire", tags = { Constants.IconCategory.FireMagic } },
    { predicate = Word "frost", tags = { Constants.IconCategory.FrostMagic } },
    { predicate = Word "holy", tags = { Constants.IconCategory.HolyMagic } },
    { predicate = Word "nature", tags = { Constants.IconCategory.NatureMagic } },
    { predicate = Word "shadow", tags = { Constants.IconCategory.ShadowMagic } },

    -- Spell Themes
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "arcane" ), tags = { Constants.IconCategory.Mage, Constants.IconCategory.ArcaneMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "blessing" ), tags = { Constants.IconCategory.Paladin } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "deathknight" ), tags = { Constants.IconCategory.DeathKnight } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "featherfall" ), tags = { Constants.IconCategory.Mage } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "fire"), Not ( Any ( WordPrefix "fel", WordSuffix "fel" ) ), tags = { Constants.IconCategory.Mage } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "fire" ), tags = { Constants.IconCategory.Warlock, Constants.IconCategory.FireMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "frost" ), tags = { Constants.IconCategory.Mage, Constants.IconCategory.FrostMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "frostfire" ), tags = { Constants.IconCategory.Mage, Constants.IconCategory.FrostMagic, Constants.IconCategory.FireMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "holy", Not ( Substring "unholy" ) ), tags = { Constants.IconCategory.HolyMagic , Constants.IconCategory.Priest, Constants.IconCategory.Paladin } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "nature" ), tags = { Constants.IconCategory.Druid, Constants.IconCategory.Shaman, Constants.IconCategory.NatureMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "polymorph" ), tags = { Constants.IconCategory.Mage, Constants.IconCategory.ArcaneMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "shadow" ), tags = { Constants.IconCategory.Priest, Constants.IconCategory.Warlock, Constants.IconCategory.DeathKnight, Constants.IconCategory.ShadowMagic } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "astral" ), tags = { Constants.IconCategory.Druid } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "eclipse" ), tags = { Constants.IconCategory.Druid } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "lunar" ), tags = { Constants.IconCategory.Druid } },
    { predicate = All ( Any ( Prefix "ability", Prefix "spell" ), Substring "solar" ), tags = { Constants.IconCategory.Druid } },
    { predicate = Substring "totem", tags = { Constants.IconCategory.Shaman, Constants.IconCategory.NatureMagic } },
    { predicate = Word "brewpoison", tags = { Constants.IconCategory.Rogue } },
    { predicate = Word "poison", tags = { Constants.IconCategory.Rogue } },
    { predicate = Word "portal", tags = { Constants.IconCategory.Mage, Constants.IconCategory.ArcaneMagic } },
    { predicate = Word "stealth", tags = { Constants.IconCategory.Rogue } },
    { predicate = Word "teleport", tags = { Constants.IconCategory.Mage, Constants.IconCategory.ArcaneMagic } },
    { predicate = Word "void", tags = { Constants.IconCategory.VoidMagic } },
    { predicate = WordBoundary "fel", tags = { Constants.IconCategory.FelMagic } },
    { predicate = WordBoundary "void", tags = { Constants.IconCategory.VoidMagic } },

    -- Professions
    { predicate = Word "alchemy", tags = { Constants.IconCategory.Alchemy } },
    { predicate = Word "archaeology", tags = { Constants.IconCategory.Archaeology } },
    { predicate = Word "blacksmithing", tags = { Constants.IconCategory.Blacksmithing } },
    { predicate = Word "cooking", tags = { Constants.IconCategory.Cooking } },
    { predicate = Word "crafting", tags = { Constants.IconCategory.Professions, Constants.IconCategory.TradeGoods } },
    { predicate = Word "enchant", tags = { Constants.IconCategory.Enchanting } },
    { predicate = Word "enchanting", tags = { Constants.IconCategory.Enchanting } },
    { predicate = Word "engineering", tags = { Constants.IconCategory.Engineering } },
    { predicate = Word "firstaid", tags = { Constants.IconCategory.FirstAid } },
    { predicate = Word "fishing", tags = { Constants.IconCategory.Fishing } },
    { predicate = WordBoundary "fishingpole", tags = { Constants.IconCategory.Fishing } },
    { predicate = Word "herbalism", tags = { Constants.IconCategory.Herbalism } },
    { predicate = Word "inscription", tags = { Constants.IconCategory.Inscription } },
    { predicate = Word "jewelcrafting", tags = { Constants.IconCategory.Jewelcrafting } },
    { predicate = Word "leatherworking", tags = { Constants.IconCategory.Leatherworking } },
    { predicate = Word "mining", tags = { Constants.IconCategory.Mining } },
    { predicate = Word "professions?", tags = { Constants.IconCategory.Professions } },
    { predicate = Word "skinning", tags = { Constants.IconCategory.Skinning } },
    { predicate = Word "tailoring", tags = { Constants.IconCategory.Tailoring } },
    { predicate = Word "trade", tags = { Constants.IconCategory.TradeGoods } },

    -- Profession resources
    { predicate = All ( Prefix "inv", Substring "bag" ), tags = { Constants.IconCategory.Tailoring } },
    { predicate = All ( Prefix "inv", Substring "clothbolt" ), tags = { Constants.IconCategory.Tailoring, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "bandage" ), tags = { Constants.IconCategory.FirstAid } },
    { predicate = All ( Prefix "inv", Word "bolt" ), tags = { Constants.IconCategory.Tailoring, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "claw" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "crystal" ), tags = { Constants.IconCategory.Enchanting, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "dust" ), tags = { Constants.IconCategory.Enchanting, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "egg" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "elixir" ), tags = { Constants.IconCategory.Alchemy, Constants.IconCategory.Potion } },
    { predicate = All ( Prefix "inv", Word "essence" ), tags = { Constants.IconCategory.Enchanting, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "fabric" ), tags = { Constants.IconCategory.Inscription, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "feather" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "fish", Not ( Word "armor" ) ), tags = { Constants.IconCategory.Fishing, Constants.IconCategory.Food } },
    { predicate = All ( Prefix "inv", Word "gem" ), tags = { Constants.IconCategory.Jewelcrafting } },
    { predicate = All ( Prefix "inv", Word "glyph" ), tags = { Constants.IconCategory.Inscription } },
    { predicate = All ( Prefix "inv", Word "heart" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "herb" ), tags = { Constants.IconCategory.Herbalism, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "horn" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "ingot" ), tags = { Constants.IconCategory.Mining, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "ink" ), tags = { Constants.IconCategory.Inscription } },
    { predicate = All ( Prefix "inv", Word "mote" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "ore" ), tags = { Constants.IconCategory.Mining, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "potion" ), tags = { Constants.IconCategory.Alchemy, Constants.IconCategory.Potion } },
    { predicate = All ( Prefix "inv", Word "rod", Not ( Any ( Word "enchant", Word "enchanting" ) ) ), tags = { Constants.IconCategory.Fishing } },
    { predicate = All ( Prefix "inv", Word "rod", Not ( Word "fishing" ) ), tags = { Constants.IconCategory.Enchanting } },
    { predicate = All ( Prefix "inv", Word "scale" ), tags = { Constants.IconCategory.Leatherworking, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "scroll" ), tags = { Constants.IconCategory.Enchanting, Constants.IconCategory.Inscription } },
    { predicate = All ( Prefix "inv", Word "shard" ), tags = { Constants.IconCategory.Enchanting, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "stone" ), tags = { Constants.IconCategory.Mining, Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "tail" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "tooth" ), tags = { Constants.IconCategory.TradeGoods } },
    { predicate = All ( Prefix "inv", Word "vellum" ), tags = { Constants.IconCategory.Inscription } },
    { predicate = Substring "resourcelumber", tags = { Constants.IconCategory.TradeGoods } },
};

-- luacheck: pop

return Constants;
