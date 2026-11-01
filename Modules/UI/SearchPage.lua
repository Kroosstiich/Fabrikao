local _, ns = ...
local L = ns.L

-- Page of the main window that searches every recipe in the game's data (also the ones of professions the
-- character doesn't have). The matches are listed like those of a profession's page (the same list, in the table or
-- detailed view, with the same filters and sorting) and a click on one opens its panel next to the window.

local MAX_RESULTS = 300
local VIEW_NAMES = { "table", "detailed" }

local page, window
local state = { skill = nil, results = {}, truncated = 0, total = 0, sources = {}, categories = {} }
local filters = {} -- the filters of the page (FilterBar.lua), kept for the next time in ns.char.searchFilters

local function knows(spellID)
    if ns.Roster_Knows then return ns.Roster_Knows(spellID) end
    return ns.RecipeDB_Known(spellID)
end

-- skill line -> { rank, maxRank } of the character's professions
local function myProfessions()
    local mine = {}
    for _, p in ipairs(ns.Professions_List()) do mine[p.skillLine] = p end
    return mine
end

-- an item's name, or a placeholder while the client loads it (GET_ITEM_INFO_RECEIVED redraws)
local function itemName(itemID)
    return ns.ItemName(itemID) or L["item %d"]:format(itemID)
end

local function viewName()
    local view = ns.char.view
    for _, name in ipairs(VIEW_NAMES) do if name == view then return view end end
    return "table"
end

local function viewLabel(view)
    return ({ table = L["Table"], detailed = L["Detailed"] })[view]
end

local function updateCount()
    local count
    if state.total == 0 then
        local browse = state.skill ~= nil or state.ingredient ~= nil or ns.FilterBar_Active(filters)
        count = (page.search:GetText() == "" and not browse) and L["Type to search every recipe."] or L["No recipes found"]
    elseif state.truncated > 0 then
        count = L["%d recipes (showing the first %d)"]:format(state.total, MAX_RESULTS)
    elseif state.ingredient then
        count = L["%d recipes using %s"]:format(state.total, itemName(state.ingredient))
    else
        count = L["%d recipes"]:format(state.total)
    end
    page.count:SetText(count)
end

---------------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------------
local function saveFilters()
    ns.char.searchFilters = {
        canMake = filters.canMake, hideGrey = filters.hideGrey, alts = filters.alts,
        difficulty = filters.difficulty, skill = filters.skill, sort = filters.sort,
    }
end

local function loadFilters()
    local saved = ns.char.searchFilters or {}
    filters.canMake = saved.canMake and true or false
    filters.hideGrey = saved.hideGrey and true or false
    filters.alts = saved.alts and true or false
    filters.difficulty, filters.skill, filters.sort = saved.difficulty, saved.skill, saved.sort
    filters.source, filters.category = nil, nil
end

-- every source code and category of the data, for those filters before anything is listed
local allSources, allCategories
local function listAll()
    if not allSources then
        allSources, allCategories = {}, {}
        for _, recipe in ns.RecipeDB_Each() do
            for _, code in ipairs(ns.RecipeDB_Sources(recipe)) do allSources[code] = true end
            allCategories[ns.RecipeDB_Category(recipe)] = true
        end
    end
    return allSources, allCategories
end

