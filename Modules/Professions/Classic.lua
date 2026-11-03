local _, ns = ...

-- Professions and recipes on Classic Era and TBC Anniversary (ns.IsClassic()), where the game is not the retail engine Forever
-- runs on: no GetProfessions / C_TradeSkillUI / C_SpellBook. What there is instead:
--   * the professions are skill lines (GetNumSkillLines / GetSkillLineInfo), known by their name;
--   * the recipes a character knows are what its profession window lists (GetNumTradeSkills / GetTradeSkillInfo; Enchanting
--     and Poisons use the older "craft" window: GetNumCrafts / GetCraftInfo), a recipe being the spell id inside the link of
--     each line. A learned recipe is not in the spell book there, so the window is scanned whenever it shows and the ids are
--     kept in FabrikaoCharDB.knownRecipes (IsPlayerSpell / IsSpellKnown are still asked, in case the client answers for them);
--   * the profession's window opens by casting its spell, which only secure code may do: the Craft buttons get a secure
--     overlay (ns.Craft_Secure / ns.Craft_Prepare) and Craft.lua picks the recipe once the window is up.
-- None of it runs on Forever: every entry point is behind ns.IsClassic().

-- the spell that opens each profession's window (and so has its name), by skill line. Mining opens with Smelting.
local OPEN_SPELL = {
    [171] = 2259, [164] = 2018, [165] = 2108, [197] = 3908, [202] = 4036, [333] = 7411, [755] = 25229,
    [185] = 2550, [129] = 3273, [186] = 2656, [40] = 2842,
}
-- the profession's own spell, for the names of those that have no window
local NAME_SPELL = { [356] = 7620, [182] = 2366, [393] = 8613, [186] = 2575 }
-- the skill lines' names in English, to start from when the client's spells don't say
local ENGLISH = {
    [171] = "Alchemy", [164] = "Blacksmithing", [165] = "Leatherworking", [197] = "Tailoring", [202] = "Engineering",
    [333] = "Enchanting", [755] = "Jewelcrafting", [185] = "Cooking", [129] = "First Aid", [186] = "Mining",
    [356] = "Fishing", [182] = "Herbalism", [393] = "Skinning", [40] = "Poisons",
}
-- the windows that are not the trade skill one
local CRAFT_WINDOW = { [333] = true, [40] = true }

-- the name of a spell in the player's language (the older global, or C_Spell on the clients that dropped it)
local function spellName(id)
    if not id then return nil end
    local name
    if GetSpellInfo then
        name = GetSpellInfo(id)
    elseif C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        name = info and info.name
    end
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function aliases()
    return ns.db and ns.db.skillAliases or {}
end

-- The skill line a name stands for: its English name, the name of its spell, or one learned from a window (the game does not
-- always call the skill line what it calls the spell).
local function skillOf(name)
    local key = name and name:lower()
    if not key then return nil end
    if aliases()[key] then return aliases()[key] end
    for skill, english in pairs(ENGLISH) do
        if english:lower() == key then return skill end
    end
    for skill, spell in pairs(OPEN_SPELL) do
        local localized = spellName(spell)
        if localized and localized:lower() == key then return skill end
    end
    for skill, spell in pairs(NAME_SPELL) do
        local localized = spellName(spell)
        if localized and localized:lower() == key then return skill end
    end
    return nil
end

