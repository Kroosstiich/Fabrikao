local _, ns = ...

-- The professions the character has, in the order the window shows them: the primary ones first (as the
-- game lists them), then First Aid, Cooking and Fishing. Forever uses the retail profession API:
-- GetProfessions() / GetProfessionInfo() for the list, C_TradeSkillUI for everything about recipes. Classic Era and TBC Anniversary have
-- the old one instead (skill lines and the profession windows): Classic.lua.

-- skill lines of the secondary professions, in display order
local SECONDARY = { [129] = 1, [185] = 2, [356] = 3 } -- First Aid, Cooking, Fishing
local ARCHAEOLOGY = 794 -- never has recipes
local QUESTION_MARK = 134400

-- Colors of the difficulty of a recipe, as the game's trade skill windows draw them. The keys are
-- Enum.TradeskillRelativeDifficulty: 0 optimal (orange), 1 medium (yellow), 2 easy (green), 3 trivial (grey).
ns.DIFFICULTY_COLORS = {
    [0] = { 1, 0.5, 0.25 },
    [1] = { 1, 1, 0 },
    [2] = { 0.25, 0.75, 0.25 },
    [3] = { 0.5, 0.5, 0.5 },
}
ns.DIFFICULTY_LAST = 3

-- The four skill levels of a recipe (orange, yellow, green, grey), each in its color; "-" for a color the recipe skips.
function ns.DifficultyColorsText(colors)
    local out = {}
    for i, level in ipairs(colors) do
        local c = ns.DIFFICULTY_COLORS[i - 1]
        local shown = (level > 0 or i == 1) and tostring(level) or "-"
        out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), shown)
    end
    return table.concat(out, "  ")
end

-- GetProfessions() returns nil for the slots the character doesn't have, so the values can't go through ipairs.
local function pack(...)
    return { ... }, select("#", ...)
end

