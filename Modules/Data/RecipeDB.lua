local _, ns = ...
local L = ns.L

-- Queries over ns.RECIPE_DATA (Data/Generated/Recipes.lua): what a recipe needs, at which skill it turns
-- orange, yellow, green and grey, and where it is learned (trainers, vendors, drops, quests). Works for
-- recipes of professions the character doesn't have, and for those it doesn't know yet.

local SOURCE_NAMES = {
    [1] = L["Crafted"], [2] = L["Drop"], [3] = L["PvP"], [4] = L["Quest"], [5] = L["Vendor"], [6] = L["Trainer"],
    [16] = L["Gathered"], [21] = L["Salvaged"],
}
-- the order they are shown in
local SOURCE_ORDER = { 6, 5, 4, 2, 3, 1, 16, 21 }

local function data()
    return ns.RECIPE_DATA
end

local function playerSide()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
end

-- Zones only one side can be in (its capitals and starting zones), by area id: many NPCs of the data carry no side, but a vendor
-- standing in Orgrimmar is not for an Alliance character.
local SIDE_ZONES = {
    A = { [1519] = true, [1537] = true, [1657] = true, [3557] = true, [12] = true, [1] = true, [141] = true, [3524] = true },
    H = { [1637] = true, [1497] = true, [1638] = true, [3487] = true, [14] = true, [85] = true, [215] = true, [3430] = true },
}

-- is it for the character's side (or both)? An NPC with no side of its own counts for the other one when every zone it is in is
-- one that side owns.
local function forMySide(entry)
    local mine = playerSide()
    if mine == nil then return true end
    if entry.f ~= nil then return entry.f == mine end
    local other = SIDE_ZONES[mine == "A" and "H" or "A"]
    if entry.z and #entry.z > 0 then
        for _, zone in ipairs(entry.z) do
            if not other[zone] then return true end
        end
        return false
    end
    return true
end

local function zoneName(id)
    local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
    return name
end

local function zoneList(ids)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local name = zoneName(id)
        if name then names[#names + 1] = name end
    end
    return table.concat(names, ", ")
end

local function money(copper)
    if not copper or copper <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

-- does the character know the recipe? (learned recipes are spells in the spell book)
function ns.RecipeDB_Known(spellID)
    if ns.IsClassic() then return ns.Classic_Known(spellID) end -- (a recipe is not in the spell book there)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
        if ok and known then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID, bank, false)
        if ok and known then return true end
    end
    return IsPlayerSpell ~= nil and IsPlayerSpell(spellID) and true or false
end

-- icon of what the recipe makes (or of the recipe itself)
function ns.RecipeDB_Icon(spellID, recipe)
    local product = recipe.p and recipe.p[1]
    local icon = product and ns.ItemIcon(product)
    if icon then return icon end
    return ns.SpellIcon(spellID) or 134400 -- the question mark
end

-- Category of what a recipe makes, to filter by: the slot of armor (hands, wrist...), the kind of weapon, bags, potions, elixirs,
-- food, gems, trade goods... The game names them (in the player's language) from the item the recipe makes. An enchantment makes
-- no item: its slot comes from its name ("Enchant Bracer - ...").
local ENCHANT_SLOTS = {
    Bracer = "INVTYPE_WRIST", Chest = "INVTYPE_CHEST", Boots = "INVTYPE_FEET", Gloves = "INVTYPE_HAND", Cloak = "INVTYPE_CLOAK",
    Shield = "INVTYPE_SHIELD", Ring = "INVTYPE_FINGER", ["2H Weapon"] = "INVTYPE_2HWEAPON",
}
local BY_SUBCLASS = { [0] = true, [2] = true, [6] = true, [7] = true } -- consumables, weapons, projectiles, trade goods: named by their subclass
local categories = {}

local function categoryOf(recipe)
    local product = recipe.p and recipe.p[1]
    if product and (C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant) then
        local _, itemType, subType, equipLoc, _, classID = ns.ItemInstant(product)
        if classID == 1 then return L["Bags"] end
        if classID == 4 and equipLoc and equipLoc ~= "" then
            if equipLoc == "INVTYPE_ROBE" then equipLoc = "INVTYPE_CHEST" end -- robes are chests
            return _G[equipLoc] or subType
        end
        if (BY_SUBCLASS[classID] or classID == 4) and subType and subType ~= "" then return subType end
        return itemType
    end
    local what = recipe.n and recipe.n:match("^Enchant (.-) %- ")
    if what == "Weapon" then return L["Weapon"] end
    return what and ENCHANT_SLOTS[what] and _G[ENCHANT_SLOTS[what]] or nil
end

function ns.RecipeDB_Category(recipe)
    local category = categories[recipe]
    if not category then
        local ok, found = pcall(categoryOf, recipe)
        category = ok and found or L["Other"]
        if category == "" then category = L["Other"] end
        categories[recipe] = category
    end
    return category
end

-- The tooltip of what the recipe makes (the item; for the ones that make none, like an enchantment, the recipe's own
-- spell) next to `owner`. False when there is nothing to show.
function ns.RecipeDB_ShowProductTooltip(owner, spellID, recipe)
    local product = recipe and recipe.p and recipe.p[1]
    if product and GameTooltip.SetItemByID then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(product)
        GameTooltip:Show()
        ns.Compare_Show(GameTooltip) -- (Classic clients: what you wear in that slot, beside it)
    elseif GameTooltip.SetSpellByID then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellID)
    else
        return false
    end
    GameTooltip:Show()
    return true
