local _, ns = ...
local L = ns.L

-- The panel of a recipe, next to the main window: everything the addon knows about it (status, skill and colors, what it makes,
-- the ingredients with how many you have, cost and profit, the item that teaches it, where it is learned). A click on a
-- recipe of the lists opens it; ns.RecipeDetail_Show(recipe, opts) fills it, with `recipe` as the lists see it (ns.Recipes_FromData...)
-- and opts = { parent = the window to dock to, alts = count the other characters too, rank = the character's skill in the
-- profession (when the recipe has none of its own), onClose = function() }.
-- A recipe the character knows has a "Craft" button that opens the game's profession window on it (Modules/Professions/Craft.lua).
-- The trainers and vendors of a recipe the character doesn't know have a button that shows them on the map and, with TomTom
-- installed, another that sets a waypoint (Modules/Map/Map.lua).

local WIDTH = 520
local MARGIN = 22
local SCROLL_W = 28 -- the scroll bar
local TEXT_W = WIDTH - MARGIN - SCROLL_W - 6
local LABEL_W = 150
local ICON, ROW_H = 42, 54
local GOLD = "|cffffd100"
local GREEN, RED, DIM = "|cff40bf40", "|cffff4040", "|cff9a9a9a"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t"
local CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:16|t"

-- the texts are one size up from the game's usual: the panel has the room
local FONT_BODY, FONT_LABEL, FONT_SMALL = "GameFontHighlightLarge", "GameFontNormalLarge", "GameFontHighlight"
local FONT_HEAD = _G.GameFontNormalHuge and "GameFontNormalHuge" or "GameFontNormalLarge"

local panel, current

local function colorCode(color)
    return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

local function itemName(itemID)
    return ns.ItemName(itemID) or L["item %d"]:format(itemID)
end

local function itemIcon(itemID)
    return ns.ItemIcon(itemID) or 134400
end

local function iconText(texture)
    return texture and ("|T%s:16|t "):format(tostring(texture)) or ""
end

-- how many of an item: the bags, the bank and the other characters
local function holdings(itemID)
    local bags, bank = 0, 0
    if ns.Inventory_Mine then bags, bank = ns.Inventory_Mine(itemID) end
    return bags, bank, ns.Inventory_OthersTotal and ns.Inventory_OthersTotal(itemID) or 0
end

-- Sets a TomTom waypoint at the NPC ({ id =, name = }); false when TomTom or its location is missing.
function ns.RecipeDetail_Waypoint(npc)
    return ns.Map_TomTom(ns.RecipeDB_NpcLocation(npc.id), npc.name)
end

-- Opens the world map on the NPC; false when its location is missing.
function ns.RecipeDetail_ViewOnMap(npc)
    local spot = ns.RecipeDB_NpcLocation(npc.id)
    return spot ~= nil and ns.Map_Show(spot)
end

