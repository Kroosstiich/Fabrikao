local _, ns = ...
local L = ns.L

-- The two rows of filters and sorting of the recipe pages (the profession's page and the search of every recipe): a row
-- of checkboxes ("can make now", "hide grey") with "Clear", and a row of dropdowns like the ones of the game's options
-- (source, category, color, skill, sort). The page owns the filters table:
--   { canMake = bool, hideGrey = bool, alts = bool (count the other characters' items too), difficulty = 0..3 or nil, skill = "learnable" | "higher" | nil,
--     sort = { key =, desc = } or nil, source = a source code or nil, category = a category name or nil }
-- and gets onChange() after every change.

-- the value after `current` in `values` (a list that may start with nil: "no filter"), wrapping around
function ns.FilterBar_NextValue(values, count, current)
    for i = 1, count do
        if values[i] == current then return values[i % count + 1] end
    end
    return values[1]
end

local function difficultyLabel(difficulty)
    if difficulty == nil then return L["All"] end
    local c = ns.DIFFICULTY_COLORS[difficulty]
    local names = { [0] = L["orange"], L["yellow"], L["green"], L["grey"] }
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), names[difficulty])
end

local function skillLabel(mode)
    return mode == "learnable" and L["Learnable now"] or mode == "higher" and L["Needs more skill"] or L["All"]
end

local function sortName(key)
    return ({ name = L["Name"], level = L["Level"], cost = L["Cost"], value = L["AH value"], craftable = L["Can make"] })[key]
end

local function sortLabel(sort)
    if not sort then return L["Default"] end
    return sortName(sort.key) .. (sort.desc and " v" or " ^")
end

-- Nothing filtered, nothing sorted.
function ns.FilterBar_Reset(filters)
    filters.canMake, filters.hideGrey, filters.alts = false, false, false
    filters.difficulty, filters.skill, filters.sort, filters.source, filters.category = nil, nil, nil, nil, nil
end

-- Is anything filtered? (not the sorting)
function ns.FilterBar_Active(filters)
    return filters.canMake or filters.hideGrey or filters.difficulty ~= nil or filters.skill ~= nil or filters.source ~= nil
        or filters.category ~= nil
end

-- A click on a column title or on the sort button's key: sorts by it, or turns the order around when it already is.
function ns.FilterBar_SortBy(filters, key)
    if filters.sort and filters.sort.key == key then
        filters.sort = { key = key, desc = not filters.sort.desc }
    else
        filters.sort = { key = key, desc = key == "craftable" or key == "value" }
    end
end

