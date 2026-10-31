local _, ns = ...

-- /fabrikao probe: a diagnostic for development. It checks, for each profession of the character, how many of
-- the data's recipes the client says are known (by each way of asking), and, when that profession's window is
-- open (the K window), compares the data with the window's own list. The result is printed and kept in the saved
-- variable FabrikaoDB.probe, to be read from the file after /reload.

local function bankPlayer()
    return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
end

local function viaIsSpellKnown(id)
    if not (C_SpellBook and C_SpellBook.IsSpellKnown) then return IsSpellKnown ~= nil and IsSpellKnown(id) and true or false end
    local ok, result = pcall(C_SpellBook.IsSpellKnown, id, bankPlayer())
    return ok and result and true or false
end

local function viaInSpellBook(id)
    if not (C_SpellBook and C_SpellBook.IsSpellInSpellBook) then return false end
    local ok, result = pcall(C_SpellBook.IsSpellInSpellBook, id, bankPlayer(), false)
    return ok and result and true or false
end

local function viaIsPlayerSpell(id)
    return IsPlayerSpell ~= nil and IsPlayerSpell(id) and true or false
end

function ns.Probe()
    local probe = {
        build = { GetBuildInfo() }, project = WOW_PROJECT_ID,
        api = {
            IsSpellKnown = C_SpellBook ~= nil and C_SpellBook.IsSpellKnown ~= nil,
            IsSpellInSpellBook = C_SpellBook ~= nil and C_SpellBook.IsSpellInSpellBook ~= nil,
            IsPlayerSpell = IsPlayerSpell ~= nil,
            GetSpellTexture = C_Spell ~= nil and C_Spell.GetSpellTexture ~= nil,
            GetItemNameByID = C_Item ~= nil and C_Item.GetItemNameByID ~= nil,
            GetAreaInfo = C_Map ~= nil and C_Map.GetAreaInfo ~= nil,
        },
        recipesInData = 0, professions = {},
    }
    for _ in ns.RecipeDB_Each() do probe.recipesInData = probe.recipesInData + 1 end

    if ns.IsClassic() then
        -- the old API: what the client has, the skill lines as the game lists them and what the windows gave
        local lines, unnamed, rows = ns.Classic_SkillLines()
        probe.classic = {
            flavor = ns.flavor, unnamedPrimary = unnamed, skillRows = rows, lines = {},
            api = {
                GetNumSkillLines = GetNumSkillLines ~= nil, GetNumTradeSkills = GetNumTradeSkills ~= nil, GetNumCrafts = GetNumCrafts ~= nil,
                GetTradeSkillRecipeLink = GetTradeSkillRecipeLink ~= nil, GetCraftItemLink = GetCraftItemLink ~= nil,
                IsSpellKnown = IsSpellKnown ~= nil, ExpandTradeSkillSubClass = ExpandTradeSkillSubClass ~= nil,
                C_TradeSkillUI = C_TradeSkillUI ~= nil, C_SpellBook = C_SpellBook ~= nil, GetProfessions = GetProfessions ~= nil,
            },
            tradeWindow = TradeSkillFrame ~= nil and TradeSkillFrame:IsShown() or false,
            craftWindow = CraftFrame ~= nil and CraftFrame:IsShown() or false,
            aliases = ns.db and ns.db.skillAliases or {},
        }
        for _, line in ipairs(lines) do
            probe.classic.lines[#probe.classic.lines + 1] = ("%s (%d): %d/%d"):format(line.name, line.skillLine, line.rank, line.maxRank)
        end
        ns.Print(("%s: %d skill rows, %d professions named, %d primary not named; trade window %s, craft window %s"):format(
            ns.flavor, rows, #lines, unnamed, probe.classic.tradeWindow and "open" or "closed", probe.classic.craftWindow and "open" or "closed"))
    end

    local open = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    probe.openWindow = open and { id = open.professionID, name = open.professionName, parent = open.parentProfessionID } or false
    probe.ready = C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() or false

    local list = ns.Professions_Mine()
    ns.Print(("%d professions, %d recipes in the data"):format(#list, probe.recipesInData))
    for _, profession in ipairs(list) do
        local entry = { name = profession.name, skillLine = profession.skillLine, rank = profession.rank, total = 0,
            isSpellKnown = 0, inSpellBook = 0, isPlayerSpell = 0, union = 0, sample = {} }
        for id, recipe in ns.RecipeDB_Each() do
            if recipe.s == profession.skillLine then
                entry.total = entry.total + 1
                local a, b, c = viaIsSpellKnown(id), viaInSpellBook(id), viaIsPlayerSpell(id)
                if a then entry.isSpellKnown = entry.isSpellKnown + 1 end
                if b then entry.inSpellBook = entry.inSpellBook + 1 end
                if c then entry.isPlayerSpell = entry.isPlayerSpell + 1 end
                if a or b or c then
                    entry.union = entry.union + 1
                    if #entry.sample < 5 then entry.sample[#entry.sample + 1] = recipe.n end
                end
            end
        end
        -- the game's own window, when it is open on this profession
        local live = ns.Recipes_Read(profession.skillLine, profession.name)
        if live then
            entry.live = { known = #live.known, unknown = #live.unknown, differences = {} }
            local fromData = ns.Recipes_FromData(profession.skillLine, profession.rank)
            local dataKnown = {}
            for _, r in ipairs(fromData.known) do dataKnown[r.id] = true end
            for _, r in ipairs(live.known) do
                if not dataKnown[r.id] and #entry.live.differences < 10 then
                    entry.live.differences[#entry.live.differences + 1] = r.name .. " (" .. r.id .. ") known in the window, not by the spell book"
                end
            end
        end
        if ns.IsClassic() then
            -- what the profession windows gave (the recipes saved as known) against what the client says by itself
            entry.saved = 0
            for id in pairs(FabrikaoCharDB and FabrikaoCharDB.knownRecipes or {}) do
                local recipe = ns.RecipeDB_Get(id)
                if recipe and recipe.s == profession.skillLine then entry.saved = entry.saved + 1 end
            end
        end
        probe.professions[#probe.professions + 1] = entry
        ns.Print(("%s: %d in the data; known by IsSpellKnown %d, InSpellBook %d, IsPlayerSpell %d%s"):format(
            entry.name, entry.total, entry.isSpellKnown, entry.inSpellBook, entry.isPlayerSpell,
            (entry.saved and (("; saved from the windows %d"):format(entry.saved)) or "")
            .. (entry.live and (("; the window lists %d known"):format(entry.live.known)) or "")))
    end
    FabrikaoDB.probe = probe
    ns.Print(ns.L["Probe finished. Type /reload to save it."])
end
