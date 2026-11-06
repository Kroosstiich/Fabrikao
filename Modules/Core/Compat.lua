local _, ns = ...

-- Queries the clients answer under two names: the C_Item / C_Spell one (Forever, and the Classic clients that have it) and the older
-- global one. Forever's answer is always tried first, so what it shows does not change.

-- The name of an item, or nil while the client has not loaded it (it is asked to).
function ns.ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then return name end
    name = GetItemInfo and GetItemInfo(itemID)
    if name then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return nil
end

-- The icon of an item, or nil.
function ns.ItemIcon(itemID)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if icon then return icon end
    if GetItemIcon then return GetItemIcon(itemID) end
    return nil
end

-- The icon of a spell, or nil.
function ns.SpellIcon(spellID)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if icon then return icon end
    return GetSpellTexture and GetSpellTexture(spellID) or nil
end

-- The name of a spell in the player's language, or nil when the client doesn't know it. A spell's name is always at hand
-- (no load to wait for), unlike an item's.
function ns.SpellName(spellID)
    if not spellID then return nil end
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    elseif C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        name = info and info.name
    end
    if (not name or name == "") and GetSpellInfo then name = GetSpellInfo(spellID) end
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

-- The name of an NPC (vendor, trainer, creature) in the player's language, from the game's creature cache: a hidden tooltip
-- of the creature's link. The cache holds the ones the character has met or the game was asked about; asking is what makes
-- the game fetch the rest, so a name that isn't there yet usually is the next time. `fallback` (the data's English name)
-- meanwhile. `cachedOnly`: don't ask the game (for the search, which goes over thousands of NPCs a keystroke).
local npcNames = {} -- [npc id] = name, what the game has answered this session
local scanTip
local function askNpcName(id)
    local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(id)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local info = C_TooltipInfo.GetHyperlink(link)
        local line = info and info.lines and info.lines[1]
        return line and line.leftText
    end
    if not (CreateFrame and WorldFrame) then return nil end
    if not scanTip then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "FabrikaoNameTooltip", nil, "GameTooltipTemplate")
        if not ok or not tip then return nil end
        scanTip = tip
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    pcall(scanTip.SetHyperlink, scanTip, link)
    local line = _G["FabrikaoNameTooltipTextLeft1"]
    local text = line and line:GetText()
    scanTip:Hide()
    return text
end

function ns.NpcName(id, fallback, cachedOnly)
    if not id then return fallback end
    local name = npcNames[id]
    if name then return name end
    if cachedOnly then return fallback end
    local ok, answer = pcall(askNpcName, id)
    if ok and type(answer) == "string" and answer ~= "" and answer ~= RETRIEVING_DATA then
        npcNames[id] = answer
        return answer
    end
    return fallback
end

-- The name of a quest in the player's language, when the game has it (else it is asked for, and `fallback` meanwhile).
function ns.QuestName(questID, fallback)
    if not (questID and C_QuestLog) then return fallback end
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if (not title or title == "") and C_QuestLog.GetQuestInfo then title = C_QuestLog.GetQuestInfo(questID) end
    if type(title) == "string" and title ~= "" then return title end
    if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(questID) end
    return fallback
end

-- The name of a world object (a herb, a vein, a chest) in the player's language: the game has no query for those, so
-- they come with the data (ns.OBJECT_NAMES[locale][English name], Data/.../Names.lua). The English name otherwise.
function ns.ObjectName(englishName)
    local names = ns.OBJECT_NAMES
    if not (names and englishName and GetLocale) then return englishName end
    local locale = GetLocale()
    local sibling = (locale == "esMX" and "esES") or (locale == "esES" and "esMX") or nil -- (one fills the other's gaps)
    local found = names[locale] and names[locale][englishName]
    if not found and sibling then found = names[sibling] and names[sibling][englishName] end
    return found or englishName
end

-- The class, subclass, equip slot and class id of an item as GetItemInfoInstant gives them (itemID, type, subType, equipLoc, icon,
-- classID, subClassID), nil if the client has no such function.
function ns.ItemInstant(itemID)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not info then return nil end
    return info(itemID)
end