end

-- the record of a recipe (by its spell id), or nil
function ns.RecipeDB_Get(spellID)
    local db = data()
    return db and db.recipes[spellID]
end

-- The name of a recipe as the player's game calls it: the name of its spell (the id it is keyed by), in the client's
-- language; the data's (English) name when the client doesn't know the spell.
function ns.RecipeDB_Name(spellID, recipe)
    return ns.SpellName(spellID) or (recipe and recipe.n) or ""
end

function ns.RecipeDB_Each()
    local db = data()
    return pairs(db and db.recipes or {})
end

function ns.RecipeDB_Item(recipe)
    local db = data()
    return recipe.i and db and db.items[recipe.i]
end

-- skill needed to learn it (the point where it turns orange: the first number of the colors)
function ns.RecipeDB_Required(recipe)
    return recipe.l or (recipe.c and recipe.c[1]) or 0
end

-- { orange, yellow, green, grey } skill levels
function ns.RecipeDB_Colors(recipe)
    local c = recipe.c
    if not c then return nil end
    return { ns.RecipeDB_Required(recipe), c[2], c[3], c[4] }
end

-- the sources of a recipe as codes, from the recipe and from the item that teaches it
function ns.RecipeDB_Sources(recipe)
    local set, list = {}, {}
    local function add(codes)
        for _, code in ipairs(codes or {}) do set[code] = true end
    end
    add(recipe.k)
    local item = ns.RecipeDB_Item(recipe)
    if item then add(item.k) end
    for _, code in ipairs(SOURCE_ORDER) do
        if set[code] then list[#list + 1] = code end
    end
    return list
end

function ns.RecipeDB_SourceName(code)
    return SOURCE_NAMES[code] or L["Other"]
end

-- short text for a list row: "Trainer", "Vendor / Quest"...
function ns.RecipeDB_ShortSource(recipe)
    local names = {}
    for i, code in ipairs(ns.RecipeDB_Sources(recipe)) do
        if i > 2 then break end
        names[#names + 1] = SOURCE_NAMES[code]
    end
    return #names > 0 and table.concat(names, " / ") or nil
end

-- The name of an entry of the data in the player's language: an NPC's by default, `kind` "quest" or "object" for those.
local function nameOf(entry, kind)
    if kind == "quest" then return ns.QuestName(entry.id, entry.n) end
    if kind == "object" then return ns.ObjectName(entry.n) end
    return ns.NpcName(entry.id, entry.n)
end

local function named(entry, withZones, kind)
    local name = nameOf(entry, kind)
    local zones = withZones and zoneList(entry.z)
    if zones and zones ~= "" then return ("%s (%s)"):format(name, zones) end
    return name
end

-- Where an NPC of the data stands: { map = map id, x =, y = } (x and y in percent of the map), or nil when it is not known.
function ns.RecipeDB_NpcLocation(id)
    local db = data()
    local spot = db and db.npcs and db.npcs[id]
    return spot and { map = spot[1], x = spot[2], y = spot[3] } or nil
end

-- a list of texts as the entries of a line of ns.RecipeDB_Where
local function asEntries(texts)
    local entries = {}
    for i, text in ipairs(texts) do entries[i] = { text = text } end
    return entries
end

-- The NPCs by how far they are from the character (a trainer next door beats one in another continent): by distance when the game
-- tells it, then the ones on the character's map, then the ones elsewhere, then the ones whose position isn't known. The order they
-- came in is kept among equals. Returns a new list, and a table of the distances there are, by NPC.
local NOBODY = 4e7 -- the key of what nobody teaches: after every NPC

-- How near an NPC is, as a number to sort by (and its distance in yards when the game tells it): the distance itself, then 1e7 for the
-- ones on the character's map (`here`), 2e7 for the ones elsewhere, 3e7 for the ones whose position isn't known.
local function nearKey(npc, here)
    local spot = npc.id and ns.RecipeDB_NpcLocation(npc.id)
    local distance = spot and ns.Map_Distance and ns.Map_Distance(spot)
    if distance then return distance, distance end
    if spot and here and spot.map == here then return 1e7 end
    if spot then return 2e7 end
    return 3e7
end

local function playerMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function nearestFirst(list)
    local here = playerMap()
    local keyed, distances = {}, {}
    for index, npc in ipairs(list) do
        local key, distance = nearKey(npc, here)
        distances[npc] = distance
        keyed[index] = { npc = npc, key = key, index = index }
    end
    table.sort(keyed, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.index < b.index
    end)
    local sorted = {}
    for i, item in ipairs(keyed) do sorted[i] = item.npc end
    return sorted, distances
end

-- A quest as an entry of a line: its name (the text) and its id, and, when the data knows who gives it, its nearest giver: `id`, `name`
-- and `distance` are the giver's, for the map and waypoint buttons, and `giver` is "name (zones)".
local function questEntry(quest)
    local entry = { text = nameOf(quest, "quest"), questID = quest.id }
    if quest.g and #quest.g > 0 then
        local ordered, distances = nearestFirst(quest.g)
        local giver = ordered[1]
        entry.id, entry.name, entry.giver, entry.distance = giver.id, nameOf(giver), named(giver, true), distances[giver]
    end
    return entry
end

-- How a rank is gained when trainers do not teach it, from the data's `ranks`: the Expert rank (up to skill 225) of Cooking, First Aid and
-- Fishing is a book that a vendor sells, and the Artisan rank (up to 300) of the three is a quest. `cap` is the skill the rank goes up to.
-- Returns { { id =, name =, text =, distance =, kind = "vendor" | "quest", questID =, giver = }... }, those for the character's side,
-- nearest first; nil when the data has no book or quest for that rank (a trainer teaches it). A vendor's text is "name (zones) <book>"
-- and its price; a quest is its name, with its giver in `giver` (`id`, `name` and `distance` are the giver's, for the buttons).
function ns.RecipeDB_RankSources(skillLine, cap)
    local db = data()
    local rec = db and db.ranks and db.ranks[skillLine] and db.ranks[skillLine][cap]
    if not rec then return nil end
    local entries = {}
    for _, book in ipairs(rec.b or {}) do
        local vendors = {}
        for _, vendor in ipairs(book.v or {}) do
            if forMySide(vendor) then vendors[#vendors + 1] = vendor end
        end
        local ordered, distances = nearestFirst(vendors)
        for _, vendor in ipairs(ordered) do
            local price = money(vendor.g)
            entries[#entries + 1] = {
                id = vendor.id, name = nameOf(vendor), kind = "vendor", distance = distances[vendor],
                text = named(vendor, true) .. (price and (" -- " .. price) or "") .. " <" .. (book.i and ns.ItemName(book.i) or book.n) .. ">",
            }
        end
    end
    for _, quest in ipairs(rec.q or {}) do
        if forMySide(quest) then
            local entry = questEntry(quest)
            entry.kind = "quest"
            entries[#entries + 1] = entry
        end
    end
    if #entries == 0 then return nil end
    for index, entry in ipairs(entries) do entry.order = index end
    table.sort(entries, function(a, b)
        local da, db2 = a.distance or math.huge, b.distance or math.huge
        if da ~= db2 then return da < db2 end
        return a.order < b.order
    end)
    return entries
end

-- How near the closest trainer of a profession (a skill line) that is for the character's side is, as a number to sort by (the
-- same as nearestFirst's; a profession with none is after everyone). Compute it once per profession and give it to
-- ns.RecipeDB_TeacherKey for each recipe.
function ns.RecipeDB_TrainerKey(skillLine)
    local db = data()
    local here, best = playerMap(), NOBODY
    for _, trainer in ipairs(db and db.trainers and db.trainers[skillLine] or {}) do
        if forMySide(trainer) then
            local key = nearKey(trainer, here)
            if key < best then best = key end
        end
    end
    return best
end

-- The trainers that teach a recipe (its record), for the character's side: those of its profession, or, when the data says which ones
-- teach it (`t`, the ids of the NPCs: Classic Era and TBC), only those.
local function trainersOf(recipe)
    local db = data()
    local list = db and db.trainers and db.trainers[recipe.s] or {}
    local only
    if recipe.t then
        only = {}
        for _, id in ipairs(recipe.t) do only[id] = true end
    end
    local mine = {}
    for _, trainer in ipairs(list) do
        if (not only or only[trainer.id]) and forMySide(trainer) then mine[#mine + 1] = trainer end
    end
    return mine
end

-- How near the closest trainer or vendor that teaches a recipe (its record) is: the trainer key of its profession when trainers teach
-- it, and the vendors of the item that teaches it for the character's side; NOBODY (after everyone) when no one is known to.
function ns.RecipeDB_TeacherKey(recipe, trainerKey)
    local best = NOBODY
    for _, code in ipairs(recipe.k or {}) do
        if code == 6 and recipe.t then
            -- (only some of the profession's trainers teach it: the nearest of those)
            local here = playerMap()
            for _, trainer in ipairs(trainersOf(recipe)) do
                local key = nearKey(trainer, here)
                if key < best then best = key end
            end
        elseif code == 6 and trainerKey and trainerKey < best then
            best = trainerKey
        end
    end
    local item = ns.RecipeDB_Item(recipe)
    if item and item.v then
        local here = playerMap()
        for _, vendor in ipairs(item.v) do
            if forMySide(vendor) then
                local key = nearKey(vendor, here)
                if key < best then best = key end
            end
        end
    end
    return best
end

-- Where an ingredient (an item id) can be had, from the data's `reagents`: lines { title =, entries = { { text =, id =, name =,
-- distance = }... } } -- the vendors for the character's side (nearest first), the creatures that drop it and the ones skinned for it
-- (likeliest first, with the chance and how far they are), the zones it is fished in, the nodes it is gathered from and what makes it.
-- `id` and `name` are there for the creatures and vendors, who can be shown on the map. Empty when the data knows nothing of it.
function ns.RecipeDB_ReagentWhere(itemID)
    local db = data()
    local rec = db and db.reagents and db.reagents[itemID]
    local lines = {}
    if not rec then return lines end

    local function percent(pm)
        if not pm then return nil end
        return pm > 0 and pm < 10 and "<0.1%" or ("%.1f%%"):format(pm / 100)
    end

    local vendors = {}
    for _, vendor in ipairs(rec.v or {}) do
        if forMySide(vendor) then vendors[#vendors + 1] = vendor end
    end
    if #vendors > 0 then
        local ordered, distances = nearestFirst(vendors)
        local entries = {}
        for _, vendor in ipairs(ordered) do
            local price = money(vendor.g)
            entries[#entries + 1] = {
                id = vendor.id, name = nameOf(vendor), text = named(vendor, true) .. (price and (" -- " .. price) or ""),
                distance = distances[vendor],
            }
        end
        lines[#lines + 1] = { title = L["Sold by"], entries = entries }
    end

    -- creatures keep the order of the data (the likeliest first); how far each is goes with it
    local function creatures(list, title)
        if not list or #list == 0 then return end
        local _, distances = nearestFirst(list)
        local entries = {}
        for _, creature in ipairs(list) do
            local extra = {}
            if creature.lo then
                extra[#extra + 1] = L["level %s"]:format(creature.lo == creature.hi and creature.lo or (creature.lo .. "-" .. (creature.hi or creature.lo)))
            end
            local chance = percent(creature.pm)
            if chance then extra[#extra + 1] = chance end
            local text = named(creature, true)
            if #extra > 0 then text = text .. " -- " .. table.concat(extra, ", ") end
            entries[#entries + 1] = { id = creature.id, name = nameOf(creature), text = text, distance = distances[creature] }
        end
        lines[#lines + 1] = { title = title, entries = entries }
    end
    creatures(rec.d, L["Dropped by"])
    creatures(rec.k, L["Skinned from"])

    if rec.f and #rec.f > 0 then
        local entries = {}
        for _, zone in ipairs(rec.f) do
            local name = zoneName(zone.z)
            if name then
                local chance = percent(zone.pm)
                entries[#entries + 1] = { text = chance and (name .. " -- " .. chance) or name }
            end
        end
        if #entries > 0 then lines[#lines + 1] = { title = L["Fished in"], entries = entries } end
    end

    if rec.g and #rec.g > 0 then
        local entries = {}
        for _, node in ipairs(rec.g) do
            local zones = zoneList(node.z)
            entries[#entries + 1] = { text = zones ~= "" and ("%s (%s)"):format(ns.ObjectName(node.n), zones) or ns.ObjectName(node.n) }
        end
        lines[#lines + 1] = { title = L["Gathered from"], entries = entries }
    end

    if rec.c and #rec.c > 0 then
        local entries = {}
        for _, made in ipairs(rec.c) do
            local name = ns.RecipeDB_Name(made.i, made)
            entries[#entries + 1] = { text = made.s and ("%s: %s"):format(ns.RecipeDB_SkillName(made.s), name) or name }
        end
        lines[#lines + 1] = { title = L["Made by"], entries = entries }
    end
    return lines
end

-- The trainers of a profession (a skill line) that are for the character's side, nearest first (see nearestFirst):
-- { { id =, name =, title =, zones = text, text = "name (zones)", distance = yards or nil }, ... }, cut to `limit` when given, and how
-- many there are in all.
function ns.RecipeDB_Trainers(skillLine, limit)
    local db = data()
    local mine = {}
    for _, trainer in ipairs(db and db.trainers and db.trainers[skillLine] or {}) do
        if forMySide(trainer) then mine[#mine + 1] = trainer end
    end
    local ordered, distances = nearestFirst(mine)
    local list = {}
    for i, trainer in ipairs(ordered) do
        if limit and i > limit then break end
        list[#list + 1] = {
            id = trainer.id, name = nameOf(trainer), title = trainer.t, zones = zoneList(trainer.z), text = named(trainer, true),
            distance = distances[trainer],
        }
    end
    return list, #ordered
end

-- where the recipe is learned, as lines { title =, text =, entries = { { text =, id =, name = }... }, more = how many are left out }
-- for a tooltip or detail panel (`text` is the entries in one line; the panel puts each entry on its own line; id and name are
-- there for the trainers and vendors, who can be shown on the map); `full` lists far more of each (the recipe's own panel has the room)
function ns.RecipeDB_Where(recipe, full)
    local lines = {}
    local maxTrainers, maxVendors, maxQuests, maxDrops, maxObjects = 3, 5, 3, 4, 3
    if full then maxTrainers, maxVendors, maxQuests, maxDrops, maxObjects = 10, 12, 8, 30, 8 end
    local item = ns.RecipeDB_Item(recipe)

    local trainable = false
    for _, code in ipairs(recipe.k or {}) do if code == 6 then trainable = true end end
    if trainable then
        local names, npcs, count = {}, {}, 0
        local mine = trainersOf(recipe)
        local ordered, distances = nearestFirst(mine)
        for _, trainer in ipairs(ordered) do
            count = count + 1
            if count <= maxTrainers then
                names[#names + 1] = named(trainer, true)
                npcs[#npcs + 1] = { id = trainer.id, name = nameOf(trainer), text = named(trainer, true), distance = distances[trainer] }
            end
        end
        local text = table.concat(names, "; ")
        if count > #names then text = text .. "; " .. L["and %d more"]:format(count - #names) end
        local cost = money(recipe.g)
        if cost then text = (text ~= "" and (text .. " -- ") or "") .. L["costs %s"]:format(cost) end
        lines[#lines + 1] = { title = L["Trainer"], text = text, entries = npcs, more = count - #names }
    end

    if item then
        local vendors, npcs, vendorCount = {}, {}, 0
        local mine = {}
        for _, vendor in ipairs(item.v or {}) do
            if forMySide(vendor) then mine[#mine + 1] = vendor end
        end
        local ordered, distances = nearestFirst(mine)
        for _, vendor in ipairs(ordered) do
            vendorCount = vendorCount + 1
            if #vendors < maxVendors then
                local price = money(vendor.g)
                local text = named(vendor, true) .. (price and (" -- " .. price) or "")
                vendors[#vendors + 1] = text
                npcs[#npcs + 1] = { id = vendor.id, name = nameOf(vendor), text = text, distance = distances[vendor] }
            end
        end
        if #vendors > 0 then
            local text = table.concat(vendors, "; ")
            if vendorCount > #vendors then text = text .. "; " .. L["and %d more"]:format(vendorCount - #vendors) end
            lines[#lines + 1] = { title = L["Vendor"], text = text, entries = npcs, more = vendorCount - #vendors }
        end

        if item.qs then
            local quests, questEntries = {}, {}
            for _, quest in ipairs(item.qs) do
                if forMySide(quest) and #quests < maxQuests then
                    quests[#quests + 1] = nameOf(quest, "quest")
                    questEntries[#questEntries + 1] = questEntry(quest)
                end
            end
            if #quests > 0 then lines[#lines + 1] = { title = L["Quest"], text = table.concat(quests, "; "), entries = questEntries } end
        end

        if item.d then
            local drops, dropEntries = {}, {}
            -- (the tooltips keep the most likely drops first; the panel, with the room, puts the nearest first)
            local dropOrder, dropDistances = item.d, {}
            if full then dropOrder, dropDistances = nearestFirst(item.d) end
            for _, npc in ipairs(dropOrder) do
                if #drops < maxDrops then
                    local text = named(npc, true)
                    if npc.lo then text = text .. (npc.hi and npc.hi ~= npc.lo and (" " .. L["level %d-%d"]:format(npc.lo, npc.hi))
                        or (" " .. L["level %d"]:format(npc.lo))) end
                    if npc.pm and npc.pm > 0 then text = text .. (" -- %.2f%%"):format(npc.pm / 100) end
                    drops[#drops + 1] = text
                    dropEntries[#dropEntries + 1] = { text = text, id = npc.id, name = nameOf(npc), distance = dropDistances[npc] }
                end
            end
            local text = table.concat(drops, "; ")
            local left = item.dn and item.dn > #drops and item.dn - #drops or 0
            if left > 0 then text = text .. "; " .. L["and %d more"]:format(left) end
            lines[#lines + 1] = { title = L["Drop"], text = text, entries = dropEntries, more = left }
        elseif item.cd then
            lines[#lines + 1] = { title = L["Drop"], text = L["World drop: any creature of about level %d"]:format(item.lv or 0) }
        end

        if item.o then
            local objects = {}
            for _, object in ipairs(item.o) do
                if #objects < maxObjects then objects[#objects + 1] = named(object, true, "object") end
            end
            lines[#lines + 1] = { title = L["Found in"], text = table.concat(objects, "; "), entries = asEntries(objects) }
        end
    end

    if #lines == 0 then
        lines[1] = { title = L["Unknown"], text = L["No source known for this recipe"] }
    end
    return lines
end

-- Everything a search can match in a recipe, in lower case: its name, ingredients (the ones the client knows by now),
-- and who sells, drops or gives the item that teaches it, with their zones.
local function haystackOf(id, recipe)
    local parts = { recipe.n }
    local localized = ns.RecipeDB_Name(id, recipe)
    if localized ~= recipe.n then parts[#parts + 1] = localized end
    local itemName = C_Item and C_Item.GetItemNameByID
    for _, reagent in ipairs(recipe.m or {}) do
        local name = itemName and itemName(reagent[1])
        if name then parts[#parts + 1] = name end
    end
    local item = ns.RecipeDB_Item(recipe)
    if item then
        -- (the names in the player's language too: an NPC's only once the game has given it, asking for thousands is too slow)
        local lists = { { item.v, "npc" }, { item.d, "npc" }, { item.qs, "quest" }, { item.o, "object" } }
        for _, list in ipairs(lists) do
            for _, entry in ipairs(list[1] or {}) do
                parts[#parts + 1] = entry.n
                local shown
                if list[2] == "npc" then shown = ns.NpcName(entry.id, entry.n, true) else shown = nameOf(entry, list[2]) end
                if shown and shown ~= entry.n then parts[#parts + 1] = shown end
                if entry.z then parts[#parts + 1] = zoneList(entry.z) end
            end
        end
    end
    return table.concat(parts, "\n"):lower()
end

-- the same for a recipe by its spell id (for the lists of the profession pages), "" when it isn't known
function ns.RecipeDB_SearchText(spellID)
    local recipe = ns.RecipeDB_Get(spellID)
    return recipe and haystackOf(spellID, recipe) or ""
end

local function usesItem(recipe, itemID)
    for _, reagent in ipairs(recipe.m or {}) do
        if reagent[1] == itemID then return true end
    end
    return false
end

-- Recipes matching a search: every word of `text` has to be in the name, an ingredient, an NPC, a quest or a
-- zone. opts: { skill = skill line to look in (nil: all), ingredient = item id every match has to use (works with no
-- text too) }. Returns { { id = spellID, recipe = record }, ... } by name.
function ns.RecipeDB_Search(text, opts)
    local results = {}
    local db = data()
    if not db then return results end
    text = strtrim((text or ""):lower())
    local skill = opts and opts.skill
    local ingredient = opts and opts.ingredient
    -- no text: nothing, unless asked for everything (of a profession, or of all of them) to browse it
    if text == "" and not (opts and (opts.all or ingredient)) then return results end
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end

    for id, recipe in pairs(db.recipes) do
        if (not skill or recipe.s == skill) and (not ingredient or usesItem(recipe, ingredient)) then
            local haystack = text ~= "" and haystackOf(id, recipe) or ""
            local all = true
            for _, word in ipairs(words) do
                if not haystack:find(word, 1, true) then all = false break end
            end
            if all then results[#results + 1] = { id = id, recipe = recipe, name = ns.RecipeDB_Name(id, recipe) } end
        end
    end
    local browsing = text == ""
    table.sort(results, function(a, b)
        if browsing then -- a whole profession: by the skill each recipe needs
            local ra, rb = ns.RecipeDB_Required(a.recipe), ns.RecipeDB_Required(b.recipe)
            if ra ~= rb then return ra < rb end
        end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return results
end

-- 0 orange, 1 yellow, 2 green, 3 grey: how the recipe looks for a character with that skill. A level of 0 in
-- the data means the recipe skips that color (it stays orange until it turns grey, say).
function ns.RecipeDB_Difficulty(recipe, skill)
    local c = recipe.c
    if not c then return 0 end
    if c[4] > 0 and skill >= c[4] then return 3 end
    if c[3] > 0 and skill >= c[3] then return 2 end
    if c[2] > 0 and skill >= c[2] then return 1 end
    return 0
end

-- The highest skill any recipe of the data asks for: where this game's professions end (300 in a game with Artisan as the last rank).
local maxSkill
function ns.RecipeDB_MaxSkill()
    if maxSkill == nil or maxSkill.data ~= data() then
        local top = 0
        for _, recipe in ns.RecipeDB_Each() do
            local required = ns.RecipeDB_Required(recipe)
            if required and required > top then top = required end
        end
        maxSkill = { data = data(), value = top }
    end
    return maxSkill.value
end

local SKILL_NAMES = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [165] = "Leatherworking",
    [197] = "Tailoring", [186] = "Mining", [185] = "Cooking", [129] = "First Aid", [40] = "Poisons", [755] = "Jewelcrafting",
}
-- the order the professions are listed in a filter
local SKILL_ORDER = { 171, 164, 333, 202, 165, 197, 755, 186, 185, 129, 40 }

-- the profession's name in the player's language (from the client), or its English one
function ns.RecipeDB_SkillName(skill)
    if skill == 40 then -- Poisons is a rogue's spell, not a profession of the game's list: its name is the spell's
        local spell = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(2842)
        local name = (spell and spell.name) or (GetSpellInfo and GetSpellInfo(2842))
        if type(name) == "string" and name ~= "" then return name end
    end
    if ns.IsClassic() then
        local classic = ns.Classic_SkillName(skill)
        if classic then return classic end
    end
    local info = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
        and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skill)
    local name = info and info.professionName
    if name and name ~= "" then return name end
    return SKILL_NAMES[skill] or ("#" .. skill)
end

-- the skill lines that have recipes in the data, in display order
function ns.RecipeDB_Skills()
    local db = data()
    local present, list = {}, {}
    for _, recipe in pairs(db and db.recipes or {}) do present[recipe.s] = true end
    for _, skill in ipairs(SKILL_ORDER) do
        if present[skill] then list[#list + 1] = skill; present[skill] = nil end
    end
    local extra = {}
    for skill in pairs(present) do extra[#extra + 1] = skill end
    table.sort(extra)
    for _, skill in ipairs(extra) do list[#list + 1] = skill end
    return list
end
