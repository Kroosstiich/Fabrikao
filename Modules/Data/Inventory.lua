local _, ns = ...
local L = ns.L

-- What the other characters carry and keep in their banks, to count ingredients across the account. It comes from Embolsao,
-- which saves it for every character (account-wide, at logout and after every bag change):
--   * through its public API, EmbolsaoAPI (version 1: GetCharacters, GetOthersItemCount, GetItemHolders), when the installed
--     Embolsao has it;
--   * else by reading its saved variable as it is saved, for Embolsao versions without the API:
--       EmbolsaoDB.characterItems[key] = { name =, class = "MAGE", time =, bags = { [itemID] = n }, bank = { [itemID] = n } }
-- Without Embolsao (or with the preference off) none of this exists and every count is the character's own.

local function api()
    local a = EmbolsaoAPI
    if a and (a.version or 0) >= 1 and a.GetCharacters and a.GetOthersItemCount and a.GetItemHolders then return a end
    return nil
end

-- Is Embolsao there at all? Fabrikao works without it: this only decides what the preferences say.
function ns.Inventory_Installed()
    if api() or EmbolsaoDB ~= nil then return true end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded -- (older clients have only the global)
    return loaded and loaded("Embolsao") and true or false
end

local function enabled()
    return not (ns.char and ns.char.useAlts == false)
end

---------------------------------------------------------------------------------------------------
-- The saved variable, for Embolsao versions without the API
---------------------------------------------------------------------------------------------------
local function identity(name)
    return ((name or ""):gsub("%s", "")):lower()
end

local function nameOf(key, info)
    return (info and info.name) or (key or ""):match("^(.-)%-") or key
end

-- Every other character with something saved, each once (the newest copy when one is saved under several keys), by name:
-- { { key =, name =, class =, time =, bags =, bank = }, ... }
local function othersFromSavedVariable()
    local mine = identity(UnitName and UnitName("player"))
    local newest = {}
    for key, info in pairs((EmbolsaoDB and EmbolsaoDB.characterItems) or {}) do
        local name = nameOf(key, info)
        local id = identity(name)
        local seen = newest[id]
        if id ~= mine and type(info) == "table" and (not seen or (info.time or 0) > (seen.time or 0)) then
            newest[id] = { key = key, name = name, class = info.class, time = info.time, bags = info.bags or {}, bank = info.bank or {} }
        end
    end
    local others = {}
    for _, character in pairs(newest) do others[#others + 1] = character end
    table.sort(others, function(a, b) return a.name < b.name end)
    return others
end

---------------------------------------------------------------------------------------------------
-- What the rest of the addon asks
---------------------------------------------------------------------------------------------------
-- The other characters with items saved, by name: { { key =, name =, class =, time = }, ... } (the saved-variable path also
-- carries their bags and bank).
function ns.Inventory_Others()
    if not enabled() then return {} end
    local embolsao = api()
    if embolsao then return embolsao.GetCharacters() end
    return othersFromSavedVariable()
end

-- Are there other characters to count?
function ns.Inventory_Available()
    return #ns.Inventory_Others() > 0
end

-- The character's own: in the bags, and in the bank (what the client has of it: the bank's copy since the last visit).
function ns.Inventory_Mine(itemID)
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    local bags = count(itemID) or 0
    local both = count(itemID, true) or bags
    return bags, math.max(0, both - bags)
end

-- How many of an item the OTHER characters have in all (bags and banks).
function ns.Inventory_OthersTotal(itemID)
    if not enabled() then return 0 end
    local embolsao = api()
    if embolsao then
        local bags, bank = embolsao.GetOthersItemCount(itemID)
        return (bags or 0) + (bank or 0)
    end
    local total = 0
    for _, character in ipairs(othersFromSavedVariable()) do
        total = total + (character.bags[itemID] or 0) + (character.bank[itemID] or 0)
    end
    return total
end