-- The profession's name in the player's language (nil when the client doesn't tell it).
function ns.Classic_SkillName(skill)
    local spell = NAME_SPELL[skill] or OPEN_SPELL[skill]
    return spellName(spell)
end

-- The icon of the profession (its spell's).
function ns.Classic_SkillIcon(skill)
    local spell = OPEN_SPELL[skill] or NAME_SPELL[skill]
    return spell and GetSpellTexture and GetSpellTexture(spell) or nil
end

---------------------------------------------------------------------------------------------------
-- The character's professions
---------------------------------------------------------------------------------------------------
-- The skill lines the game's skills list has that are professions of the data: { { name =, skillLine =, rank =, maxRank = }, ... }.
-- The list is folded by headers (a folded one hides its skills), so any folded header is opened; it is left open (closing it again
-- would fire SKILL_LINES_CHANGED and start the roster saving over and over). Also tells how many primary professions it could not
-- name (a player's language the names don't cover), and whether the list was there at all.
function ns.Classic_SkillLines()
    local out, unnamed, rows = {}, 0, 0
    if not (GetNumSkillLines and GetSkillLineInfo) then return out, unnamed, rows end
    if ExpandSkillHeader then
        for _ = 1, 30 do
            local folded
            for i = 1, GetNumSkillLines() do
                local _, header, expanded = GetSkillLineInfo(i)
                if header and not expanded then folded = i break end
            end
            if not folded then break end
            ExpandSkillHeader(folded)
        end
    end
    for i = 1, GetNumSkillLines() do
        local name, header, _, rank, _, _, maxRank, abandonable = GetSkillLineInfo(i)
        if name and not header then
            rows = rows + 1
            local skill = skillOf(name)
            if skill then
                out[#out + 1] = { name = name, skillLine = skill, rank = rank or 0, maxRank = maxRank or 0 }
            elseif abandonable then
                unnamed = unnamed + 1
            end
        end
    end
    return out, unnamed, rows
end

---------------------------------------------------------------------------------------------------
-- Recipes the character knows
---------------------------------------------------------------------------------------------------
local function store()
    if not FabrikaoCharDB then return nil end
    FabrikaoCharDB.knownRecipes = FabrikaoCharDB.knownRecipes or {}
    return FabrikaoCharDB.knownRecipes
end

-- Does the character know the recipe (a spell id of the data)?
function ns.Classic_Known(spellID)
    local saved = FabrikaoCharDB and FabrikaoCharDB.knownRecipes
    if saved and saved[spellID] then return true end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    return false
end

-- The recipes of a profession the character dropped are no longer known: forget them. Only when every primary profession in the
-- skills list was named, so a name the addon doesn't know never costs anyone their recipes.
function ns.Classic_Prune(have, unnamed, rows)
    local saved = FabrikaoCharDB and FabrikaoCharDB.knownRecipes
    if not saved or unnamed > 0 or rows == 0 then return end
    local present = {}
    for _, p in ipairs(have) do present[p.skillLine] = true end
    for id in pairs(saved) do
        local recipe = ns.RecipeDB_Get(id)
        if not recipe or (not present[recipe.s] and recipe.s ~= 40) then saved[id] = nil end
    end
end

-- the spell id of a recipe link ("|Henchant:3101|h[...]|h")
local function spellOf(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("enchant:(%d+)")) or tonumber(link:match("spell:(%d+)"))
end

-- The two windows, as the same few questions: how many lines, what is line i ({ name, kind, expanded }) and which spell it makes.
local WINDOWS = {
    trade = {
        count = function() return GetNumTradeSkills and GetNumTradeSkills() or 0 end,
        info = function(i)
            local name, kind, _, expanded = GetTradeSkillInfo(i)
            return name, kind, expanded
        end,
        spell = function(i)
            return spellOf(GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)) or spellOf(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
        end,
        expand = function(i) if ExpandTradeSkillSubClass then ExpandTradeSkillSubClass(i) end end,
        collapse = function(i) if CollapseTradeSkillSubClass then CollapseTradeSkillSubClass(i) end end,
        line = function() return GetTradeSkillLine and GetTradeSkillLine() end,
        frame = "TradeSkillFrame", select = "TradeSkillFrame_SetSelection", update = "TradeSkillFrame_Update",
    },
    craft = {
        count = function() return GetNumCrafts and GetNumCrafts() or 0 end,
        info = function(i)
            local name, _, kind, _, expanded = GetCraftInfo(i)
            return name, kind, expanded
        end,
        spell = function(i)
            return spellOf(GetCraftItemLink and GetCraftItemLink(i)) or spellOf(GetCraftRecipeLink and GetCraftRecipeLink(i))
        end,
        expand = function(i) if ExpandCraftSkillLine then ExpandCraftSkillLine(i) end end,
        collapse = function(i) if CollapseCraftSkillLine then CollapseCraftSkillLine(i) end end,
        line = function() return GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() end,
        frame = "CraftFrame", select = "CraftFrame_SetSelection", update = "CraftFrame_Update",
    },
}

local scanning, quietUntil = false, 0

local function now()
    return GetTime and GetTime() or 0
end

-- Opens the folded headers of the window, runs `fn`, and folds them again as they were (the player may have folded them on purpose).
-- The events that opening and folding fire are ignored for a moment: `quietUntil`.
local function withOpened(window, fn)
    local opened = {}
    for _ = 1, 30 do
        local folded
        for i = 1, window.count() do
            local name, kind, expanded = window.info(i)
            if (kind == "header" or kind == "subheader") and not expanded then folded = { i, name } break end
        end
        if not folded then break end
        window.expand(folded[1])
        opened[#opened + 1] = folded[2]
    end
    local result = fn()
    for n = #opened, 1, -1 do
        for i = 1, window.count() do
            local name, kind, expanded = window.info(i)
            if (kind == "header" or kind == "subheader") and expanded and name == opened[n] then window.collapse(i) break end
        end
    end
    if #opened > 0 then quietUntil = now() + 2 end
    return result
end

local LEARNED = { optimal = true, medium = true, easy = true, trivial = true, used = true }

-- The recipes the open window lists (spell ids of the data) and the name it gives its profession.
local function readWindow(window)
    local ids, skills = {}, {}
    withOpened(window, function()
        for i = 1, window.count() do
            local name, kind = window.info(i)
            if name and LEARNED[kind] then
                local spell = window.spell(i)
                local recipe = spell and ns.RecipeDB_Get(spell)
                if recipe then
                    ids[#ids + 1] = spell
                    skills[recipe.s] = (skills[recipe.s] or 0) + 1
                end
            end
        end
    end)
    local lineName = window.line()
    return ids, lineName, skills
end

-- The skill line most of the recipes belong to.
local function majority(skills)
    local best, count = nil, 0
    for skill, n in pairs(skills) do
        if n > count then best, count = skill, n end
    end
    return best
end

-- Reads whichever of the two windows is open and remembers the recipes in it. Returns how many were new.
function ns.Classic_Scan()
    local saved = store()
    if not saved or scanning then return 0 end
    scanning = true
    local added = 0
    for _, key in ipairs({ "trade", "craft" }) do
        local window = WINDOWS[key]
        local frame = _G[window.frame]
        if frame and (not frame.IsShown or frame:IsShown()) then
            local ok, ids, lineName, skills = pcall(readWindow, window)
            if ok then
                for _, id in ipairs(ids) do
                    if not saved[id] then saved[id] = true; added = added + 1 end
                end
                -- a name the game gives the profession that the addon did not know: remember it
                local skill = majority(skills)
                if skill and lineName and ns.db and not skillOf(lineName) then
                    ns.db.skillAliases = ns.db.skillAliases or {}
                    ns.db.skillAliases[lineName:lower()] = skill
                end
            end
        end
    end
    scanning = false
    if added > 0 then
        if ns.Roster_Snapshot then ns.Roster_Snapshot(false) end
        if ns.UI_Refresh then ns.UI_Refresh() end
    end
    return added
end

---------------------------------------------------------------------------------------------------
-- When to scan
---------------------------------------------------------------------------------------------------
local pending = false
local function schedule()
    if pending or now() < quietUntil then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        ns.Classic_Scan()
    end)
end

---------------------------------------------------------------------------------------------------
-- Recipes learned
---------------------------------------------------------------------------------------------------
-- The game tells in chat ("You have learned how to create a new item: [Beer Basted Boar Ribs]") when a recipe is learned, and these clients
-- have no event of their own for it, so the message is read: the link in it names the spell, or the item it makes, or just the recipe.
local function messagePattern(format)
    if type(format) ~= "string" then return nil end
    local escaped = format:gsub("%%s", "\1"):gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", "(.+)")
    return "^" .. escaped .. "$"
end

-- Marks as known the recipe a "learned" chat message names. Returns the spell id, or nil when the message is not about a recipe of the data.
function ns.Classic_Learned(text)
    if type(text) ~= "string" then return nil end
    local what
    for _, name in ipairs({ "ERR_LEARN_RECIPE_S", "ERR_LEARN_SPELL_S" }) do
        local pattern = messagePattern(_G[name])
        what = pattern and text:match(pattern)
        if what then break end
    end
    if not what then return nil end
    local spell = tonumber(what:match("spell:(%d+)") or what:match("enchant:(%d+)"))
    if not (spell and ns.RecipeDB_Get(spell)) then
        spell = nil
        local item = tonumber(what:match("item:(%d+)"))
        local name = what:match("%[(.-)%]") or what
        -- (the item it makes, or its name; a recipe of a profession the character does not have is not the one)
        local mine = {}
        for _, line in ipairs(ns.Classic_SkillLines()) do mine[line.skillLine] = true end
        for id, recipe in ns.RecipeDB_Each() do
            if (mine[recipe.s] or recipe.s == 40) and ((item and recipe.p and recipe.p[1] == item) or recipe.n == name) then
                spell = id
                break
            end
        end
    end
    local saved = store()
    if not (spell and saved) then return nil end
    saved[spell] = true
    return spell
end

local learnPending = false
-- Soon, and once for a burst: the recipes now known are saved and the window draws them.
local function afterLearning()
    if learnPending then return end
    learnPending = true
    C_Timer.After(0.5, function()
        learnPending = false
        if ns.Roster_Snapshot then ns.Roster_Snapshot(false) end
        if ns.UI_Refresh then ns.UI_Refresh() end
    end)
end

local started = false
-- Starts listening for the windows (the events don't exist on Forever, which never gets here).
function ns.Classic_Start()
    if started then return end
    started = true
    local frame = CreateFrame("Frame")
    local events = { "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "CHAT_MSG_SYSTEM", "TRAINER_UPDATE", "SKILL_LINES_CHANGED" }
    for _, event in ipairs(events) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, text)
        if not ns.IsClassic() then return end
        if event == "CHAT_MSG_SYSTEM" then
            if ns.Classic_Learned(text) then afterLearning() end
        elseif event == "TRAINER_UPDATE" or event == "SKILL_LINES_CHANGED" then
            afterLearning() -- (a recipe bought from a trainer; a skill that went up)
        else
            schedule()
        end
    end)
end
if ns.IsClassic and ns.IsClassic() then ns.Classic_Start() end

---------------------------------------------------------------------------------------------------
-- Opening the window on a recipe
---------------------------------------------------------------------------------------------------
-- The name of the spell that opens the profession's window.
local function openSpellName(skill)
    return spellName(OPEN_SPELL[skill]) or (skill ~= 186 and ENGLISH[skill]) or (skill == 186 and "Smelting") or nil -- (English: better than nothing)
end

-- Selects the recipe in the window that is open. False when no window shows it.
function ns.Classic_Select(recipeID)
    for _, key in ipairs({ "trade", "craft" }) do
        local window = WINDOWS[key]
        local frame = _G[window.frame]
        if frame and (not frame.IsShown or frame:IsShown()) then
            for i = 1, window.count() do
                local name, kind = window.info(i)
                if name and LEARNED[kind] and window.spell(i) == recipeID then
                    local pick, update = _G[window.select], _G[window.update]
                    if pick then pick(i) end
                    if update then update() end
                    return true
                end
            end
        end
    end
    return false
end

-- Is the window of that profession the one open (by the name it gives it, or because it lists the recipe)?
local function windowOpenFor(skill, recipeID)
    for _, key in ipairs({ "trade", "craft" }) do
        local window = WINDOWS[key]
        local frame = _G[window.frame]
        if frame and (not frame.IsShown or frame:IsShown()) then
            local lineName = window.line()
            if lineName and skillOf(lineName) == skill then return true end
            for i = 1, window.count() do
                local name, kind = window.info(i)
                if name and LEARNED[kind] and window.spell(i) == recipeID then return true end
            end
        end
    end
    return false
end

-- Puts a transparent secure button over `button` that casts the profession's spell (which opens its window) and then asks
-- Craft.lua to pick the recipe. It does nothing until ns.Craft_Prepare tells it what to open. Only on the classic clients.
function ns.Craft_Secure(button)
    if not ns.IsClassic() then return nil end
    if button.secure then return button.secure end
    local secure = CreateFrame("Button", nil, button, "SecureActionButtonTemplate")
    secure:SetAllPoints(button)
    secure:SetFrameLevel(button:GetFrameLevel() + 5)
    -- (the game fires a secure button on the key down or the key up by a setting, and only for the ones the button is registered for)
    secure:RegisterForClicks("AnyUp", "AnyDown")
    secure:SetAttribute("type", "spell")
    secure:SetScript("OnEnter", function()
        local onEnter = button:GetScript("OnEnter")
        if onEnter then onEnter(button) end
    end)
    secure:SetScript("OnLeave", function()
        local onLeave = button:GetScript("OnLeave")
        if onLeave then onLeave(button) end
    end)
    -- casting the spell while its window is open closes it: then the click only picks the recipe (out of combat: the attribute is locked in it)
    secure:SetScript("PreClick", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        local open = self.recipeID and windowOpenFor(self.skillLine, self.recipeID)
        self:SetAttribute("type", not open and "spell" or nil)
    end)
    secure:SetScript("PostClick", function(self, _, down)
        -- once per click: on the half the game acts on
        local onDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") and true or false
        if down ~= nil and (down and true or false) ~= onDown then return end
        local recipeID, skill = self.recipeID, self.skillLine
        if recipeID then C_Timer.After(0.3, function() ns.Craft_Open(recipeID, skill) end) end
    end)
    secure:Hide()
    button.secure = secure
    return secure
end

-- What a click on the button's secure overlay opens: the window of the recipe's profession (changed out of combat only: the game
-- locks the attributes of secure buttons in combat).
function ns.Craft_Prepare(button, recipeID, skillLine)
    local secure = button and button.secure
    if not secure then return end
    secure.recipeID, secure.skillLine = recipeID, skillLine
    if InCombatLockdown and InCombatLockdown() then return end
    local spell = recipeID and openSpellName(skillLine)
    secure:SetAttribute("spell", spell)
    if spell then secure:Show() else secure:Hide() end
end

-- is that profession's window one of the "craft" kind (Enchanting, Poisons)?
function ns.Classic_IsCraftWindow(skill)
    return CRAFT_WINDOW[skill] == true
end
