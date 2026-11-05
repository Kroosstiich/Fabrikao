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

-- The class, subclass, equip slot and class id of an item as GetItemInfoInstant gives them (itemID, type, subType, equipLoc, icon,
-- classID, subClassID), nil if the client has no such function.
function ns.ItemInstant(itemID)
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not info then return nil end
    return info(itemID)
end