-- Who else has the item, other characters only: { { name =, bags =, bank = }, ... }. The copies are read whatever the
-- "other characters" preference says: this is for looking at one of them.
local function holdersOf(itemID)
    local list = {}
    local embolsao = api()
    if embolsao then
        for _, holder in ipairs(embolsao.GetItemHolders(itemID) or {}) do
            list[#list + 1] = { name = holder.name, bags = holder.bags or 0, bank = holder.bank or 0 }
        end
        return list
    end
    for _, character in ipairs(othersFromSavedVariable()) do
        local bags, bank = character.bags[itemID] or 0, character.bank[itemID] or 0
        if bags > 0 or bank > 0 then list[#list + 1] = { name = character.name, bags = bags, bank = bank } end
    end
    return list
end

-- The count as seen by another character (the window shows its professions): its bags by default, or with `alts`, everything
-- the account has: its bags and bank, the playing character's and the rest of the characters'. Zero where Embolsao has no
-- copy of it.
local function countAs(itemID, name, alts)
    local id = identity(name)
    local bags, bank, rest = 0, 0, 0
    for _, holder in ipairs(holdersOf(itemID)) do
        if identity(holder.name) == id then
            bags, bank = holder.bags, holder.bank
        else
            rest = rest + holder.bags + holder.bank
        end
    end
    if not alts then return bags end
    local mineBags, mineBank = ns.Inventory_Mine(itemID)
    return bags + bank + mineBags + mineBank + (enabled() and rest or 0)
end

-- How many of an item there are: only in the character's bags by default, or with `alts`, everything: its own bags and
-- bank and the bags and banks of the other characters. While the window shows another character, that one's.
function ns.Inventory_Count(itemID, alts)
    local viewed = ns.Roster_Viewed and ns.Roster_Viewed()
    if viewed then return countAs(itemID, viewed.name, alts) end
    local bags, bank = ns.Inventory_Mine(itemID)
    if not alts then return bags end
    return bags + bank + ns.Inventory_OthersTotal(itemID)
end

-- Who has the item: { { name =, class =, bags =, bank =, me = true or nil }, ... }, the character first, then the others by
-- name; only those with some. Nil when there are no other characters to tell from.
function ns.Inventory_Breakdown(itemID)
    if not ns.Inventory_Available() then return nil end
    local list = {}
    local bags, bank = ns.Inventory_Mine(itemID)
    if bags > 0 or bank > 0 then
        local class = UnitClass and select(2, UnitClass("player"))
        list[#list + 1] = { name = UnitName("player"), class = class, bags = bags, bank = bank, me = true }
    end
    local embolsao = api()
    if embolsao then
        for _, holder in ipairs(embolsao.GetItemHolders(itemID)) do
            list[#list + 1] = { name = holder.name, class = holder.class, bags = holder.bags or 0, bank = holder.bank or 0 }
        end
        return list
    end
    for _, character in ipairs(othersFromSavedVariable()) do
        local inBags, inBank = character.bags[itemID] or 0, character.bank[itemID] or 0
        if inBags > 0 or inBank > 0 then
            list[#list + 1] = { name = character.name, class = character.class, bags = inBags, bank = inBank }
        end
    end
    return list
end

-- Adds who has the item to a tooltip, one line per OTHER character, leaving out the ones the tooltip already lists: Embolsao puts
-- them in every item tooltip itself, so they would show twice. The character playing is not added either: its bags are in
-- front of the player and Embolsao's "In your bank" line is already in the tooltip.
function ns.Inventory_AddTooltipLines(tooltip, itemID)
    local list = ns.Inventory_Breakdown(itemID)
    if not list then return end
    local present = {}
    local name = tooltip.GetName and tooltip:GetName()
    for i = 1, (name and tooltip.NumLines and tooltip:NumLines()) or 0 do
        local fontString = _G[name .. "TextLeft" .. i]
        local text = fontString and fontString.GetText and fontString:GetText()
        if text then present[#present + 1] = text end
    end
    for _, entry in ipairs(list) do
        local listed = entry.me or false
        for _, text in ipairs(present) do
            if text:find(entry.name .. "|r: ", 1, true) or text:find(entry.name .. ": ", 1, true) then listed = true break end
        end
        if not listed then tooltip:AddLine(ns.Inventory_Line(entry), 0.8, 0.8, 0.8) end
    end
end

-- The same as a line of text: "Elsa: 5 in bags, 2 in bank" (the name in its class color).
function ns.Inventory_Line(entry)
    local color = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    local name = color and ("|c" .. (color.colorStr or "ffffffff") .. entry.name .. "|r") or entry.name
    local parts = {}
    if entry.bags > 0 then parts[#parts + 1] = L["%d in bags"]:format(entry.bags) end
    if entry.bank > 0 then parts[#parts + 1] = L["%d in bank"]:format(entry.bank) end
    return name .. ": " .. table.concat(parts, ", ")
end