---------------------------------------------------------------------------------------------------
-- What the panel says
---------------------------------------------------------------------------------------------------
-- The panel's content as data:
-- { name =, color =, icon =, subtitle =, status = text, facts = { { label =, value = }... }, reagents = { { itemID =, items =, needed =,
--   have =, bank =, others =, unit =, total =, status = text }... }, economy = { { label =, value = }... }, note = text or nil,
--   sources = the lines of ns.RecipeDB_Where, ids = text }.
function ns.RecipeDetail_Build(recipe, opts)
    opts = opts or {}
    local db = recipe.db
    local rank = recipe.rank or opts.rank
    local viewed = ns.Roster_Viewed and ns.Roster_Viewed() -- another character's professions are shown: read only, in the third person
    local who = viewed and ns.Roster_ColoredName(viewed)
    local out = { name = recipe.name, icon = recipe.icon }
    out.color = recipe.learned and ns.DIFFICULTY_COLORS[recipe.difficulty or ns.DIFFICULTY_LAST] or { 0.85, 0.85, 0.85 }

    local subtitle = {}
    if db then subtitle[#subtitle + 1] = ns.RecipeDB_SkillName(db.s) end
    if recipe.category then subtitle[#subtitle + 1] = recipe.category end
    out.subtitle = table.concat(subtitle, "  -  ")

    if recipe.learned then
        out.status = GREEN .. CHECK .. " " .. (who and L["%s knows this recipe"]:format(who) or L["You know this recipe"]) .. "|r"
    elseif rank then
        out.status = CROSS .. " " .. (who and L["%s doesn't know this recipe yet"]:format(who) or L["You don't know this recipe yet"])
    else
        out.status = DIM .. CROSS .. " " .. (who and L["%s doesn't have this profession"]:format(who) or L["You don't have this profession"]) .. "|r"
    end

    local facts = {}
    local function fact(label, value) facts[#facts + 1] = { label = label, value = value } end

    local required = recipe.required or (db and ns.RecipeDB_Required(db))
    if required then
        local text = tostring(required)
        if rank then
            local have = who and L["%s has %d"]:format(viewed.label, rank) or L["you have %d"]:format(rank)
            text = text .. ("   (%s)"):format((rank >= required and GREEN or RED) .. have .. "|r")
        end
        fact(L["Skill needed:"], text)
    end

    local colors = recipe.colors or (db and ns.RecipeDB_Colors(db))
    if colors then
        fact(L["Difficulty:"], ns.DifficultyColorsText(colors))
        if db and rank and required and rank >= required then
            local d = ns.RecipeDB_Difficulty(db, rank)
            local names = { [0] = L["orange"], L["yellow"], L["green"], L["grey"] }
            fact(who and L["For their skill:"] or L["For your skill:"], ("%s%s|r"):format(colorCode(ns.DIFFICULTY_COLORS[d]), names[d]))
        end
    end

    local product = db and db.p
    if product then
        local quantity = product[2] == product[3] and tostring(product[2]) or ("%d-%d"):format(product[2], product[3])
        fact(L["Makes:"], ("%s%s x%s"):format(iconText(itemIcon(product[1])), itemName(product[1]), quantity))
    end

    local alts = opts.alts and ns.Inventory_Available and ns.Inventory_Available()
    if recipe.reagents and #recipe.reagents > 0 and ns.Recipes_Craftable then
        local now = ns.Recipes_Craftable(recipe, false)
        fact(L["Crafts possible:"], alts and L["%d (%d counting your other characters)"]:format(now, ns.Recipes_Craftable(recipe, true))
            or tostring(now))
    end

    if db and db.g and db.g > 0 then fact(L["Training cost:"], ns.FormatMoney(db.g)) end
    local teacher = db and ns.RecipeDB_Item(db)
    if db and db.i then
        local text = teacher and teacher.n or itemName(db.i)
        if teacher and teacher.lv then text = text .. " " .. DIM .. "(" .. L["item level %d"]:format(teacher.lv) .. ")|r" end
        fact(L["Taught by:"], text)
    end
    if db and db.u then fact(L["New in Forever"], GREEN .. L["Yes"] .. "|r") end
    out.facts = facts

    -- ingredients, one row each
    out.reagents = {}
    for _, reagent in ipairs(recipe.reagents or {}) do
        local itemID = reagent.items[1]
        local have, bank, others = 0, 0, 0
        for _, id in ipairs(reagent.items) do
            local b, k, o = holdings(id)
            have, bank, others = have + b, bank + k, others + o
        end
        local unit = ns.Prices_Unit and ns.Prices_Unit(itemID)
        local parts = { L["you have %d"]:format(have) }
        if bank > 0 then parts[#parts + 1] = L["%d in your bank"]:format(bank) end
        if others > 0 then parts[#parts + 1] = L["+%d on other characters"]:format(others) end
        local color = have >= reagent.quantity and GREEN or (have + bank >= reagent.quantity and GOLD or RED)
        out.reagents[#out.reagents + 1] = {
            itemID = itemID, items = reagent.items, needed = reagent.quantity, have = have, bank = bank, others = others,
            unit = unit, total = unit and unit * reagent.quantity or nil, status = color .. table.concat(parts, ", ") .. "|r",
        }
    end

    -- what it costs and brings
    local economy = {}
    local cost, incomplete
    if ns.Prices_RecipeCost then cost, incomplete = ns.Prices_RecipeCost(recipe) end
    local value = ns.Prices_RecipeValue and ns.Prices_RecipeValue(recipe)
    if cost then economy[#economy + 1] = { label = L["Ingredients cost:"], value = ns.FormatMoney(cost) .. (incomplete and "+" or "") } end
    if value then economy[#economy + 1] = { label = L["Sells for about:"], value = ns.FormatMoney(value) } end
    if cost and value then
        local profit = value - cost
        economy[#economy + 1] = { label = L["Profit:"], value = (profit >= 0 and GREEN or RED) .. (profit < 0 and "-" or "")
            .. ns.FormatMoney(math.abs(profit)) .. "|r" }
    end
    out.economy = economy
    if (cost or value) and ns.Prices_HasAuctionData and not ns.Prices_HasAuctionData() then
        out.note = L["No auction data (Auctionator): the cost uses what vendors pay."]
    end

    -- where it is learned
    if db then
        out.sources = ns.RecipeDB_Where(db, true)
    elseif recipe.sourceText and recipe.sourceText ~= "" then
        out.sources = { { title = L["Source"], text = recipe.sourceText } }
    else
        out.sources = {}
    end

    local ids = { L["Recipe ID: %d"]:format(recipe.id) }
    if product then ids[#ids + 1] = L["Item ID: %d"]:format(product[1]) end
    out.ids = table.concat(ids, "     ")
    return out
end

---------------------------------------------------------------------------------------------------
-- Drawing: the pieces are made once and reused (pools), laid out top to bottom
---------------------------------------------------------------------------------------------------
local pools, used = { fs = {}, line = {}, ingredient = {}, npc = {} }, { fs = 0, line = 0, ingredient = 0, npc = 0 }

local function acquire(kind, make)
    used[kind] = used[kind] + 1
    local piece = pools[kind][used[kind]]
    if not piece then
        piece = make()
        pools[kind][used[kind]] = piece
    end
    piece:Show()
    return piece
end

local function releaseAll()
    for kind, list in pairs(pools) do
        for _, piece in ipairs(list) do piece:Hide() end
        used[kind] = 0
    end
end

local function newText()
    local fs = panel.child:CreateFontString(nil, "OVERLAY", FONT_BODY)
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    return fs
end

-- A text at (x, y) of the content, `width` wide; returns its height.
local function put(font, x, y, width, text, justify, color)
    local fs = acquire("fs", newText)
    fs:SetFontObject(font)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", panel.child, "TOPLEFT", x, -y)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    if color then fs:SetTextColor(color[1], color[2], color[3]) else fs:SetTextColor(1, 1, 1) end
    fs:SetText(text)
    return fs:GetStringHeight()
end

local function heading(y, title)
    put(FONT_HEAD, 0, y, TEXT_W, title, nil, { 1, 0.82, 0 })
    local line = acquire("line", function() return panel.child:CreateTexture(nil, "ARTWORK") end)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -(y + 28))
    line:SetSize(TEXT_W, 1)
    line:SetColorTexture(1, 0.82, 0, 0.4)
    return y + 40
end

-- "Label    value" with the value wrapping in its own column
local function factRow(y, label, value)
    local a = put(FONT_LABEL, 0, y, LABEL_W, label, nil, { 1, 0.82, 0 })
    local b = put(FONT_BODY, LABEL_W + 8, y, TEXT_W - LABEL_W - 8, value)
    return y + math.max(a, b) + 9
end

local function newIngredient()
    local row = CreateFrame("Button", nil, panel.child)
    row:SetSize(TEXT_W, ROW_H - 4)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 2, 0)
    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 1)
    row.name = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
    row.name:SetPoint("RIGHT", row, "RIGHT", -100, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.status = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    row.status:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
    row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.status:SetJustifyH("LEFT")
    row.status:SetWordWrap(false)
    row.price = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    row.price:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
    row.price:SetJustifyH("RIGHT")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetText(itemName(self.itemID), 1, 1, 1) end
        if ns.Inventory_AddTooltipLines then ns.Inventory_AddTooltipLines(GameTooltip, self.itemID) end
        GameTooltip:AddLine(L["Click to see where to get it"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local info = C_Item and C_Item.GetItemInfo or GetItemInfo
            local link = info and select(2, info(self.itemID))
            if link then ChatEdit_InsertLink(link) end
        else
            ns.RecipeDetail_ToggleReagent(self.itemID)
        end
    end)
    return row
end

local function ingredientRow(y, reagent)
    local row = acquire("ingredient", newIngredient)
    row.itemID = reagent.itemID
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
    row.icon:SetTexture(itemIcon(reagent.itemID))
    row.count:SetText(reagent.needed > 1 and tostring(reagent.needed) or "")
    row.name:SetText(("%s x%d"):format(itemName(reagent.itemID), reagent.needed))
    row.status:SetText(reagent.status)
    row.price:SetText(reagent.total and (DIM .. ns.FormatMoney(reagent.total) .. "|r") or "")
    return y + ROW_H
end

local function newNpc()
    local row = CreateFrame("Frame", nil, panel.child)
    row.text = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    row.text:SetPoint("TOPLEFT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    row.tomButton = ns.IconButton_Create(row, "pointer", L["Set a TomTom waypoint"], function(npc) return ns.RecipeDetail_Waypoint(npc) end)
    row.mapButton = ns.IconButton_Create(row, "map", L["View on map"], function(npc) return ns.RecipeDetail_ViewOnMap(npc) end)
    -- a quest of Completao!!'s: its icon opens the quest there
    row.questButton = ns.IconButton_Create(row, "quest", L["View Quest"], function(npc) return ns.Quests_Show(npc.questID) end)
    return row
end

-- An entry of a source (a trainer, a vendor, a creature that drops it, a quest...) on its own line, with the map and waypoint buttons
-- when it is an NPC with a known location, and Completao!!'s icon (View Quest) when it is a quest Completao has.
local function npcRow(y, npc, indent)
    local row = acquire("npc", newNpc)
    local x = indent or 14
    local spot = npc.id and ns.RecipeDB_NpcLocation(npc.id)
    local withTomTom = spot and ns.Map_HasTomTom()
    local quest = npc.questID and ns.Quests_Known(npc.questID)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", x, -y)
    row:SetWidth(TEXT_W - x)
    row.tomButton:SetShown(withTomTom and true or false)
    row.mapButton:SetShown(spot and true or false)
    row.questButton:SetShown(quest and true or false)
    local taken = ns.IconButton_Row(0, 0, row.tomButton, row.mapButton, row.questButton)
    row.text:SetWidth(TEXT_W - x - taken)
    -- how far it is, when the game says (the list is in that order)
    local distance = npc.distance and ns.Map_FormatDistance and ns.Map_FormatDistance(npc.distance)
    row.text:SetText(distance and (npc.text .. "  " .. DIM .. distance .. "|r") or npc.text)
    row.tomButton.npc, row.mapButton.npc, row.questButton.npc = npc, npc, npc
    local height = math.max(row.text:GetStringHeight(), (spot or quest) and 22 or 0)
    row:SetHeight(height)
    return y + height + 6
end

-- Where an ingredient can be had, under its row (a click on the row opens and closes it): who sells it, the creatures that drop it, the
-- zones it is fished in... with the map and waypoint buttons of the ones that have a place.
local function reagentSources(y, itemID)
    local lines = ns.RecipeDB_ReagentWhere and ns.RecipeDB_ReagentWhere(itemID) or {}
    if #lines == 0 then
        return y + put(FONT_SMALL, 14, y, TEXT_W - 14, L["No known source."], nil, { 0.6, 0.6, 0.6 }) + 10
    end
    for _, line in ipairs(lines) do
        y = y + put(FONT_LABEL, 14, y, TEXT_W - 14, line.title, nil, { 1, 0.82, 0 }) + 4
        for _, entry in ipairs(line.entries) do y = npcRow(y, entry, 28) end
        y = y + 4
    end
    return y + 6
end

-- The craft button: only for a recipe the character knows, with how many the bags allow.
local function updateCraftBar()
    if not (panel and current) then return end
    local recipe = current.recipe
    -- no crafting for another character's recipes: the game's window is the playing character's
    local known = recipe.learned and not (ns.Roster_ViewKey and ns.Roster_ViewKey()) and true or false
    panel.craftBar:SetShown(known)
    if not known then return end
    local craftable = ns.Recipes_Craftable and ns.Recipes_Craftable(recipe, false) or 0
    panel.craftInfo:SetText(L["%d possible with your bags"]:format(craftable))
    panel.craftButton:SetEnabled(craftable > 0) -- nothing to craft with what the bags hold
    -- (Classic: the click is the secure overlay that opens the profession window, so it follows the button)
    ns.Craft_Prepare(panel.craftButton, craftable > 0 and recipe.id or nil, recipe.db and recipe.db.s)
end

local function render()
    if not (panel and current) then return end
    local data = ns.RecipeDetail_Build(current.recipe, current.opts)
    releaseAll()
    updateCraftBar()
    -- tinted blue with the window when it is another character's recipes
    if ns.Roster_ViewKey and ns.Roster_ViewKey() then
        panel:SetBackdropColor(0.05, 0.1, 0.25, 1)
    else
        panel:SetBackdropColor(0.05, 0.05, 0.07, 1)
    end

    panel.name:SetText(data.name)
    panel.name:SetTextColor(data.color[1], data.color[2], data.color[3])
    panel.subtitle:SetText(data.subtitle)
    panel.status:SetText(data.status)
    panel.icon:SetTexture(data.icon)

    local y = 4
    for _, f in ipairs(data.facts) do y = factRow(y, f.label, f.value) end

    if #data.reagents > 0 then
        y = heading(y + 10, (L["Ingredients:"]:gsub(":$", "")))
        for _, reagent in ipairs(data.reagents) do
            y = ingredientRow(y, reagent)
            if current.expanded[reagent.itemID] then y = reagentSources(y, reagent.itemID) end
        end
    end

    if #data.economy > 0 then
        y = heading(y + 10, L["Cost and profit"])
        for _, f in ipairs(data.economy) do y = factRow(y, f.label, f.value) end
        if data.note then y = y + put(FONT_SMALL, 0, y, TEXT_W, data.note, nil, { 0.6, 0.6, 0.6 }) + 8 end
    end

    if #data.sources > 0 then
        y = heading(y + 10, L["Where to learn it"])
        for _, line in ipairs(data.sources) do
            if line.entries and #line.entries > 0 then
                y = y + put(FONT_LABEL, 0, y, TEXT_W, line.title, nil, { 1, 0.82, 0 }) + 6
                for _, entry in ipairs(line.entries) do y = npcRow(y, entry) end
                if line.more and line.more > 0 then
                    y = y + put(FONT_SMALL, 14, y, TEXT_W - 14, L["and %d more"]:format(line.more), nil, { 0.6, 0.6, 0.6 }) + 6
                end
                y = y + 4
            else
                y = factRow(y, line.title, line.text)
            end
        end
    end

    y = y + put(FONT_SMALL, 0, y + 14, TEXT_W, data.ids, nil, { 0.55, 0.55, 0.55 }) + 28
    ns.AutoScroll_SetHeight(panel.scroll, y)
    panel.scroll:SetVerticalScroll(0)
end

---------------------------------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------------------------------
local function create(parent)
    panel = CreateFrame("Frame", "FabrikaoDetailFrame", UIParent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata(parent:GetFrameStrata())
    parent:HookScript("OnHide", function() ns.RecipeDetail_Hide() end) -- it goes away with the window
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.07, 1)
    panel:SetToplevel(true)
    panel:EnableMouse(true) -- clicks must not fall through to what is behind it

    local okClose, close = pcall(CreateFrame, "Button", nil, panel, "UIPanelCloseButtonDefaultAnchors")
    if not okClose or not close then close = CreateFrame("Button", nil, panel, "UIPanelCloseButton") end
    close:SetPoint("TOPRIGHT", -6, -6)

    -- the icon of what it makes, in a frame, with that item's tooltip
    local iconFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    iconFrame:SetSize(72, 72)
    iconFrame:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    iconFrame:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
    iconFrame:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    local iconButton = CreateFrame("Button", nil, iconFrame)
    iconButton:SetPoint("TOPLEFT", 5, -5)
    iconButton:SetPoint("BOTTOMRIGHT", -5, 5)
    panel.icon = iconButton:CreateTexture(nil, "ARTWORK")
    panel.icon:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        local recipe = current and current.recipe
        if not (recipe and recipe.db and ns.RecipeDB_ShowProductTooltip(self, recipe.id, recipe.db)) then GameTooltip:Hide() end
    end)
    iconButton:SetScript("OnLeave", GameTooltip_Hide)
    iconButton:SetScript("OnClick", function()
        local recipe = current and current.recipe
        if recipe and recipe.link and IsModifiedClick and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(recipe.link) end
    end)

    panel.name = panel:CreateFontString(nil, "OVERLAY", FONT_HEAD)
    panel.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 14, -2)
    panel.name:SetWidth(WIDTH - MARGIN * 2 - 72 - 14 - 26)
    panel.name:SetJustifyH("LEFT")
    panel.name:SetWordWrap(true)
    panel.name:SetMaxLines(2)
    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", FONT_BODY)
    panel.subtitle:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMRIGHT", 14, 2)
    panel.subtitle:SetTextColor(0.7, 0.7, 0.7)
    panel.subtitle:SetJustifyH("LEFT")
    panel.status = panel:CreateFontString(nil, "OVERLAY", FONT_BODY)
    panel.status:SetPoint("TOPLEFT", iconFrame, "BOTTOMLEFT", 0, -12)
    panel.status:SetJustifyH("LEFT")

    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -(MARGIN + 72 + 44))
    separator:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    separator:SetHeight(1)
    separator:SetColorTexture(1, 0.82, 0, 0.5)

    -- (the bar is only there when the content is taller than the frame)
    panel.scroll, panel.child = ns.AutoScroll_Create(panel, function(withBar, scroll)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", MARGIN, -(MARGIN + 72 + 58))
        scroll:SetPoint("BOTTOMRIGHT", withBar and -SCROLL_W or -MARGIN, MARGIN + 38)
    end)

    -- crafting: a button that opens the game's profession window on the recipe, and how many the bags allow
    panel.craftBar = CreateFrame("Frame", nil, panel)
    panel.craftBar:SetPoint("BOTTOMLEFT", MARGIN, MARGIN - 2)
    panel.craftBar:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN - 2)
    panel.craftBar:SetHeight(28)
    panel.craftButton = CreateFrame("Button", nil, panel.craftBar, "UIPanelButtonTemplate")
    panel.craftButton:SetSize(150, 26)
    panel.craftButton:SetPoint("LEFT", 0, 0)
    panel.craftButton:SetText(L["Craft"])
    panel.craftButton:SetScript("OnClick", function()
        local recipe = current and current.recipe
        if recipe then ns.Craft_Open(recipe.id, recipe.db and recipe.db.s) end
    end)
    panel.craftButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Craft"], 1, 1, 1)
        GameTooltip:AddLine(L["Opens the game's profession window on this recipe."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    panel.craftButton:SetScript("OnLeave", GameTooltip_Hide)
    ns.Craft_Secure(panel.craftButton) -- (Classic clients only)
    panel.craftInfo = panel.craftBar:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    panel.craftInfo:SetPoint("LEFT", panel.craftBar, "LEFT", 162, 0)
    panel.craftBar:Hide()

    -- the bags changed (a craft used the ingredients up): the counts follow
    local bags = CreateFrame("Frame")
    bags:RegisterEvent("BAG_UPDATE_DELAYED")
    bags:SetScript("OnEvent", function()
        if panel:IsShown() then updateCraftBar() end
    end)

    -- item names arrive late: draw again once (a burst of them makes one redraw)
    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local waiting = false
    events:SetScript("OnEvent", function()
        if waiting or not panel:IsShown() then return end
        waiting = true
        C_Timer.After(0.3, function()
            waiting = false
            if panel:IsShown() then
                local offset = panel.scroll:GetVerticalScroll()
                render()
                panel.scroll:SetVerticalScroll(offset)
            end
        end)
    end)

    panel:SetScript("OnHide", function()
        local onClose = current and current.opts and current.opts.onClose
        current = nil
        if onClose then onClose() end
    end)
    tinsert(UISpecialFrames, "FabrikaoDetailFrame")
    panel:Hide()
end

-- Docks the panel to the window's right side, or to its left when there is no room on the right.
local function dock(window)
    panel:ClearAllPoints()
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local room = (UIParent:GetRight() or 0) - (window:GetRight() or 0) * scale
    if room >= WIDTH * scale or (window:GetLeft() or 0) * scale < WIDTH * scale then
        panel:SetPoint("TOPLEFT", window, "TOPRIGHT", -4, 0)
        panel:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", -4, 0)
    else
        panel:SetPoint("TOPRIGHT", window, "TOPLEFT", 4, 0)
        panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 4, 0)
    end
end

-- Opens the panel with a recipe (or fills it again when it is open).
function ns.RecipeDetail_Show(recipe, opts)
    opts = opts or {}
    local window = opts.parent or _G.FabrikaoFrame
    if not window then return end
    if ns.Trainers_Hide then ns.Trainers_Hide() end -- the same place
    if not panel then create(window) end
    panel:SetScale(window:GetScale())
    dock(window)
    -- what was opened under the ingredients stays while the same recipe is filled again
    local expanded = current and current.recipe and recipe and current.recipe.id == recipe.id and current.expanded or {}
    current = { recipe = recipe, opts = opts, expanded = expanded }
    render()
    panel:Show()
end

-- Opens or closes where to get an ingredient, under its row; false when no recipe is open.
function ns.RecipeDetail_ToggleReagent(itemID)
    if not (panel and current and current.expanded and itemID) then return false end
    current.expanded[itemID] = not current.expanded[itemID] or nil
    local offset = panel.scroll:GetVerticalScroll()
    render()
    panel.scroll:SetVerticalScroll(offset)
    return true
end

-- Is where to get the ingredient open?
function ns.RecipeDetail_ReagentOpen(itemID)
    return current ~= nil and current.expanded ~= nil and current.expanded[itemID] == true
end

function ns.RecipeDetail_Hide()
    if panel and panel:IsShown() then panel:Hide() end
    current = nil
end

-- The recipe it shows, or nil when closed.
function ns.RecipeDetail_Current()
    return panel and panel:IsShown() and current and current.recipe or nil
end