-- Whether the profession has a crafting window at all (Herbalism, Skinning and Fishing don't): the game asks
-- it with the profession's own spell, the first one of its spell book entries.
local function hasRecipes(spellOffset)
    if not (spellOffset and C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_TradeSkillUI
            and C_TradeSkillUI.CanTradeSkillShowCraftingUI and Enum and Enum.SpellBookSpellBank) then
        return true -- can't tell: let it try
    end
    local info = C_SpellBook.GetSpellBookItemInfo(spellOffset + 1, Enum.SpellBookSpellBank.Player)
    if not (info and info.spellID) then return false end
    return C_TradeSkillUI.CanTradeSkillShowCraftingUI(info.spellID) and true or false
end

-- Poisons, the rogue's class skill (40): the game's list of professions does not have it, it is a spell (2842) a rogue learns at level 20,
-- and its skill goes up five a level (to 300). Only a rogue has it.
local POISONS, POISONS_SPELL, ROGUE = 40, 2842, "ROGUE"

local function playerClass()
    return UnitClass and select(2, UnitClass("player")) or nil
end

local function poisonsName()
    return ns.RecipeDB_SkillName and ns.RecipeDB_SkillName(POISONS) or "Poisons"
end

local function knowsSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    end
    return IsPlayerSpell ~= nil and IsPlayerSpell(id) and true or false
end

local function poisonsIcon()
    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(POISONS_SPELL)
    return texture or (GetSpellTexture and GetSpellTexture(POISONS_SPELL)) or "Interface\\Icons\\Ability_Poisons"
end

-- the skill and its maximum: the game's own numbers when it has them (its profession info, or the older list of skills), else five a level
local function poisonsSkill()
    local info = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(POISONS)
    if info and (info.skillLevel or 0) > 0 then return info.skillLevel, info.maxSkillLevel or 300 end
    if GetNumSkillLines and GetSkillLineInfo then
        local name = ns.RecipeDB_SkillName and ns.RecipeDB_SkillName(POISONS)
        for i = 1, GetNumSkillLines() do
            local skillName, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if not header and skillName == name and (rank or 0) > 0 then return rank, maxRank or 300 end
        end
    end
    local level = UnitLevel and UnitLevel("player") or 0
    return math.min(300, level * 5), 300
end

-- Forever: the list the game gives (GetProfessions).
local function foreverList()
    local list = {}
    if not (GetProfessions and GetProfessionInfo) then return list end
    local indexes, count = pack(GetProfessions())
    for i = 1, count do
        local index = indexes[i]
        if index then
            local name, icon, rank, maxRank, _, spellOffset, skillLine = GetProfessionInfo(index)
            if name and skillLine ~= ARCHAEOLOGY then
                -- (the game lists Poisons for a rogue in some clients: its own entry is the one, by the number of the skill the data uses)
                if name == poisonsName() then skillLine = POISONS end
                list[#list + 1] = {
                    name = name, icon = icon, rank = rank or 0, maxRank = maxRank or 0, skillLine = skillLine,
                    primary = not SECONDARY[skillLine], hasRecipes = hasRecipes(spellOffset),
                    order = #list + 1,
                }
            end
        end
    end
    return list
end

-- Classic Era and TBC Anniversary: the skill lines of the character that are professions (Classic.lua). Herbalism, Skinning and Fishing
-- are listed but have no recipes.
local function classicList()
    local list = {}
    local lines, unnamed, rows = ns.Classic_SkillLines()
    local withRecipes = {}
    for _, skill in ipairs(ns.RecipeDB_Skills and ns.RecipeDB_Skills() or {}) do withRecipes[skill] = true end
    for _, line in ipairs(lines) do
        list[#list + 1] = {
            name = line.name, icon = ns.Classic_SkillIcon(line.skillLine) or QUESTION_MARK, rank = line.rank, maxRank = line.maxRank,
            skillLine = line.skillLine, primary = not SECONDARY[line.skillLine], hasRecipes = withRecipes[line.skillLine] == true,
            order = #list + 1,
        }
    end
    ns.Classic_Prune(list, unnamed, rows)
    return list
end

-- The professions the playing character has: { { name =, icon =, rank =, maxRank =, skillLine =, primary =, hasRecipes = }, ... }
function ns.Professions_Mine()
    local list = ns.IsClassic() and classicList() or foreverList()
    local listed = false
    for _, p in ipairs(list) do
        if p.skillLine == POISONS then listed = true end
    end
    if not listed and playerClass() == ROGUE and knowsSpell(POISONS_SPELL) then
        local rank, maxRank = poisonsSkill()
        list[#list + 1] = {
            name = poisonsName(), icon = poisonsIcon(), rank = rank, maxRank = maxRank,
            -- listed with the main skills, after the primary professions and before First Aid, Cooking and Fishing
            skillLine = POISONS, primary = true, hasRecipes = true, order = #list + 1,
        }
    end
    table.sort(list, function(a, b)
        if a.primary ~= b.primary then return a.primary end
        if not a.primary then
            local oa, ob = SECONDARY[a.skillLine] or 99, SECONDARY[b.skillLine] or 99
            if oa ~= ob then return oa < ob end
        end
        return a.order < b.order
    end)
    return list
end

-- The ranks of a profession: each one caps the skill at a multiple of 75 (the rank that ends at 150 is Journeyman...), and a character
-- trains the next one once its skill is 25 short of the current cap (Journeyman asks for 50 of the 75, Expert 125 of 150...) and it is the
-- level the rank asks for: it does not have to wait for the cap.
local RANK_NAMES = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan", [375] = "Master", [450] = "Grand Master" }
local RANK_LEVEL = { [150] = 10, [225] = 20, [300] = 35, [375] = 50, [450] = 65 } -- the level to train the rank that ends there
local RANK_STEP = 75
local RANK_SKILL_MARGIN = 25 -- how far under its cap the skill may be to train the next rank

-- The rank a character can train now in the profession, or nil: its skill is within RANK_SKILL_MARGIN of the cap of its rank, a higher
-- rank exists in this game (the data has recipes that ask for more skill) and its level allows it. `profession` is an entry of ns.Professions_List
-- (`charLevel` is the character's level when it is another one's: false when its copy has none; without it, the playing one's is used).
-- Returns the rank's name (as the game calls it) and the skill it ends at.
function ns.Professions_NextRank(profession)
    if not (profession and profession.learned ~= false and profession.rank and profession.maxRank and profession.maxRank > 0) then return nil end
    if profession.rank < profession.maxRank - RANK_SKILL_MARGIN then return nil end
    local cap = profession.maxRank + RANK_STEP
    local name = RANK_NAMES[cap]
    if not name then return nil end
    if not (ns.RecipeDB_MaxSkill and ns.RecipeDB_MaxSkill() > profession.maxRank) then return nil end
    local need = RANK_LEVEL[cap]
    local level = profession.charLevel
    if level == nil then level = UnitLevel and UnitLevel("player") end
    if need and not (level and level >= need) then return nil end
    return ns.L[name], cap
end

-- What the window tells of a profession beside it, in green: the rank a trainer can teach ("Can train: Expert") or, for Poisons --whose
-- "recipes" are abilities that a rogue's trainer teaches--, how many of them can be learned now ("Can learn: 3"). Nil when nothing.
function ns.Professions_Notice(profession)
    local rank = ns.Professions_NextRank(profession)
    if rank then return ns.L["Can train: %s"]:format(rank) end
    if profession and profession.skillLine == POISONS and profession.learned ~= false and profession.rank and ns.Recipes_LearnableNow then
        local group = ns.Recipes_LearnableNow({ profession })[1]
        if group and group.total > 0 then return ns.L["Can learn: %d"]:format(group.total) end
    end
    return nil
end

-- The professions of the character the window shows: the playing one's, or another character's saved copy (Roster.lua).
function ns.Professions_List()
    return ns.Roster_ViewedProfessions and ns.Roster_ViewedProfessions() or ns.Professions_Mine()
end

-- icons of the professions the character may not have (the game's own when any character saved one, else these)
local ICONS = {
    [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing", [333] = "Interface\\Icons\\Trade_Engraving",
    [202] = "Interface\\Icons\\Trade_Engineering", [165] = "Interface\\Icons\\INV_Misc_ArmorKit_17", [197] = "Interface\\Icons\\Trade_Tailoring",
    [186] = "Interface\\Icons\\Trade_Mining", [755] = "Interface\\Icons\\INV_Misc_Gem_01", [185] = "Interface\\Icons\\INV_Misc_Food_15",
    [129] = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
}

-- The professions with recipes in the data that `have` (a list as ns.Professions_List returns) lacks, in the data's order:
-- { { name =, icon =, skillLine =, primary =, hasRecipes = true, learned = false }, ... } (no rank: it isn't learned).
function ns.Professions_Missing(have)
    local owned = {}
    for _, p in ipairs(have) do owned[p.skillLine] = true end
    local viewed = ns.Roster_Viewed and ns.Roster_Viewed()
    local isRogue = (viewed and viewed.class or playerClass()) == ROGUE
    local list = {}
    for _, skill in ipairs(ns.RecipeDB_Skills and ns.RecipeDB_Skills() or {}) do
        if not owned[skill] and (skill ~= POISONS or isRogue) then
            list[#list + 1] = {
                name = ns.RecipeDB_SkillName(skill), skillLine = skill, hasRecipes = true, learned = false,
                icon = (ns.Roster_Icon and ns.Roster_Icon(skill)) or (skill == POISONS and poisonsIcon()) or ICONS[skill] or QUESTION_MARK,
                primary = not SECONDARY[skill],
            }
        end
    end
    return list
end

function ns.Professions_Get(skillLine)
    for _, profession in ipairs(ns.Professions_List()) do
        if profession.skillLine == skillLine then return profession end
    end
end
