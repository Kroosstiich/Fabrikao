local _, ns = ...
local L = ns.L

-- The scrolling list of recipes of a profession page, in the two views the player can choose in the preferences:
--   table     columns: icon, name, components (the ingredients' icons, with their tooltips), approximate cost, approximate
--             auction value, level; the headers sort
--   detailed  a big icon and three lines of information per recipe
-- ns.RecipeList_Create(parent) builds it; ns.RecipeList_Set(rows, view, sort) draws the rows of ns.Recipes_Rows.

local VIEWS = {
    table = { height = 24, icon = 20 },
    detailed = { height = 58, icon = 44 },
}
local HEADER_ROW_H = 24 -- the "Known recipes (38)" rows
local COLUMN_H = 22 -- the column titles of the table view
local FIXED = { cost = 90, value = 90, level = 52 } -- widths of the numeric columns
local GAP = 8
local ICON_X = 6
local COMP_ICON, COMP_GAP = 20, 3 -- the ingredient icons of the table's components column
local DETAIL_COMP_ICON = 16 -- and of the detailed view's third line

local MIN_VISIBLE_HEIGHT = 600 -- rows are made for at least this much height (the scroll frame can still say 0 before it is laid out)
local list, rows, view, sort, onSort, onToggle, onSelect, selectedID
local tops, total = {}, 0 -- where each row starts (from the top of the content) and how tall they all are
local rowButtons = {}
local columnButtons = {}

---------------------------------------------------------------------------------------------------
-- Text of a row
---------------------------------------------------------------------------------------------------
local function itemName(itemID)
    return ns.ItemName(itemID) or L["item %d"]:format(itemID)
end

-- how many of an item: the bags' (and with `alts`, everything the account has)
local function itemCount(itemID, alts)
    if ns.Inventory_Count then return ns.Inventory_Count(itemID, alts) end
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    return count(itemID) or 0
end

-- "2x Peacebloom, 1x Silverleaf"; with `have`, each ingredient the bags cover is green and the others red
local function componentsText(recipe, have, alts)
    if not recipe.reagents or #recipe.reagents == 0 then return "-" end
    local parts = {}
    for _, reagent in ipairs(recipe.reagents) do
        local itemID = reagent.items[1]
        local text = ("%dx %s"):format(reagent.quantity, itemName(itemID))
        if have then
            local owned = 0
            for _, id in ipairs(reagent.items) do owned = owned + itemCount(id, alts) end
            text = ("%s%s|r"):format(owned >= reagent.quantity and "|cff40bf40" or "|cffff6060", text)
        end
        parts[#parts + 1] = text
    end
    return table.concat(parts, ", ")
end

local function money(copper, incomplete)
    if not copper then return "-" end
    return ns.FormatMoney(copper) .. (incomplete and "+" or "")
end

-- the skill the recipe needs, in the color it has for the character: red when the skill isn't enough yet
local function levelText(recipe, rank)
    if not recipe.required then return "-" end
    local color
    if recipe.learned then
        color = ns.DIFFICULTY_COLORS[recipe.difficulty or ns.DIFFICULTY_LAST]
    elseif rank and recipe.required > rank then
        color = { 1, 0.3, 0.3 }
    elseif rank and recipe.db then
        color = ns.DIFFICULTY_COLORS[ns.RecipeDB_Difficulty(recipe.db, rank)]
    else
        color = { 0.85, 0.85, 0.85 }
    end
    return ("|cff%02x%02x%02x%d|r"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), recipe.required)
end

local function sourceText(recipe)
    return recipe.db and ns.RecipeDB_ShortSource(recipe.db) or ns.Recipes_SourceLabel(recipe.sourceType)
end

---------------------------------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------------------------------
local function showRecipeTooltip(row)
    local data = row.data
    if not data or data.kind ~= "recipe" then return end
    local recipe = data.recipe
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local shown = recipe.link and pcall(GameTooltip.SetHyperlink, GameTooltip, recipe.link)
    if not shown then GameTooltip:SetText(recipe.name, 1, 1, 1) end
    if recipe.colors then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Skill needed: %d"]:format(recipe.required or recipe.colors[1]), 1, 0.82, 0)
        GameTooltip:AddLine(ns.DifficultyColorsText(recipe.colors), 1, 1, 1)
    end
    if recipe.reagents and #recipe.reagents > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Ingredients:"], 1, 0.82, 0)
        GameTooltip:AddLine(componentsText(recipe, true, data.alts), 1, 1, 1, true)
    end
    if data.cost or data.value then
        GameTooltip:AddLine(" ")
        if data.cost then GameTooltip:AddLine(L["Ingredients cost: %s"]:format(money(data.cost, data.incomplete)), 1, 1, 1) end
        if data.value then GameTooltip:AddLine(L["Sells for about: %s"]:format(money(data.value)), 1, 1, 1) end
    end
    if not recipe.learned then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Where to learn it"], 1, 0.82, 0)
        if recipe.db then
            for _, line in ipairs(ns.RecipeDB_Where(recipe.db)) do
                GameTooltip:AddLine(line.title .. ": " .. line.text, 1, 1, 1, true)
            end
        elseif recipe.sourceText and recipe.sourceText ~= "" then
            GameTooltip:AddLine(recipe.sourceText, 1, 1, 1, true)
        else
            GameTooltip:AddLine(ns.Recipes_SourceLabel(recipe.sourceType), 1, 1, 1)
        end
        if not recipe.colors and recipe.trivial and recipe.trivial > 0 then
            GameTooltip:AddLine(L["Turns grey at skill %d"]:format(recipe.trivial), 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------------------------------
-- One ingredient of a recipe as an icon with its count, with the item's tooltip on hover (and how many the bags have).
local function newComponent(row)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(COMP_ICON, COMP_ICON)
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetAllPoints()
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", 1, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) else GameTooltip:SetText(itemName(self.itemID), 1, 1, 1) end
        GameTooltip:AddLine(L["Needs %d, you have %d"]:format(self.quantity, self.owned), 1, 1, 1)
        -- who has it, when there are other characters to tell from (not the ones the tooltip already lists)
        if ns.Inventory_AddTooltipLines then ns.Inventory_AddTooltipLines(GameTooltip, self.itemID) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local info = C_Item and C_Item.GetItemInfo or GetItemInfo
            local link = info and select(2, info(self.itemID))
            if link then ChatEdit_InsertLink(link) end
        else
            local onClick = row:GetScript("OnClick")
            if onClick then onClick(row) end
        end
    end)
    return button
end

local function newRow()
    local b = CreateFrame("Button", nil, list.content)
    b.compIcons = {}
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    for _, key in ipairs({ "info", "comp", "cost", "value", "level", "line2", "line3" }) do
        b[key] = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b[key]:SetWordWrap(false)
    end
    for _, key in ipairs({ "info", "cost", "value", "level" }) do b[key]:SetJustifyH("RIGHT") end
    for _, key in ipairs({ "comp", "line2", "line3" }) do b[key]:SetJustifyH("LEFT") end
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.selected = b:CreateTexture(nil, "BACKGROUND") -- the recipe whose panel is open
    b.selected:SetAllPoints()
    b.selected:SetColorTexture(1, 0.82, 0, 0.16)
    b.selected:Hide()
    b:SetScript("OnEnter", showRecipeTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    -- a click on a recipe: shift-click puts its link in the chat, any other opens its panel
    local function onClick(self)
        local data = self.data
        if not (data and data.kind == "recipe") then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            if data.recipe.link then ChatEdit_InsertLink(data.recipe.link) end
        elseif onSelect then
            onSelect(data)
        end
    end
    b:SetScript("OnClick", function(self)
        local data = self.data
        if data and data.kind == "header" then
            if onToggle then onToggle(data.group) end -- a group's title folds and unfolds it
            return
        end
        onClick(self)
    end)
    -- over the icon: the tooltip of what the recipe makes
    b.iconButton = CreateFrame("Button", nil, b)
    b.iconButton:SetAllPoints(b.icon)
    b.iconButton:SetScript("OnEnter", function(self)
        local data = b.data
        local recipe = data and data.kind == "recipe" and data.recipe
        if not (recipe and recipe.db and ns.RecipeDB_ShowProductTooltip(self, recipe.id, recipe.db)) then showRecipeTooltip(b) end
    end)
    b.iconButton:SetScript("OnLeave", GameTooltip_Hide)
    b.iconButton:SetScript("OnClick", function() onClick(b) end)
    return b
end

-- Where each column of the table goes, for a row `width` wide: { name = { x, w }, comp = ..., cost, value, level }
local function columnsFor(width)
    local left = ICON_X + VIEWS.table.icon + 6
    local fixed = FIXED.cost + FIXED.value + FIXED.level + GAP * 3
    local flex = math.max(160, width - left - 10 - fixed)
    local nameW = math.floor(flex * 0.4)
    local compW = flex - nameW - GAP
    local c = {}
    c.name = { left, nameW }
    c.comp = { left + nameW + GAP, compW }
    c.cost = { c.comp[1] + compW + GAP, FIXED.cost }
    c.value = { c.cost[1] + FIXED.cost + GAP, FIXED.value }
    c.level = { c.value[1] + FIXED.value + GAP, FIXED.level }
    return c
end

local function place(fs, row, x, w, y)
    fs:ClearAllPoints()
    if y then fs:SetPoint("TOPLEFT", row, "TOPLEFT", x, y) else fs:SetPoint("LEFT", row, "LEFT", x, 0) end
    fs:SetWidth(w)
    fs:Show()
end

local function layoutRow(b, data, width)
    for _, key in ipairs({ "info", "comp", "cost", "value", "level", "line2", "line3" }) do b[key]:Hide() end
    for _, icon in ipairs(b.compIcons) do icon:Hide() end
    if b.compMore then b.compMore:Hide() end
    b.text:ClearAllPoints()
    b.text:SetWidth(0) -- the width is the anchors', except in the table
    b.icon:ClearAllPoints()
    if data.kind == "header" then
        b:SetHeight(HEADER_ROW_H)
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("LEFT", b, "LEFT", ICON_X, 0)
        b.text:SetFontObject("GameFontNormal")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        return
    end
    local spec = VIEWS[view]
    b:SetHeight(spec.height)
    b.icon:SetSize(spec.icon, spec.icon)
    if view == "detailed" then
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", ICON_X, -7)
    else
        b.icon:SetPoint("LEFT", b, "LEFT", ICON_X, 0)
    end
    if view == "table" then
        local c = columnsFor(width)
        b.text:SetFontObject("GameFontNormal")
        b.text:SetPoint("LEFT", b, "LEFT", c.name[1], 0)
        b.text:SetWidth(c.name[2])
        place(b.comp, b, c.comp[1], c.comp[2])
        place(b.cost, b, c.cost[1], c.cost[2])
        place(b.value, b, c.value[1], c.value[2])
        place(b.level, b, c.level[1], c.level[2])
    else -- detailed: name, then skill and colors (prices to the right), then components (icons, see showComponents)
        local x = ICON_X + spec.icon + 10
        b.text:SetFontObject("GameFontNormalLarge")
        b.text:SetPoint("TOPLEFT", b, "TOPLEFT", x, -5)
        b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        b.info:ClearAllPoints()
        b.info:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -24)
        b.info:SetWidth(0)
        b.info:Show()
        place(b.line2, b, x, math.max(60, width - x - 200), -24)
    end
end

-- The ingredients of a recipe as icons (as many as fit in `w`, then "+n"), from `x` on: in the table's components column (centered
-- vertically in the row) and on the detailed view's third line (`top` is where it starts). "-" in `dash` without ingredients. On
-- a recipe the character knows, an ingredient the bags don't cover is tinted red.
local function showComponents(b, recipe, alts, x, w, size, top, dash)
    local reagents = recipe.reagents
    if not reagents or #reagents == 0 then
        dash:SetText("-")
        dash:Show()
        return
    end
    dash:Hide()
    local fit = math.max(1, math.floor((w + COMP_GAP) / (size + COMP_GAP)))
    local shown = #reagents <= fit and #reagents or fit - 1 -- the last slot is for the "+n"
    for i = 1, shown do
        local reagent = reagents[i]
        local icon = b.compIcons[i]
        if not icon then
            icon = newComponent(b)
            b.compIcons[i] = icon
        end
        local itemID = reagent.items[1]
        local owned = 0
        for _, id in ipairs(reagent.items) do owned = owned + itemCount(id, alts) end
        icon.itemID, icon.quantity, icon.owned = itemID, reagent.quantity, owned
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        if top then
            icon:SetPoint("TOPLEFT", b, "TOPLEFT", x + (i - 1) * (size + COMP_GAP), top)
        else
            icon:SetPoint("LEFT", b, "LEFT", x + (i - 1) * (size + COMP_GAP), 0)
        end
        icon.texture:SetTexture(ns.ItemIcon(itemID) or 134400)
        if recipe.learned and owned < reagent.quantity then
            icon.texture:SetVertexColor(1, 0.35, 0.35)
        else
            icon.texture:SetVertexColor(1, 1, 1)
        end
        icon.count:SetText(reagent.quantity > 1 and tostring(reagent.quantity) or "")
        icon:Show()
    end
    if shown < #reagents then
        if not b.compMore then
            b.compMore = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        end
        b.compMore:ClearAllPoints()
        if top then
            b.compMore:SetPoint("TOPLEFT", b, "TOPLEFT", x + shown * (size + COMP_GAP), top - 3)
        else
            b.compMore:SetPoint("LEFT", b, "LEFT", x + shown * (size + COMP_GAP), 0)
        end
        b.compMore:SetText(("+%d"):format(#reagents - shown))
        b.compMore:Show()
    end
end

local function renderRow(b, data, width)
    b.data = data
    layoutRow(b, data, width)
    b.selected:SetShown(data.kind == "recipe" and data.recipe.id == selectedID)
    if data.kind == "header" then
        -- a plus when it is folded, a minus when it is open
        b.icon:SetTexture(data.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        b.icon:Show()
        b.iconButton:Hide()
        b.text:SetText(("%s (%d)"):format(data.text, data.count))
        b.text:SetTextColor(1, 0.82, 0)
        b:EnableMouse(true)
        return
    end
    local recipe = data.recipe
    b:EnableMouse(true)
    b.icon:Show()
    b.iconButton:Show()
    b.icon:SetTexture(recipe.icon)

    local color = recipe.learned and ns.DIFFICULTY_COLORS[recipe.difficulty or ns.DIFFICULTY_LAST] or { 0.85, 0.85, 0.85 }
    local name = (recipe.learned and data.craftable > 0) and ("%s (%d)"):format(recipe.name, data.craftable) or recipe.name
    b.text:SetText(name)
    b.text:SetTextColor(color[1], color[2], color[3])

    if view == "table" then
        local c = columnsFor(width).comp
        showComponents(b, recipe, data.alts, c[1], c[2], COMP_ICON, nil, b.comp)
        b.cost:SetText(money(data.cost, data.incomplete))
        b.value:SetText(money(data.value))
        b.level:SetText(levelText(recipe, list.rank or recipe.rank))
    else
        local parts = {}
        if recipe.required then parts[#parts + 1] = L["Skill %d"]:format(recipe.required) end
        if recipe.colors then parts[#parts + 1] = ns.DifficultyColorsText(recipe.colors) end
        parts[#parts + 1] = recipe.learned and L["Known"] or sourceText(recipe)
        b.line2:SetText(table.concat(parts, "   "))
        b.info:SetText(L["Cost %s   AH %s"]:format(money(data.cost, data.incomplete), money(data.value)))
        local x = ICON_X + VIEWS.detailed.icon + 10
        showComponents(b, recipe, data.alts, x, math.max(60, width - x - 12), DETAIL_COMP_ICON, -39, b.line3)
        if #(recipe.reagents or {}) == 0 then place(b.line3, b, x, 60, -40) end
    end
end

local function heightOf(data)
    if data.kind == "header" then return HEADER_ROW_H end
    return VIEWS[view].height
end

-- The bar of the scroll is there only when the rows are taller than it; the page that has the list places it (and the column titles)
-- as a function of that. The width that changes redraws the rows, as any other change of width.
local function updateBar()
    if not list then return end
    local need = total > (list.scroll:GetHeight() or 0) + 1
    if list.withBar == need then return end
    list.withBar = need
    if list.scroll.ScrollBar and list.scroll.ScrollBar.SetShown then list.scroll.ScrollBar:SetShown(need) end
    if list.place then list.place(need) end
    if not need then list.scroll:SetVerticalScroll(0) end
end

-- Where each row starts and how tall they all are: the scroll's content is that tall, but only the rows in view exist as frames.
local function computeTops()
    tops, total = {}, 0
    for i, data in ipairs(rows) do
        tops[i] = total
        total = total + heightOf(data)
    end
    list.content:SetHeight(math.max(1, total))
    updateBar()
end

-- The first row that ends below `offset` (binary search over the tops).
local function firstVisible(offset)
    local low, high = 1, #rows
    while low < high do
        local middle = math.floor((low + high) / 2)
        if tops[middle] + heightOf(rows[middle]) <= offset then low = middle + 1 else high = middle end
    end
    return low
end

-- Draws the rows in view -- a few dozen frames, reused as the list scrolls -- instead of one per recipe: with hundreds of
-- recipes, laying out a frame per row made resizing and filtering crawl.
local function draw()
    if not list then return end
    local width = list.content:GetWidth()
    local offset = list.scroll:GetVerticalScroll() or 0
    local limit = offset + math.max(list.scroll:GetHeight() or 0, MIN_VISIBLE_HEIGHT)
    local used = 0
    local index = #rows > 0 and firstVisible(offset) or 1
    while index <= #rows and tops[index] < limit do
        used = used + 1
        local b = rowButtons[used] or newRow()
        rowButtons[used] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -tops[index])
        b:SetPoint("RIGHT", list.content, "RIGHT", 0, 0)
        renderRow(b, rows[index], width)
        b:Show()
        index = index + 1
    end
    for i = used + 1, #rowButtons do rowButtons[i]:Hide() end
end

---------------------------------------------------------------------------------------------------
-- Column titles (table view)
---------------------------------------------------------------------------------------------------
local COLUMN_TITLES = {
    { key = "name", sort = "name" },
    { key = "comp" },
    { key = "cost", sort = "cost" },
    { key = "value", sort = "value" },
    { key = "level", sort = "level" },
}

local function columnTitle(key)
    return ({ name = L["Name"], comp = L["Components"], cost = L["Cost"], value = L["AH value"], level = L["Level"] })[key]
end

local function updateColumnHeader()
    if not list then return end
    local isTable = view == "table"
    list.header:SetHeight(isTable and COLUMN_H or 1)
    list.header:SetShown(isTable)
    if not isTable then return end
    local c = columnsFor(list.content:GetWidth())
    for i, col in ipairs(COLUMN_TITLES) do
        local b = columnButtons[i]
        if not b then
            b = CreateFrame("Button", nil, list.header)
            b:SetHeight(COLUMN_H)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.text:SetAllPoints()
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b:SetScript("OnClick", function(self)
                if self.sortKey and onSort then onSort(self.sortKey) end
            end)
            columnButtons[i] = b
        end
        b.sortKey = col.sort
        b:ClearAllPoints()
        b:SetPoint("LEFT", list.header, "LEFT", c[col.key][1], 0)
        b:SetWidth(c[col.key][2])
        b.text:SetJustifyH((col.key == "name" or col.key == "comp") and "LEFT" or "RIGHT")
        local arrow = ""
        if sort and col.sort and sort.key == col.sort then arrow = sort.desc and " v" or " ^" end
        b.text:SetText(columnTitle(col.key) .. arrow)
        b:Show()
    end
end

---------------------------------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------------------------------
-- The width changes at every step of a resize drag: laying out and redrawing every row each time froze the game. While the width keeps
-- changing only the content's width follows (the rows are anchored to it and stretch by themselves); the redraw of the rows --
-- the table's columns, the icons that fit -- happens once, when the width has stopped changing.
local REDRAW_DELAY = 0.1
local function followWidth()
    updateBar() -- (the height may have changed with the window)
    list.content:SetWidth(math.max(100, list.scroll:GetWidth()))
    list.widthChanges = (list.widthChanges or 0) + 1
    if list.redrawWaiting then return end
    list.redrawWaiting = true
    local seen = list.widthChanges
    local function settle()
        if list.widthChanges ~= seen then -- it changed again while waiting: wait some more
            seen = list.widthChanges
            C_Timer.After(REDRAW_DELAY, settle)
            return
        end
        list.redrawWaiting = false
        list.content:SetWidth(math.max(100, list.scroll:GetWidth()))
        updateColumnHeader()
        draw()
    end
    C_Timer.After(REDRAW_DELAY, settle)
end

function ns.RecipeList_Create(parent, onSortCallback, onToggleCallback, onSelectCallback)
    onSort = onSortCallback
    onToggle = onToggleCallback
    onSelect = onSelectCallback -- (given the data of the row: { recipe =, craftable =, cost =, value =, alts = })
    list = {}
    list.header = CreateFrame("Frame", nil, parent)
    list.header:SetHeight(1)
    list.scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    list.content = CreateFrame("Frame", nil, list.scroll)
    list.content:SetSize(600, 1)
    list.scroll:SetScrollChild(list.content)
    list.scroll:SetScript("OnSizeChanged", followWidth)
    list.scroll:HookScript("OnVerticalScroll", function() draw() end) -- the rows in view change as it scrolls

    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local pending = false
    events:SetScript("OnEvent", function()
        if pending or not list.scroll:IsVisible() then return end
        pending = true -- item names arrive in a burst: one redraw for all
        C_Timer.After(0.3, function()
            pending = false
            draw()
        end)
    end)

    view, rows = "table", {}
    return list
end

-- The list is one for the whole window: the page that shows (a profession's, the search) takes it with its own callbacks, and
-- places it. Returns the list ({ header =, scroll =, content = }).
function ns.RecipeList_Attach(parent, onSortCallback, onToggleCallback, onSelectCallback)
    if not list then return end
    onSort, onToggle, onSelect = onSortCallback, onToggleCallback, onSelectCallback
    selectedID = nil
    list.header:SetParent(parent)
    list.scroll:SetParent(parent)
    return list
end

-- (A click on the title of a group, "Known recipes (38)", calls onToggleCallback(group).)
-- Draws the rows of ns.Recipes_Rows in a view ("table" or "detailed"); `currentSort` marks the sorted column;
-- `rank` is the character's skill in the profession.
function ns.RecipeList_Set(newRows, newView, currentSort, rank)
    if not list then return end
    rows, view, sort = newRows or {}, VIEWS[newView] and newView or "table", currentSort
    list.rank = rank
    updateColumnHeader()
    computeTops()
    -- fewer rows than before: the scroll can't be left past the end
    local beyond = (list.scroll:GetVerticalScroll() or 0) - math.max(0, total - (list.scroll:GetHeight() or 0))
    if beyond > 0 then list.scroll:SetVerticalScroll(math.max(0, total - (list.scroll:GetHeight() or 0))) end
    draw()
end

-- Where the page puts the list: placeFn(withBar) anchors the column titles and the scroll, with room for the bar or without it. It is
-- called now and again whenever the bar comes or goes.
function ns.RecipeList_Place(placeFn)
    if not list then return end
    list.place = placeFn
    list.withBar = list.withBar == nil and true or list.withBar
    placeFn(list.withBar)
end

-- Marks the recipe (by id) whose panel is open; nil for none.
function ns.RecipeList_Select(id)
    selectedID = id
    draw()
end

-- The window changed size: the rows follow once it has settled (see followWidth).
function ns.RecipeList_Relayout()
    if not list then return end
    followWidth()
end

-- how tall the column titles are, to place the scroll under them
function ns.RecipeList_HeaderFrame()
    return list and list.header
end