local function createCheck(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.text = check.Text or check.text
    if check.text then check.text:SetText(label) end
    check:SetScript("OnClick", onClick)
    return check
end

-- A picker of one of several values. In the game it is the dropdown of the options screens (a menu with a radio button per value);
-- without the menu templates it is a button that goes to the next value on a click. config = { width =,
-- options = function() returning { { value =, text = }... } (the first is "no filter"), get = function() the current value,
-- set = function(value), text = function() the text to show, extra = function(rootDescription) (more menu entries, optional),
-- altClick = function() returning true when it handled a right click on the button (optional) }. Returns { frame =, Update = function() }.
local function createPicker(parent, config)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu and dropdown.GenerateMenu then
        dropdown:SetWidth(config.width)
        -- the text comes from the filters, not from the selected entry: a filter of a value the list lacks still shows
        if dropdown.SetSelectionTranslator then dropdown:SetSelectionTranslator(function() return config.text() end) end
        dropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(config.options()) do
                rootDescription:CreateRadio(option.text, function() return config.get() == option.value end,
                    function() config.set(option.value) end)
            end
            if config.extra then config.extra(rootDescription) end
        end)
        return { frame = dropdown, Update = function()
            if dropdown.SetDefaultText then dropdown:SetDefaultText(config.text()) end
            -- An open menu is rebuilt in place, and rebuilt from here it is tainted: with the gamepad UI on, the game then blocks
            -- the addon when that menu closes and hands the controls back. The game updates an open dropdown itself after a pick
            -- and builds the menu again every time it opens, so an open one is left alone.
            if dropdown.IsMenuOpen and dropdown:IsMenuOpen() then return end
            dropdown:GenerateMenu()
        end }
    end
    if ok and dropdown then dropdown:Hide() end
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(config.width, 22)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" and config.altClick and config.altClick() then return end
        local options, current = config.options(), config.get()
        for i, option in ipairs(options) do
            if option.value == current then
                config.set(options[i % #options + 1].value)
                return
            end
        end
        config.set(options[1] and options[1].value)
    end)
    return { frame = button, Update = function() button:SetText(config.text()) end }
end

ns.FilterBar_CreatePicker = createPicker -- (the professions page's character picker is one too)

local function createButton(parent, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetScript("OnClick", onClick)
    return button
end

-- the entries of a picker for a list of { value, text }: "All" first
local function withAll(list)
    table.insert(list, 1, { value = nil, text = L["All"] })
    return list
end

-- Builds the rows under `anchor` (a frame of the page). config = { filters =, sources = function() returning the set of
-- source codes there are to pick from, categories = function() returning the set of category names, onChange = function(),
-- onClear = function() (optional, also on "Clear"), x = where the rows start, relative to the anchor's left (-6 by default) }.
-- Returns the bar: .checks and .buttons (the two rows: anchor what comes next to .buttons, and add widgets to .checks, to the left
-- of .clearButton), and .Update() to show the filters in the controls.
function ns.FilterBar_Create(parent, anchor, config)
    local filters = config.filters
    local bar = {}

    local function changed()
        bar.Update()
        config.onChange()
    end

    local checks = CreateFrame("Frame", nil, parent)
    checks:SetHeight(26)
    checks:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", config.x or -6, -4)
    checks:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bar.checks = checks
    bar.canMakeCheck = createCheck(checks, L["Can make now"], function(self)
        filters.canMake = self:GetChecked() and true or false
        changed()
    end)
    bar.canMakeCheck:SetPoint("LEFT", 0, 0)
    bar.hideGreyCheck = createCheck(checks, L["Hide grey"], function(self)
        filters.hideGrey = self:GetChecked() and true or false
        changed()
    end)
    local width = bar.canMakeCheck.text and bar.canMakeCheck.text:GetStringWidth() or 90
    bar.hideGreyCheck:SetPoint("LEFT", bar.canMakeCheck, "RIGHT", width + 14, 0)
    -- the items of the other characters count too (Embolsao's copies): only offered when there are any
    bar.altsCheck = createCheck(checks, L["Other characters"], function(self)
        filters.alts = self:GetChecked() and true or false
        changed()
    end)
    width = bar.hideGreyCheck.text and bar.hideGreyCheck.text:GetStringWidth() or 90
    bar.altsCheck:SetPoint("LEFT", bar.hideGreyCheck, "RIGHT", width + 14, 0)
    bar.altsCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Other characters"], 1, 1, 1)
        GameTooltip:AddLine(L["Count the bags and banks of your other characters too (saved by Embolsao)."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    bar.altsCheck:SetScript("OnLeave", GameTooltip_Hide)

    bar.clearButton = createButton(checks, 70, function()
        ns.FilterBar_Reset(filters)
        if config.onClear then config.onClear() end
        changed()
    end)
    bar.clearButton:SetPoint("RIGHT", 0, 0)
    bar.clearButton:SetText(L["Clear"])

    local buttons = CreateFrame("Frame", nil, parent)
    buttons:SetHeight(28)
    buttons:SetPoint("TOPLEFT", checks, "BOTTOMLEFT", 0, -2)
    buttons:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bar.buttons = buttons

    local pickers = {}
    local function addPicker(pickerConfig, after)
        local picker = createPicker(buttons, pickerConfig)
        picker.frame:SetPoint("LEFT", after or buttons, after and "RIGHT" or "LEFT", after and 4 or 0, 0)
        pickers[#pickers + 1] = picker
        return picker
    end
    local function applied(key) return function(value) filters[key] = value; changed() end end

    local source = addPicker({
        width = 100,
        options = function()
            local codes = {}
            for code in pairs(config.sources() or {}) do codes[#codes + 1] = code end
            table.sort(codes)
            local list = {}
            for _, code in ipairs(codes) do list[#list + 1] = { value = code, text = ns.Recipes_SourceLabel(code) } end
            return withAll(list)
        end,
        get = function() return filters.source end,
        set = applied("source"),
        text = function() return L["Source: %s"]:format(filters.source and ns.Recipes_SourceLabel(filters.source) or L["All"]) end,
    })
    bar.sourceButton = source.frame

    local category = addPicker({
        width = 125,
        options = function()
            local names = {}
            for name in pairs(config.categories and config.categories() or {}) do names[#names + 1] = name end
            table.sort(names)
            local list = {}
            for _, name in ipairs(names) do list[#list + 1] = { value = name, text = name } end
            return withAll(list)
        end,
        get = function() return filters.category end,
        set = applied("category"),
        text = function() return L["Category: %s"]:format(filters.category or L["All"]) end,
    }, source.frame)
    bar.categoryButton = category.frame

    local color = addPicker({
        width = 100,
        options = function()
            local list = {}
            for _, difficulty in ipairs({ 0, 1, 2, 3 }) do list[#list + 1] = { value = difficulty, text = difficultyLabel(difficulty) } end
            return withAll(list)
        end,
        get = function() return filters.difficulty end,
        set = applied("difficulty"),
        text = function() return L["Color: %s"]:format(difficultyLabel(filters.difficulty)) end,
    }, category.frame)
    bar.colorButton = color.frame

    local skill = addPicker({
        width = 135,
        options = function()
            return withAll({ { value = "learnable", text = skillLabel("learnable") }, { value = "higher", text = skillLabel("higher") } })
        end,
        get = function() return filters.skill end,
        set = applied("skill"),
        text = function() return filters.skill and skillLabel(filters.skill) or L["Skill: %s"]:format(L["All"]) end,
    }, color.frame)
    bar.skillButton = skill.frame

    local function turnSortAround()
        if filters.sort then
            filters.sort = { key = filters.sort.key, desc = not filters.sort.desc }
            changed()
            return true
        end
    end
    local sort = addPicker({
        width = 125,
        options = function()
            local list = { { value = nil, text = L["Default"] } }
            for _, key in ipairs({ "name", "level", "cost", "value", "craftable" }) do
                list[#list + 1] = { value = key, text = sortName(key) }
            end
            return list
        end,
        get = function() return filters.sort and filters.sort.key end,
        set = function(key)
            filters.sort = key and { key = key, desc = key == "craftable" or key == "value" } or nil
            changed()
        end,
        text = function() return L["Sort: %s"]:format(sortLabel(filters.sort)) end,
        extra = function(rootDescription)
            rootDescription:CreateDivider()
            rootDescription:CreateCheckbox(L["Descending"], function() return filters.sort ~= nil and filters.sort.desc == true end, turnSortAround)
        end,
        altClick = turnSortAround, -- (the button: a right click turns the order around)
    }, skill.frame)
    bar.sortButton = sort.frame

    function bar.Update()
        bar.canMakeCheck:SetChecked(filters.canMake)
        bar.hideGreyCheck:SetChecked(filters.hideGrey)
        bar.altsCheck:SetChecked(filters.alts)
        bar.altsCheck:SetShown(ns.Inventory_Available and ns.Inventory_Available() or false)
        for _, picker in ipairs(pickers) do picker.Update() end
    end
    bar.Update()
    return bar
end
