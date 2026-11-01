local _, ns = ...

-- Recipes of a profession for the window's lists. The list comes from the addon's own data (every recipe of the
-- profession) and "known" from the spell book, so it needs no trade skill window. When the player happens to
-- have that profession's window open, its live answer (C_TradeSkillUI) is used instead, which also knows what
-- the data doesn't. Everything works on plain tables: the list, the search and the "how many can I make"
-- counts (from the bags).

local BASIC_REAGENT = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

local cache = {} -- skill line -> last copy

local function openSkillLine()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo) then return nil end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and (info.parentProfessionID or info.professionID)
    if not id or id == 0 then return nil end
    return id
end

-- is that profession's window the one open and ready? (by skill line, or by name should the game number its lines differently)
local function isReady(skillLine, name)
    if ns.IsClassic() then return false end -- (the lists come from the data there; Classic.lua reads the windows for what is known)
    if not (C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady()) then return false end
    if openSkillLine() == skillLine then return true end
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return name ~= nil and info ~= nil and (info.professionName == name or info.parentProfessionName == name)
end

-- Is that profession open and ready in the game's profession window? (for crafting, Craft.lua)
function ns.Recipes_IsReady(skillLine, name)
    return isReady(skillLine, name)
end

-- What a recipe needs of each basic ingredient: { { items = { itemID, ... }, quantity = n }, ... }. Several
-- items in one slot are alternatives (the same ingredient in other qualities).
local function readReagents(recipeID)
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schematic) ~= "table" then return nil end
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.reagentType == BASIC_REAGENT and (slot.quantityRequired or 0) > 0 then
            local items = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                if reagent.itemID then items[#items + 1] = reagent.itemID end
            end
            if #items > 0 then reagents[#reagents + 1] = { items = items, quantity = slot.quantityRequired } end
        end
    end
    return reagents
end

-- The ingredients of a recipe of the data, as Recipes_Craftable reads them.
local function reagentsOfData(db)
    local reagents = {}
    for _, reagent in ipairs(db.m or {}) do reagents[#reagents + 1] = { items = { reagent[1] }, quantity = reagent[2] } end
    return reagents
end

local function byName(a, b) return a.name < b.name end

-- Known recipes by difficulty (orange first), then by name; the unknown ones by the skill they need (or, without
-- that, when they turn grey), then name.
local function sortKnown(a, b)
    local da, db = a.difficulty or ns.DIFFICULTY_LAST, b.difficulty or ns.DIFFICULTY_LAST
    if da ~= db then return da < db end
    return byName(a, b)
end
local function sortUnknown(a, b)
    local sa, sb = a.required or a.trivial or 0, b.required or b.trivial or 0
    if sa ~= sb then return sa < sb end
    return byName(a, b)
end

-- Copies the open profession's recipes (known and not known) into a table, or nil when `skillLine` isn't the
-- one open. { skillLine =, known = { recipe, ... }, unknown = { recipe, ... }, sources = { [sourceType] = true },
-- categories = { [category name] = true } }
-- recipe: { id, name, icon, link, learned, difficulty (0 orange .. 3 grey, known ones only), trivial (the skill
-- at which it turns grey), sourceType, category (what it makes: hands, bags, potions...), sourceText (not known ones), reagents (known ones) }
function ns.Recipes_Read(skillLine, name)
    if not isReady(skillLine, name) then return nil end
    local T = C_TradeSkillUI
    -- the lists in the game's window are filtered: ask for everything, and give its filters back
    local wasLearned = T.GetShowLearned and T.GetShowLearned()
    local wasUnlearned = T.GetShowUnlearned and T.GetShowUnlearned()
    if T.SetShowLearned then T.SetShowLearned(true) end
    if T.SetShowUnlearned then T.SetShowUnlearned(true) end

    local copy = { skillLine = skillLine, known = {}, unknown = {}, sources = {}, categories = {} }
    local seen = {}
    for _, id in ipairs(T.GetFilteredRecipeIDs and T.GetFilteredRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(id)
        -- a recipe with several ranks is one entry: the first rank
        if info and info.name and not info.previousRecipeID and not seen[info.recipeID or id]
                and (name or not T.IsRecipeInSkillLine or T.IsRecipeInSkillLine(id, skillLine)) then
            seen[info.recipeID or id] = true
            local recipe = {
                id = info.recipeID or id, name = info.name, icon = info.icon, link = info.hyperlink,
                learned = info.learned and true or false, trivial = info.maxTrivialLevel,
            }
            -- what the addon's own data knows about it: skill levels and where it is learned
            local db = ns.RecipeDB_Get and ns.RecipeDB_Get(recipe.id)
            if db then
                recipe.db = db
                recipe.required = ns.RecipeDB_Required(db)
                recipe.colors = ns.RecipeDB_Colors(db)
                recipe.search = ns.RecipeDB_SearchText(recipe.id)
                recipe.sourceType = ns.RecipeDB_Sources(db)[1]
                recipe.category = ns.RecipeDB_Category(db)
                recipe.reagents = reagentsOfData(db)
            end
            if recipe.sourceType then copy.sources[recipe.sourceType] = true end
            if recipe.category then copy.categories[recipe.category] = true end
            if recipe.learned then
                recipe.difficulty = info.relativeDifficulty
                recipe.reagents = readReagents(recipe.id) or recipe.reagents
                copy.known[#copy.known + 1] = recipe
            else
                if T.GetRecipeSourceText then recipe.sourceText = T.GetRecipeSourceText(recipe.id) end
                copy.unknown[#copy.unknown + 1] = recipe
            end
        end
    end
    table.sort(copy.known, sortKnown)
    table.sort(copy.unknown, sortUnknown)

    if wasLearned ~= nil and T.SetShowLearned then T.SetShowLearned(wasLearned) end
    if wasUnlearned ~= nil and T.SetShowUnlearned then T.SetShowUnlearned(wasUnlearned) end
    cache[skillLine] = copy
    return copy
end

-- The last copy read of a profession (this session), whether its window is open or not.
function ns.Recipes_Cached(skillLine)
    if ns.Roster_ViewKey and ns.Roster_ViewKey() then return nil end -- the copies are the playing character's
    return cache[skillLine]
end

-- How many times the character can craft the recipe with what is in the bags; with `alts`, with everything the account has
-- (its own bank and the bags and banks of the other characters, from Embolsao's copies).
function ns.Recipes_Craftable(recipe, alts)
    if not recipe.reagents or #recipe.reagents == 0 then return 0 end
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    local most
    for _, reagent in ipairs(recipe.reagents) do
        local have = 0
        for _, itemID in ipairs(reagent.items) do
            have = have + (ns.Inventory_Count and ns.Inventory_Count(itemID, alts) or count(itemID) or 0)
        end
        local times = math.floor(have / reagent.quantity)
        most = most and math.min(most, times) or times
    end
    return most or 0
end

-- Name of a recipe source code (trainer, vendor, drop, quest...).
function ns.Recipes_SourceLabel(sourceType)
    return sourceType and ns.RecipeDB_SourceName(sourceType) or ns.L["Other"]
end

-- Sort keys of the lists: the value each row is compared by (nil goes last).
local SORT_VALUE = {
    name = function(row) return row.recipe.name end,
    level = function(row) return row.recipe.required end,
    cost = function(row) return row.cost end,
    value = function(row) return row.value end,
    craftable = function(row) return row.craftable end,
}

local function sortRows(group, sort)
    local value = SORT_VALUE[sort.key]
    if not value then return end
    table.sort(group, function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then
            if va == nil then return false end
            if vb == nil then return true end
            if sort.desc then return va > vb end
            return va < vb
        end
        return a.recipe.name < b.recipe.name
    end)
end

-- The rows of the recipe list for the current search and filters: { kind = "header", text = } and
-- { kind = "recipe", recipe =, craftable =, cost =, incomplete =, value = }.
-- opts: { text =, known = bool, unknown = bool,
--   source = a source code (the recipes learned that way), category = a category name (what the recipe makes),
--   difficulty = 0..3 (orange .. grey, for the character's skill),
--   canMake = only what the bags allow (with alts = true: what the whole account allows), hideGrey = hide what gives no skill points,
--   skill = "learnable" (not known, skill enough to learn) or "higher" (not known, needs more skill),
--   sort = { key = name | level | cost | value | craftable, desc = bool } (nil: the list's own order),
--   collapsed = { known = bool, unknown = bool } (a group collapsed keeps its header, with the count, and no rows),
--   flat = true: just the rows of the recipes of copy.all (any mix of professions), no groups and no titles }
-- Each recipe has its own `rank` (the character's skill in its profession), else the copy's.
-- The header rows carry their group ("known" or "unknown") and whether it is collapsed.
function ns.Recipes_Rows(copy, opts)
    local rows = {}
    local text = strtrim((opts.text or ""):lower())
    local function matches(recipe)
        if text == "" then return true end
        if recipe.name:lower():find(text, 1, true) then return true end
        if recipe.sourceText and recipe.sourceText:lower():find(text, 1, true) then return true end
        return recipe.search and recipe.search:find(text, 1, true) and true or false
    end

    -- how the recipe looks for the character's skill (0 orange .. 3 grey), nil when it needs more skill than it has
    local function difficultyOf(recipe)
        local rank = recipe.rank or copy.rank
        if recipe.learned then return recipe.difficulty or ns.DIFFICULTY_LAST end
        if recipe.db and rank and recipe.required and recipe.required <= rank then
            return ns.RecipeDB_Difficulty(recipe.db, rank)
        end
        return nil
    end

    local function passes(recipe, craftable)
        if opts.source ~= nil and recipe.sourceType ~= opts.source then return false end
        if opts.category ~= nil and recipe.category ~= opts.category then return false end
        if opts.difficulty ~= nil and difficultyOf(recipe) ~= opts.difficulty then return false end
        if opts.hideGrey and difficultyOf(recipe) == ns.DIFFICULTY_LAST then return false end
        local rank = recipe.rank or copy.rank
        -- without the profession (no rank at all) a recipe can't be learned: it needs more than skill
        local needsMore = not recipe.learned and recipe.required and (not rank or recipe.required > rank)
        if opts.skill == "learnable" and (recipe.learned or needsMore) then return false end
        if opts.skill == "higher" and not needsMore then return false end
        if opts.canMake and craftable == 0 then return false end
        return true
    end

    local function group(list)
        local out = {}
        for _, recipe in ipairs(list) do
            if matches(recipe) then
                local craftable = ns.Recipes_Craftable(recipe, opts.alts)
                if passes(recipe, craftable) then
                    local row = { kind = "recipe", recipe = recipe, craftable = craftable, alts = opts.alts }
                    if ns.Prices_RecipeCost then
                        row.cost, row.incomplete = ns.Prices_RecipeCost(recipe)
                        row.value = ns.Prices_RecipeValue(recipe)
                    end
                    out[#out + 1] = row
                end
            end
        end
        if opts.sort then sortRows(out, opts.sort) end
        return out
    end

    if opts.flat then return group(copy.all or {}) end

    local collapsed = opts.collapsed or {}
    for _, part in ipairs({
        { "known", opts.known, copy.known, ns.L["Known recipes"] },
        { "unknown", opts.unknown, copy.unknown, ns.L["Not known"] },
    }) do
        if part[2] then
            local inGroup = group(part[3])
            if #inGroup > 0 then
                local isCollapsed = collapsed[part[1]] and true or false
                rows[#rows + 1] = { kind = "header", text = part[4], count = #inGroup, group = part[1], collapsed = isCollapsed }
                if not isCollapsed then
                    for _, row in ipairs(inGroup) do rows[#rows + 1] = row end
                end
            end
        end
    end
    return rows
end

-- A recipe of the data as the window's lists use it.
local function fromData(id, db, learned, rank, withSearch)
    local recipe = {
        id = id, name = db.n, icon = ns.RecipeDB_Icon(id, db), learned = learned, db = db, rank = rank,
        required = ns.RecipeDB_Required(db), colors = ns.RecipeDB_Colors(db), trivial = db.c and db.c[4],
        sourceType = ns.RecipeDB_Sources(db)[1], category = ns.RecipeDB_Category(db),
    }
    if withSearch then recipe.search = ns.RecipeDB_SearchText(id) end
    recipe.reagents = reagentsOfData(db)
    if learned then recipe.difficulty = ns.RecipeDB_Difficulty(db, rank or 0) end
    return recipe
end

-- A recipe of the data (any profession) as the lists use it, for the filters. `rank` is the character's skill in
-- that profession, nil when it doesn't have it.
function ns.Recipes_FromRecord(id, db, learned, rank)
    return fromData(id, db, learned, rank, false)
end

-- Every recipe of the data for a profession, known ones (by the spell book) apart from the rest. `rank` is the
-- character's skill, to color the known ones.
function ns.Recipes_FromData(skillLine, rank)
    local copy = { skillLine = skillLine, rank = rank, known = {}, unknown = {}, sources = {}, categories = {} }
    for id, db in ns.RecipeDB_Each() do
        if db.s == skillLine then
            local learned
            if ns.Roster_Knows then learned = ns.Roster_Knows(id) else learned = ns.RecipeDB_Known(id) end
            local recipe = fromData(id, db, learned, rank, true)
            if recipe.sourceType then copy.sources[recipe.sourceType] = true end
            copy.categories[recipe.category] = true
            local list = learned and copy.known or copy.unknown
            list[#list + 1] = recipe
        end
    end
    table.sort(copy.known, sortKnown)
    table.sort(copy.unknown, sortUnknown)
    return copy
end

-- What the playing character can make right now across its professions: the recipes of the data it knows (the spell book) whose
-- ingredients its bags hold. `professions` is a list as ns.Professions_Mine returns it. Returns
-- { { recipe =, craftable =, skillLine =, profession = the profession's name }, ... }, orange first and then by name, cut to `limit`
-- when given, and how many there were in all.
function ns.Recipes_CraftableNow(professions, limit)
    local have = {}
    for _, p in ipairs(professions) do
        if p.hasRecipes then have[p.skillLine] = p end
    end
    local found = {}
    for id, db in ns.RecipeDB_Each() do
        local p = have[db.s]
        if p and db.m and #db.m > 0 and ns.RecipeDB_Known(id) then
            -- the bags first: only what can be made is worth building
            local craftable = ns.Recipes_Craftable({ reagents = reagentsOfData(db) }, false)
            if craftable > 0 then
                found[#found + 1] = { recipe = fromData(id, db, true, p.rank, false), craftable = craftable, skillLine = p.skillLine, profession = p.name }
            end
        end
    end
    table.sort(found, function(a, b)
        local da, db = a.recipe.difficulty or ns.DIFFICULTY_LAST, b.recipe.difficulty or ns.DIFFICULTY_LAST
        if da ~= db then return da < db end
        if a.recipe.name ~= b.recipe.name then return a.recipe.name < b.recipe.name end
        return a.recipe.id < b.recipe.id
    end)
    local total = #found
    if limit then
        for i = total, limit + 1, -1 do found[i] = nil end
    end
    return found, total
end

-- Does the character the window shows know the recipe? (the spell book of the playing one, the saved copy of another)
local function knownByView(id)
    if ns.Roster_Knows then return ns.Roster_Knows(id) end
    return ns.RecipeDB_Known(id)
end

-- What the character could learn right now in its professions: for each profession with recipes, the recipes it doesn't know whose
-- required skill its skill reaches, the one with the nearest trainer or vendor first (and by its level among equals: the trainers
-- of a profession are the same for all its recipes). `professions` is a list as ns.Professions_List returns it.
-- Returns { { profession =, recipes = { recipe... }, total = n }, ... } in the professions' order, only the ones that have something;
-- `limit` cuts each group's recipes (`total` is how many there were). `sortBy` is how each group is ordered: "near" (the default: the
-- nearest trainer or vendor first), "level" (the lowest required skill first) or "name" (alphabetical); the others break the ties.
local function nameKey(entry) return (entry.db.n or ""):lower() end
local LEARN_ORDERS = {
    near = function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        if a.required ~= b.required then return a.required < b.required end
        if nameKey(a) ~= nameKey(b) then return nameKey(a) < nameKey(b) end
        return a.id < b.id
    end,
    level = function(a, b)
        if a.required ~= b.required then return a.required < b.required end
        if a.key ~= b.key then return a.key < b.key end
        if nameKey(a) ~= nameKey(b) then return nameKey(a) < nameKey(b) end
        return a.id < b.id
    end,
    name = function(a, b)
        if nameKey(a) ~= nameKey(b) then return nameKey(a) < nameKey(b) end
        if a.required ~= b.required then return a.required < b.required end
        return a.id < b.id
    end,
}
ns.LEARN_SORTS = { "near", "level", "name" } -- (the order the picker lists them in)

function ns.Recipes_LearnableNow(professions, limit, sortBy)
    local order = LEARN_ORDERS[sortBy] or LEARN_ORDERS.near
    local have = {}
    for _, p in ipairs(professions) do
        if p.hasRecipes and p.rank and p.learned ~= false then have[p.skillLine] = p end
    end
    local found, trainerKeys = {}, {}
    for id, db in ns.RecipeDB_Each() do
        local p = have[db.s]
        if p then
            local required = ns.RecipeDB_Required(db)
            -- (a recipe tied to a world event is out of season most of the year: nobody can teach it)
            if required and required <= p.rank and not ns.Seasonal_Event(id) and not knownByView(id) then
                local list = found[db.s] or {}
                found[db.s] = list
                trainerKeys[db.s] = trainerKeys[db.s] or ns.RecipeDB_TrainerKey(db.s)
                list[#list + 1] = { id = id, db = db, required = required, key = ns.RecipeDB_TeacherKey(db, trainerKeys[db.s]) }
            end
        end
    end
    local groups = {}
    for _, p in ipairs(professions) do
        local list = found[p.skillLine]
        if list and #list > 0 then
            table.sort(list, order)
            local recipes = {}
            for i, entry in ipairs(list) do
                if limit and i > limit then break end
                recipes[#recipes + 1] = fromData(entry.id, entry.db, false, p.rank, false)
            end
            groups[#groups + 1] = { profession = p, recipes = recipes, total = #list }
        end
    end
    return groups
end

-- Who teaches a recipe of the data (`db` is its record), nearest first (those that are for the character's side): the trainers, the
-- vendors of the item that teaches it, the quests that give it, and, after all of them, the creatures that drop it:
-- { { id =, name =, text =, distance = yards or nil, kind = "trainer" | "vendor" | "quest" | "drop", questID =, giver = }, ... }.
-- A trainer or a vendor is "name (zones)" and the price; a quest is its name, and the id, name and distance are those of the NPC that
-- gives it (for the map and waypoint buttons) when the data has it; a drop is the creature with its level and chance, or, for an item
-- that drops from any creature, one entry with no id that says so. The trainers of a recipe are all those of its profession (the data
-- does not say which of them teaches it).
function ns.Recipes_Teachers(db)
    local out = {}
    for _, line in ipairs(ns.RecipeDB_Where(db, true)) do
        local kind = (line.title == ns.L["Trainer"] and "trainer") or (line.title == ns.L["Vendor"] and "vendor")
            or (line.title == ns.L["Quest"] and "quest") or (line.title == ns.L["Drop"] and "drop")
            or (line.title == ns.L["Found in"] and "found") or nil
        if kind then
            local entries = line.entries
            if kind == "drop" and not entries and line.text then entries = { { text = line.text } } end -- (a world drop has no creature)
            for _, entry in ipairs(entries or {}) do
                out[#out + 1] = {
                    id = entry.id, name = entry.name or entry.text, text = entry.text, distance = entry.distance, kind = kind,
                    questID = entry.questID, giver = entry.giver, order = #out + 1,
                }
            end
        end
    end
    -- the kinds in one list by distance (those whose distance is not known after); a trainer before a vendor when equal; a drop or a
    -- container is only a chance, so they come after everybody who does teach it
    local function byChance(entry) return entry.kind == "drop" or entry.kind == "found" end
    table.sort(out, function(a, b)
        if byChance(a) ~= byChance(b) then return byChance(b) end
        local da, db2 = a.distance or math.huge, b.distance or math.huge
        if da ~= db2 then return da < db2 end
        return a.order < b.order
    end)
    return out
end

-- A profession's recipes: callback(copy) at once. The live answer of the game's window if that profession's is open,
-- else the data's (always the data's for another character: the window is the playing one's).
-- opts: { name = the profession's name, rank = the character's skill }
function ns.Recipes_Request(skillLine, callback, opts)
    opts = opts or {}
    local other = ns.Roster_ViewKey and ns.Roster_ViewKey() ~= nil
    local copy = (not other and ns.Recipes_Read(skillLine, opts.name)) or ns.Recipes_FromData(skillLine, opts.rank)
    copy.rank = opts.rank
    if not other then cache[skillLine] = copy end
    callback(copy)
end
