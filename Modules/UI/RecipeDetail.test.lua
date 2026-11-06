dofile("setupTests.lua")

-- The panel of a recipe: what it says, how a click on a recipe of the list opens and closes it, and the TomTom waypoints.
describe("Recipe detail", function()
    local ns, known, prices, waypoints

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 2 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 }, g = 5000, u = true },
            [2] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, l = 240, p = { 201, 1, 1 }, m = { { 12, 3 } }, k = { 5, 6 }, i = 900 },
            [3] = { s = 171, n = "Plain", c = { 1, 2, 3, 4 } },
        },
        items = {
            [900] = { n = "Recipe: Flask of the Titans", lv = 50, k = { 5 }, v = {
                { id = 1, n = "Alliance Vendor", z = { 1519 }, g = 12345 }, { id = 2, n = "Horde Vendor", z = { 1637 }, f = "H" },
                { id = 3, n = "Vendor 3", z = { 46 } }, { id = 4, n = "Vendor 4", z = { 46 } }, { id = 5, n = "Vendor 5", z = { 46 } },
                { id = 6, n = "Vendor 6", z = { 46 } }, { id = 7, n = "Vendor 7", z = { 46 } },
            }, d = { { id = 20, n = "Boss", z = { 46 }, lo = 60, hi = 60, pm = 250 }, { id = 21, n = "Nowhere Boss", z = { 46 } } } },
        },
        trainers = { [171] = { { id = 9, n = "Alchemist Anna", z = { 1519 }, f = "A" }, { id = 10, n = "Alchemist Ben", z = { 46 } } } },
        npcs = { [1] = { 1453, 74.4, 36.4 }, [9] = { 1453, 40, 60 }, [10] = { 36, 30, 20 }, [20] = { 36, 55, 45 } },
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function recipeRow(name)
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" and row.data.recipe.name == name then return row end
        end
    end

    local function panel() return _G.FabrikaoDetailFrame end

    local function factValue(detail, label)
        for _, f in ipairs(detail.facts) do if f.label == label then return f.value end end
    end

    local function source(detail, title)
        for _, line in ipairs(detail.sources) do if line.title == title then return line end end
    end

    before_each(function()
        WowMock.Reset()
        _G.FabrikaoDetailFrame, _G.IsModifiedClick, _G.ChatEdit_InsertLink, _G.TomTom = nil, nil, nil, nil -- (the game's globals outlive a test)
        known = { [1] = true }
        prices = { [10] = 100, [11] = 200, [200] = 5000 }
        waypoints = {}
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 100, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
        _G.UnitFactionGroup = function() return "Alliance" end
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [1637] = "Orgrimmar", [46] = "Burning Steppes" })[id] end }
        local bag = { [10] = 5, [11] = 0, [12] = 1 }
        _G.C_Item = {
            GetItemCount = function(id) return bag[id] or 0 end,
            GetItemNameByID = function(id) return "Item" .. id end,
            GetItemIconByID = function() return 12345 end,
        }
        _G.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return prices[id] end } } }
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_Toggle()
        click(visible("profession")[1])
    end)

    describe("what it says", function()
        local function build(id, learned, opts)
            local recipe = ns.Recipes_FromRecord(id, DATA.recipes[id], learned, 100)
            return ns.RecipeDetail_Build(recipe, opts)
        end

        it("tells the status, the skill needed and how the colors look for the character", function()
            local detail = build(1, true)
            assert.are.equal("Elixir of Wisdom", detail.name)
            assert.matches("You know this recipe", detail.status)
            assert.matches("1   %(.-you have 100", factValue(detail, "Skill needed:"))
            assert.is_not_nil(factValue(detail, "Difficulty:"))
            assert.is_not_nil(factValue(detail, "For your skill:"))
            assert.matches("Alchemy", detail.subtitle)
            detail = build(2, false)
            assert.matches("You don't know this recipe yet", detail.status)
            assert.matches("^240", factValue(detail, "Skill needed:"))
        end)

        it("without the profession it says so", function()
            local recipe = ns.Recipes_FromRecord(1, DATA.recipes[1], false, nil)
            assert.matches("You don't have this profession", ns.RecipeDetail_Build(recipe).status)
        end)

        it("tells what it makes, how many can be made, the training cost, the teacher and what is new", function()
            local detail = build(1, true)
            assert.matches("Item200 x1%-2", factValue(detail, "Makes:"))
            assert.are.equal("0", factValue(detail, "Crafts possible:")) -- no Silverleaf
            assert.is_not_nil(factValue(detail, "Training cost:"))
            assert.is_not_nil(factValue(detail, "New in Forever"))
            detail = build(2, false)
            assert.matches("Item900.-item level 50", factValue(detail, "Taught by:")) -- the game's name, in the player's language
            C_Item.GetItemNameByID = function() return nil end -- (not loaded yet)
            detail = build(2, false)
            assert.matches("Recipe: Flask of the Titans.-item level 50", factValue(detail, "Taught by:")) -- the data's meanwhile
        end)

        it("lists the ingredients with how many the character has, and the price of what they need", function()
            local reagents = build(1, true).reagents
            assert.are.equal(2, #reagents)
            assert.are.equal(10, reagents[1].itemID)
            assert.are.equal(5, reagents[1].have)
            assert.are.equal(2, reagents[1].needed)
            assert.matches("you have 5", reagents[1].status)
            assert.matches("|cff40bf40", reagents[1].status) -- enough
            assert.matches("|cffff4040", reagents[2].status) -- none
            assert.are.equal(200, reagents[1].total) -- 2 x 100
        end)

        it("counts the bank and the other characters", function()
            ns.Inventory_Mine = function() return 1, 4 end
            ns.Inventory_OthersTotal = function() return 7 end
            ns.Inventory_Available = function() return true end
            local detail = build(1, true, { alts = true })
            assert.matches("4 in your bank", detail.reagents[1].status)
            assert.matches("%+7 on other characters", detail.reagents[1].status)
            assert.matches("counting your other characters", factValue(detail, "Crafts possible:"))
        end)

        it("shows the cost, what it sells for and the profit", function()
            local economy = build(1, true).economy
            assert.are.same({ "Ingredients cost:", "Sells for about:", "Profit:" }, { economy[1].label, economy[2].label, economy[3].label })
            assert.matches("|cff40bf40", economy[3].value)
        end)

        it("says when there is no auction data", function()
            _G.Auctionator = nil
            assert.matches("No auction data", build(1, true).note)
        end)

        it("lists where it is learned in full: the vendors of the character's side with their zones, each one apart", function()
            local vendors = source(build(2, false), "Vendor")
            assert.matches("^Alliance Vendor %(Stormwind City%) %-%- 1g", vendors.entries[1].text)
            assert.are.equal(1, vendors.entries[1].id)
            assert.are.equal(6, #vendors.entries) -- the 6 of the side (the tooltips list five)
            for _, npc in ipairs(vendors.entries) do assert.is_nil(npc.text:find("Horde Vendor", 1, true)) end
            local trainers = source(build(2, false), "Trainer")
            assert.are.equal(2, #trainers.entries)
        end)

        it("lists who drops it one by one, with the id to show them on the map", function()
            local drops = source(build(2, false), "Drop")
            assert.are.equal(2, #drops.entries)
            assert.are.equal(20, drops.entries[1].id)
            assert.are.equal("Boss", drops.entries[1].name)
            assert.matches("^Boss %(Burning Steppes%) level 60 %-%- 2%.50%%", drops.entries[1].text)
        end)

        it("has the ids at the end", function()
            local detail = build(2, false)
            assert.matches("Recipe ID: 2", detail.ids)
            assert.matches("Item ID: 201", detail.ids)
        end)

        it("copes with a recipe the data does not know", function()
            local detail = ns.RecipeDetail_Build({ id = 99, name = "Odd", icon = 1, learned = true, reagents = {} })
            assert.are.equal("Odd", detail.name)
            assert.matches("Recipe ID: 99", detail.ids)
            assert.are.same({}, detail.sources)
        end)
    end)

    describe("a recipe that comes from a quest (Completao)", function()
        local shown

        before_each(function()
            shown = nil
            ns.RECIPE_DATA = {
                recipes = { [4] = { s = 171, n = "Quest Elixir", c = { 1, 2, 3, 4 }, k = { 4 }, i = 901 } },
                items = { [901] = { n = "Recipe: Quest Elixir", lv = 10, k = { 4 }, qs = { { id = 38, n = "The Elixir Quest" } } } },
                trainers = {},
            }
            _G.CompletaoAPI = {
                version = 1,
                HasQuest = function(id) return id == 38 end,
                ShowQuest = function(id) shown = id; return true end,
            }
        end)

        after_each(function() _G.CompletaoAPI = nil end)

        local function open()
            local recipe = ns.Recipes_FromRecord(4, ns.RECIPE_DATA.recipes[4], false, 100)
            ns.RecipeDetail_Show(recipe, { parent = _G.FabrikaoFrame })
            return recipe
        end

        it("its quest line keeps the quest's id", function()
            local detail = ns.RecipeDetail_Build(ns.Recipes_FromRecord(4, ns.RECIPE_DATA.recipes[4], false, 100))
            local line
            for _, l in ipairs(detail.sources) do if l.title == "Quest" then line = l end end
            assert.are.equal(38, line.entries[1].questID)
            assert.are.equal("The Elixir Quest", line.entries[1].text)
        end)

        -- the visible quest icon buttons (Completao!!'s icon): they are small icons like the map and waypoint ones, not a text button
        local function questButtons()
            local found = {}
            for _, f in ipairs(WowMock.frames) do
                if f.iconKind == "quest" and f.npc and f._scripts.OnClick and f:IsVisible() then found[#found + 1] = f end
            end
            return found
        end

        it("has Completao's icon button when Completao knows the quest, and it opens the quest there", function()
            open()
            local found = questButtons()
            assert.are.equal(1, #found)
            assert.matches("Completao", found[1].icon._set.SetTexture[1])
            assert.are.equal(22, found[1]:GetWidth())
            assert.is_nil(WowMock.FindButton("View Quest"))
            click(found[1])
            assert.are.equal(38, shown)
        end)

        it("has none without Completao, or when it doesn't know the quest", function()
            _G.CompletaoAPI = nil
            open()
            assert.are.equal(0, #questButtons())
            _G.CompletaoAPI = { version = 1, HasQuest = function() return false end, ShowQuest = function() return false end }
            open()
            assert.are.equal(0, #questButtons())
        end)
    end)

    describe("the waypoints (TomTom)", function()
        local function install()
            _G.TomTom = { AddWaypoint = function(_, map, x, y, options) waypoints[#waypoints + 1] = { map = map, x = x, y = y, options = options } end }
        end

        it("the location of an NPC comes from the data", function()
            assert.are.same({ map = 1453, x = 74.4, y = 36.4 }, ns.RecipeDB_NpcLocation(1))
            assert.is_nil(ns.RecipeDB_NpcLocation(2))
        end)

        it("a waypoint is set at the NPC, with its coordinates as fractions of the map", function()
            install()
            assert.is_true(ns.RecipeDetail_Waypoint({ id = 1, name = "Alliance Vendor" }))
            assert.are.equal(1453, waypoints[1].map)
            assert.is_true(math.abs(waypoints[1].x - 0.744) < 1e-9)
            assert.is_true(math.abs(waypoints[1].y - 0.364) < 1e-9)
            assert.are.equal("Alliance Vendor", waypoints[1].options.title)
        end)

        it("nothing is set without TomTom or without the location", function()
            assert.is_false(ns.RecipeDetail_Waypoint({ id = 1, name = "x" }))
            install()
            assert.is_false(ns.RecipeDetail_Waypoint({ id = 2, name = "x" })) -- no coordinates
            assert.are.equal(0, #waypoints)
        end)

        -- the visible icon buttons of the NPC lines of that kind ("pointer", the waypoint, or "map"): their NPC ids, and the buttons
        local function buttons(kind)
            local found, ids = {}, {}
            for _, f in ipairs(WowMock.frames) do
                if f.npc and f.iconKind == kind and f._scripts.OnClick and f:IsVisible() then found[#found + 1] = f end
            end
            for _, b in ipairs(found) do ids[#ids + 1] = b.npc.id end
            table.sort(ids)
            return ids, found
        end

        it("a recipe not known shows a TomTom button at each trainer and vendor with a location, when TomTom is there", function()
            install()
            click(recipeRow("Flask of the Titans"))
            local ids, found = buttons("pointer")
            assert.are.same({ 1, 9, 10, 20 }, ids) -- the other vendors, trainers and creatures have no known location
            click(found[1])
            assert.are.equal(1, #waypoints)
        end)

        it("and a Map button too, with or without TomTom", function()
            click(recipeRow("Flask of the Titans"))
            assert.are.same({ 1, 9, 10, 20 }, (buttons("map")))
            assert.are.same({}, (buttons("pointer")))
        end)

        it("the Map button opens the world map on the NPC", function()
            local opened
            _G.OpenWorldMap = function(map) opened = map end
            click(recipeRow("Flask of the Titans"))
            local _, found = buttons("map")
            click(found[1])
            assert.are.equal(1453, opened) -- the vendor, or the trainer: both stand in map 1453 or 36
        end)

        it("a recipe the character knows has the buttons too", function()
            install()
            click(recipeRow("Elixir of Wisdom"))
            assert.are.same({ 9, 10 }, (buttons("pointer"))) -- its trainers
            assert.are.same({ 9, 10 }, (buttons("map")))
        end)

        -- the character stands in map 1453 at (50, 50); map 36 lies 5000 yards away: a world made of yards = map fraction * 1000
        local function standAt1453()
            _G.CreateVector2D = function(x, y) return { x = x, y = y } end
            _G.C_Map.GetBestMapForUnit = function() return 1453 end
            _G.C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end
            _G.C_Map.GetWorldPosFromMapPos = function(map, vector)
                return 1, { x = vector.x * 1000 + (map == 36 and 5000 or 0), y = vector.y * 1000 }
            end
        end

        it("the trainers, vendors and creatures come nearest first, with how far they are", function()
            standAt1453()
            local detail = ns.RecipeDetail_Build(ns.Recipes_FromRecord(2, DATA.recipes[2], false, 100))
            local function ids(title)
                local list = {}
                for _, e in ipairs(source(detail, title).entries) do list[#list + 1] = e.id end
                return list
            end
            assert.are.same({ 9, 10 }, ids("Trainer")) -- Anna is next door, Ben is far
            assert.are.same({ 1, 3, 4, 5, 6, 7 }, ids("Vendor")) -- the one with a position first, the rest as they came
            assert.are.same({ 20, 21 }, ids("Drop"))
            local trainers = source(detail, "Trainer").entries
            assert.is_true(math.abs(trainers[1].distance - 141.4) < 0.5)
            assert.is_true(trainers[2].distance > 4000)
            assert.is_nil(source(detail, "Vendor").entries[2].distance) -- no position known
        end)

        it("the one that is farther comes later even when it was first", function()
            standAt1453()
            DATA.trainers[171] = { { id = 10, n = "Alchemist Ben", z = { 46 } }, { id = 9, n = "Alchemist Anna", z = { 1519 }, f = "A" } }
            local lines = ns.RecipeDB_Where(DATA.recipes[1], true)
            DATA.trainers[171] = { { id = 9, n = "Alchemist Anna", z = { 1519 }, f = "A" }, { id = 10, n = "Alchemist Ben", z = { 46 } } }
            assert.are.equal(9, lines[1].entries[1].id)
        end)

        it("without the character's position, the ones on its map come first", function()
            _G.C_Map.GetBestMapForUnit = function() return 36 end
            local lines = ns.RecipeDB_Where(DATA.recipes[1], true)
            assert.are.equal(10, lines[1].entries[1].id) -- Alchemist Ben stands in map 36
        end)

        it("the trainers and vendors of the zone the character is in come first", function()
            _G.C_Map.GetBestMapForUnit = function() return 36 end
            local lines = ns.RecipeDB_Where(DATA.recipes[1], true)
            assert.are.equal(10, lines[1].entries[1].id) -- Alchemist Ben stands in map 36
        end)
    end)

    describe("crafting", function()
        local toRecipe

        before_each(function()
            toRecipe = nil
            _G.C_Item.GetItemCount = function(id) return ({ [10] = 5, [11] = 3 })[id] or 0 end -- enough for 2
            _G.ProfessionsUtil = { OpenProfessionFrameToRecipe = function(recipeID) toRecipe = recipeID; return true end }
        end)

        after_each(function() _G.ProfessionsUtil = nil end)

        it("a recipe the character knows has the button, and one it doesn't has not", function()
            click(recipeRow("Elixir of Wisdom"))
            assert.is_true(panel().craftBar:IsShown())
            click(recipeRow("Flask of the Titans"))
            assert.is_false(panel().craftBar:IsShown())
        end)

        it("says how many the bags allow", function()
            click(recipeRow("Elixir of Wisdom"))
            assert.are.equal("2 possible with your bags", panel().craftInfo._text)
        end)

        it("the count follows the bags", function()
            click(recipeRow("Elixir of Wisdom"))
            _G.C_Item.GetItemCount = function(id) return ({ [10] = 20, [11] = 20 })[id] or 0 end
            for _, f in ipairs(WowMock.FindAll(function(f) return f._events and f._events.BAG_UPDATE_DELAYED and f._scripts.OnEvent end)) do
                f._scripts.OnEvent(f, "BAG_UPDATE_DELAYED")
            end
            assert.are.equal("10 possible with your bags", panel().craftInfo._text)
        end)

        it("the button is off when the bags allow nothing, and on again when they do", function()
            _G.C_Item.GetItemCount = function() return 0 end
            click(recipeRow("Elixir of Wisdom"))
            assert.are.equal("0 possible with your bags", panel().craftInfo._text)
            assert.is_false(panel().craftButton:IsEnabled())
            _G.C_Item.GetItemCount = function(id) return ({ [10] = 5, [11] = 3 })[id] or 0 end
            for _, f in ipairs(WowMock.FindAll(function(f) return f._events and f._events.BAG_UPDATE_DELAYED and f._scripts.OnEvent end)) do
                f._scripts.OnEvent(f, "BAG_UPDATE_DELAYED")
            end
            assert.is_true(panel().craftButton:IsEnabled())
        end)

        it("the button opens the game's profession window on the recipe", function()
            click(recipeRow("Elixir of Wisdom"))
            click(panel().craftButton)
            assert.are.equal(1, toRecipe)
        end)
    end)

    describe("opening and closing", function()
        it("a click on a recipe opens the panel with it, next to the window", function()
            assert.is_nil(panel())
            click(recipeRow("Elixir of Wisdom"))
            assert.is_true(panel():IsShown())
            assert.are.equal("Elixir of Wisdom", panel().name._text)
            assert.are.equal("Elixir of Wisdom", ns.RecipeDetail_Current().name)
            assert.matches("You know this recipe", panel().status._text)
            local anchors = {}
            for _, point in ipairs(panel()._points) do anchors[point[1]] = point[3] end
            assert.are.same({ TOPLEFT = "TOPRIGHT", BOTTOMLEFT = "BOTTOMRIGHT" }, anchors)
        end)

        it("marks the recipe in the list, and another click changes the recipe", function()
            click(recipeRow("Elixir of Wisdom"))
            assert.is_true(recipeRow("Elixir of Wisdom").selected:IsShown())
            assert.is_false(recipeRow("Flask of the Titans").selected:IsShown())
            click(recipeRow("Flask of the Titans"))
            assert.are.equal("Flask of the Titans", panel().name._text)
            assert.is_true(recipeRow("Flask of the Titans").selected:IsShown())
            assert.is_false(recipeRow("Elixir of Wisdom").selected:IsShown())
        end)

        it("draws a row for every ingredient, with the item's tooltip", function()
            click(recipeRow("Elixir of Wisdom"))
            local rows = {}
            for _, f in ipairs(WowMock.frames) do
                if f.itemID and f.icon and f._parent == panel().child and f:IsShown() then rows[#rows + 1] = f end
            end
            assert.are.equal(2, #rows)
            local row = rows[1]
            assert.matches("Item10 x2", row.name._text)
            row._scripts.OnEnter(row)
            assert.are.same({ row.itemID }, GameTooltip._set.SetItemByID)
        end)

        it("shows fewer rows when the next recipe has fewer ingredients", function()
            click(recipeRow("Elixir of Wisdom"))
            click(recipeRow("Flask of the Titans"))
            local rows = {}
            for _, f in ipairs(WowMock.frames) do
                if f.itemID and f.icon and f._parent == panel().child and f:IsShown() then rows[#rows + 1] = f end
            end
            assert.are.equal(1, #rows)
        end)

        it("the group titles do not open it", function()
            click(visible("data")[1]) -- the title of the known recipes
            assert.is_nil(panel())
        end)

        it("a shift-click puts the link in the chat instead", function()
            _G.IsModifiedClick = function() return true end
            local inserted
            _G.ChatEdit_InsertLink = function(link) inserted = link end
            local row = recipeRow("Elixir of Wisdom")
            row.data.recipe.link = "|Hspell:1|h[Elixir]|h"
            click(row)
            assert.are.equal("|Hspell:1|h[Elixir]|h", inserted)
            assert.is_nil(panel())
        end)

        it("closing it clears the mark in the list", function()
            click(recipeRow("Elixir of Wisdom"))
            panel():Hide()
            assert.is_nil(ns.RecipeDetail_Current())
            assert.is_false(recipeRow("Elixir of Wisdom").selected:IsShown())
        end)

        it("going back to the professions closes it", function()
            click(recipeRow("Elixir of Wisdom"))
            ns.UI_ShowOverview()
            assert.is_false(panel():IsShown())
        end)

        it("closing the window closes it too", function()
            click(recipeRow("Elixir of Wisdom"))
            ns.UI_Hide()
            assert.is_false(panel():IsShown())
        end)

        it("also opens from a click on an ingredient icon of the table", function()
            local row = recipeRow("Elixir of Wisdom")
            click(row.compIcons[1])
            assert.is_true(panel():IsShown())
        end)
    end)
end)