local function refresh()
    if not page then return end
    local text = page.search:GetText()
    -- with filters on and no text, everything that passes them is listed
    local browse = state.skill ~= nil or state.ingredient ~= nil or ns.FilterBar_Active(filters)
    local found = ns.RecipeDB_Search(text, { skill = state.skill, all = browse, ingredient = state.ingredient })

    -- the recipes as the lists see them (known or not, colored for the character's skill in each profession), so the
    -- filters of the profession's page work here too
    local mine = myProfessions()
    local objects = {}
    state.sources, state.categories = {}, {}
    for _, result in ipairs(found) do
        local profession = mine[result.recipe.s]
        local object = ns.Recipes_FromRecord(result.id, result.recipe, knows(result.id), profession and profession.rank)
        objects[#objects + 1] = object
        if object.sourceType then state.sources[object.sourceType] = true end
        if object.category then state.categories[object.category] = true end
    end
    if not browse then state.sources, state.categories = listAll() end
    local results = ns.Recipes_Rows({ all = objects }, {
        flat = true, source = filters.source, category = filters.category, difficulty = filters.difficulty, canMake = filters.canMake,
        hideGrey = filters.hideGrey, skill = filters.skill, sort = filters.sort,
        alts = filters.alts and ns.Inventory_Available and ns.Inventory_Available(),
    })
    state.total = #results
    state.truncated = math.max(0, state.total - MAX_RESULTS)
    for i = state.total, MAX_RESULTS + 1, -1 do results[i] = nil end
    state.results = results

    ns.RecipeList_Set(results, viewName(), filters.sort)
    updateCount()
    page.viewButton:SetText(L["View: %s"]:format(viewLabel(viewName())))
    page.filterBar.Update()

    -- the panel of a recipe that is no longer in the list closes
    local open = ns.RecipeDetail_Current()
    if open then
        local present = false
        for _, row in ipairs(results) do
            if row.recipe.id == open.id then present = true break end
        end
        if not present then
            ns.RecipeDetail_Hide()
            ns.RecipeList_Select(nil)
        end
    end
end

-- a click on a recipe: its panel opens next to the window
local function selectRecipe(data)
    ns.RecipeDetail_Show(data.recipe, {
        parent = window, alts = data.alts, rank = data.recipe.rank,
        onClose = function() ns.RecipeList_Select(nil) end,
    })
    ns.RecipeList_Select(data.recipe.id)
end

-- a click on a column title of the table
local function sortBy(key)
    ns.FilterBar_SortBy(filters, key)
    saveFilters()
    refresh()
end

local function cycleView()
    ns.char.view = ns.FilterBar_NextValue(VIEW_NAMES, 2, viewName())
    refresh()
end

local function cycleSkill()
    local skills = ns.RecipeDB_Skills()
    local nextSkill
    if state.skill == nil then
        nextSkill = skills[1]
    else
        for i, skill in ipairs(skills) do
            if skill == state.skill then nextSkill = skills[i + 1] break end
        end
    end
    state.skill = nextSkill
    page.skillButton:SetText(L["Profession: %s"]:format(state.skill and ns.RecipeDB_SkillName(state.skill) or L["All"]))
    refresh()
end

-- The list of recipes is shared with the profession's pages: this page takes it whenever it shows.
local function takeList()
    local list = ns.RecipeList_Attach(page, sortBy, nil, selectRecipe)
    ns.RecipeList_Place(function(withBar)
        local right = withBar and -24 or -4 -- (the room of the bar goes to the rows when it is not there)
        list.header:ClearAllPoints()
        list.header:SetPoint("TOPLEFT", page.filterBar.buttons, "BOTTOMLEFT", 0, -4)
        list.header:SetPoint("RIGHT", page, "RIGHT", right, 0)
        list.scroll:ClearAllPoints()
        list.scroll:SetPoint("TOPLEFT", list.header, "BOTTOMLEFT", 0, -2)
        list.scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", right, 18)
    end)
end

function ns.SearchPage_Create(parent, top)
    window = parent
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -top)
    page:SetPoint("BOTTOMRIGHT", -12, 12)

    local back = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    back:SetSize(90, 22)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Professions"])
    back:SetScript("OnClick", function() ns.UI_ShowOverview() end)

    -- the view (as in a profession's page), on the right of the first row
    local viewButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    viewButton:SetSize(130, 22)
    viewButton:SetPoint("TOPRIGHT", 0, 0)
    viewButton:SetScript("OnClick", cycleView)
    page.viewButton = viewButton

    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("LEFT", back, "RIGHT", 14, 0)
    search:SetPoint("RIGHT", viewButton, "LEFT", -10, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(60)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["Search any recipe: name, ingredient, vendor, drop, zone..."])
    page.search = search
    local function updateHint() hint:SetShown(search:GetText() == "" and not search:HasFocus()) end
    page.updateHint = updateHint
    search:SetScript("OnTextChanged", function(_, userInput)
        if userInput then state.ingredient = nil end -- typing starts an ordinary search
        updateHint()
        refresh()
    end)
    search:SetScript("OnEditFocusGained", updateHint)
    search:SetScript("OnEditFocusLost", updateHint)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- the same filters and sorting as a profession's page (FilterBar.lua); the profession to look in goes on the right
    loadFilters()
    page.filterBar = ns.FilterBar_Create(page, back, {
        filters = filters, x = 0,
        sources = function() return state.sources end,
        categories = function() return state.categories end,
        onChange = function() saveFilters(); refresh() end,
    })
    local skillButton = CreateFrame("Button", nil, page.filterBar.checks, "UIPanelButtonTemplate")
    skillButton:SetSize(190, 22)
    skillButton:SetPoint("RIGHT", page.filterBar.clearButton, "LEFT", -6, 0)
    skillButton:SetText(L["Profession: %s"]:format(L["All"]))
    skillButton:SetScript("OnClick", cycleSkill)
    page.skillButton = skillButton

    page.count = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.count:SetPoint("BOTTOMLEFT", 4, 0)

    -- the name of the item in "N recipes using X" can arrive late
    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", function()
        if page:IsVisible() and state.ingredient then updateCount() end
    end)

    page:Hide()
    return page
end

-- text: what to put in the box (nil: leave it); ingredient: an item id, to list only the recipes that use it
function ns.SearchPage_Show(text, ingredient)
    if not page then return end
    state.ingredient = ingredient
    if ingredient and state.skill then -- a profession picked before would hide recipes of the others
        state.skill = nil
        page.skillButton:SetText(L["Profession: %s"]:format(L["All"]))
    end
    takeList()
    page:Show()
    if text ~= nil then page.search:SetText(text) end
    page.updateHint()
    page.search:SetFocus()
    refresh()
end

function ns.SearchPage_Hide()
    if page then page:Hide() end
end

-- the filters of the page back to nothing
function ns.SearchPage_ResetFilters()
    ns.char.searchFilters = nil
    if not page then return end
    ns.FilterBar_Reset(filters)
    page.filterBar.Update()
    if page:IsVisible() then refresh() end
end

function ns.SearchPage_Results()
    return state.results
end
