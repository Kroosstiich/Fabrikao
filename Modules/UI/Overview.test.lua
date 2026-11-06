dofile("setupTests.lua")

-- The start screen: the professions, what can be crafted, and what can be learned with who teaches it; and the scroll bars that are
-- only there when they are needed.
describe("The start screen", function()
    local ns, known, distances, mapped, bag

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 100, 120, 140, 160 }, m = { { 11, 1 } }, k = { 6 } },
            [3] = { s = 171, n = "Mana Potion", c = { 30, 50, 70, 90 }, m = { { 11, 1 } }, k = { 6 } },
            [4] = { s = 171, n = "Flask of the Titans", c = { 250, 270, 290, 310 }, m = { { 11, 1 } }, k = { 6 } },
            [5] = { s = 164, n = "Iron Sword", c = { 50, 70, 90, 110 }, m = { { 12, 1 } }, k = { 6 } },
            [6] = { s = 164, n = "Steel Axe", c = { 150, 170, 190, 210 }, m = { { 12, 1 } }, k = { 6 } },
            -- taught by an item a vendor sells
            [7] = { s = 164, n = "Dropped Dagger", c = { 40, 60, 80, 100 }, m = { { 12, 1 } }, k = { 5 }, i = 900 },
            -- the same, but it asks for more skill than the smith has
            [8] = { s = 164, n = "Vendor Hammer", c = { 140, 160, 180, 200 }, m = { { 12, 1 } }, k = { 5 }, i = 901 },
            -- nobody teaches it: it drops
            [9] = { s = 164, n = "Orphan Plans", c = { 60, 80, 100, 120 }, m = { { 12, 1 } }, k = { 2 } },
        },
        items = {
            [900] = { n = "Plans: Dropped Dagger", k = { 5 }, v = {
                { id = 13, n = "Vendor Vic", z = { 1519 }, g = 500 }, { id = 14, n = "Horde Hank", z = { 1637 }, f = "H" },
            } },
            [901] = { n = "Plans: Vendor Hammer", k = { 5 }, v = { { id = 15, n = "Hammer Hal", z = { 1519 } } } },
        },
        trainers = {
            [171] = { { id = 9, n = "Near Anna", t = "Alchemist", z = { 1519 } }, { id = 10, n = "Far Ben", z = { 46 } } },
            [164] = { { id = 11, n = "Smith Sam", t = "Blacksmith", z = { 1519 } } },
            [185] = { { id = 12, n = "Cook Cora", z = { 1519 } } },
        },
        npcs = { [9] = { 1453, 40, 60 }, [10] = { 36, 30, 20 }, [11] = { 1453, 20, 20 }, [12] = { 1453, 30, 30 }, [13] = { 1453, 60, 60 } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end
    local function rightClick(f) f._scripts.OnClick(f, "RightButton") end

    local function text(pattern)
        return WowMock.FindAll(function(f) return f._text and f._text:match(pattern) and f:IsVisible() end)
    end

    local function learnNames()
        local out = {}
        for _, f in ipairs(framesWith("learn")) do out[#out + 1] = f.name._text end
        return out
    end

    local function learnRow(name)
        for _, f in ipairs(framesWith("learn")) do
            if f.name._text == name then return f end
        end
    end

    local function headers()
        local out = {}
        for _, f in ipairs(framesWith("kind")) do out[#out + 1] = { kind = f.kind, key = f.key, text = f.text._text, frame = f } end
        return out
    end

    -- the groups are folded until they are opened: this opens every group of professions
    local function openGroups()
        for _ = 1, 10 do
            local closed
            for _, header in ipairs(headers()) do
                if header.frame.folded then closed = header.frame break end
            end
            if not closed then return end
            click(closed)
        end
    end

    -- the names of the trainers and vendors that are shown under what is opened
    local function teachers()
        local out = {}
        for _, f in ipairs(framesWith("teacher")) do out[#out + 1] = f.teacher.name end
        return out
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        WowMock.level = 10
        bag = { [10] = 5, [11] = 0, [12] = 0 }
        known = { [1] = true, [5] = false }
        _G.GetProfessions = function() return 1, 2 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
            return "Blacksmithing", 222, 75, 75, 1, 20, 164, 0
        end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = {
            GetSpellBookItemInfo = function(slot) return { spellID = slot } end,
            IsSpellKnown = function(id) return known[id] == true end,
        }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function(id) return bag[id] or 0 end, GetItemNameByID = function(id) return "Item" .. id end,
            GetItemIconByID = function() return 1 end }
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [46] = "Burning Steppes", [1637] = "Orgrimmar" })[id] end,
            GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB, _G.TomTom = nil, nil, nil
        _G.FabrikaoDetailFrame = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        -- yards from the character by the map of the spot
        distances = { [1453] = 400, [36] = 4000 }
        ns.Map_Distance = function(spot)
            if spot.map == 1453 and spot.x == 20 then return 100 end -- the smith is the nearest of all
            return distances[spot.map]
        end
        mapped = {}
        ns.Map_Show = function(spot) mapped[#mapped + 1] = spot return true end
        StartAddon(ns)
        ns.UI_Show()
    end)

    describe("what is on it", function()
        it("welcomes, and keeps the search, the picker of the character and the button of the professions not learned", function()
            assert.are.equal(1, #text("^Welcome to Fabrikao"))
            assert.is_not_nil(WowMock.Find(function(f) return f._template == "InputBoxTemplate" and f:IsVisible() end))
            assert.is_not_nil(WowMock.Find(function(f) return f._template == "WowStyle1DropdownTemplate" and f:IsVisible() end)
                or WowMock.Find(function(f) return f._text == "My professions" and f:IsVisible() end))
            assert.are.equal(1, #text("professions not learned$"))
        end)

        it("has the professions and the craft list on the left and what can be learned on the right, with nothing about trainers apart", function()
            assert.are.equal(1, #text("^Professions$")) -- (once: its first group does not repeat it)
            assert.are.equal(1, #text("^You can craft now %("))
            assert.are.equal(1, #text("^You can learn %("))
            assert.are.equal(0, #text("^Trainers"))
        end)

        it("only tells the groups that are not the primary professions: secondary ones and the ones not learned", function()
            _G.GetProfessions = function() return 1, 2, 3 end
            _G.GetProfessionInfo = function(index)
                if index == 1 then return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
                if index == 2 then return "Blacksmithing", 222, 75, 75, 1, 20, 164, 0 end
                return "Cooking", 333, 50, 75, 1, 30, 185, 0
            end
            ns.UI_ShowOverview()
            assert.are.equal(1, #text("^Professions$"))
            assert.are.equal(1, #text("^Secondary professions$"))
            assert.are.equal(0, #text("^Not learned$"))
        end)

        it("the top left lists the professions with their bar and skill", function()
            local list = framesWith("profession")
            assert.are.equal(2, #list)
            assert.are.equal("Alchemy", list[1].profession.name)
            assert.are.equal("150 / 300", list[1].barText._text)
            assert.are.equal("Blacksmithing", list[2].profession.name)
            assert.are.equal("75 / 75", list[2].barText._text)
        end)
    end)

    describe("what can be learned (the right side)", function()
        it("counts the ranks and the recipes in its title", function()
            -- the smith's rank, five recipes of alchemy and the smith's (the Elixir is known, the Flask, the Axe and the Hammer ask for more)
            assert.are.equal(1, #text("^You can learn %(6%)$"))
        end)

        it("tells the ranks a trainer can teach", function()
            -- the smith's skill is at the cap of its rank and the character is level 10
            local ranks = framesWith("ofProfession")
            assert.are.equal(1, #ranks)
            assert.matches("Blacksmithing: .*Journeyman", ranks[1].name._text)
            assert.are.equal("skill 150", ranks[1].skillText._text)
        end)

        it("keeps the ranks and the recipes apart, each under its own title", function()
            assert.are.equal(1, #text("^Skill ranges$"))
            assert.are.equal(1, #text("^Recipes$"))
        end)

        it("has the groups folded at first, with how many each has", function()
            assert.are.same({}, learnNames())
            local h = headers()
            assert.are.equal(2, #h)
            assert.matches("^Alchemy %(2%)", h[1].text)
            assert.matches("^Blacksmithing %(3%)", h[2].text)
        end)

        it("lists the recipes the skill reaches that are not known, by profession, the one with the nearest teacher first", function()
            -- Alchemy (skill 150): Mana Potion needs 30, Healing Potion 100; the Elixir is known, the Flask asks for 250. Their
            -- trainers are the same, 400 yards away, so the level decides.
            -- Blacksmithing (skill 75): the Sword is taught by the smith, 100 yards away; the Dagger is sold by a vendor 400 yards
            -- away; nobody is known to teach the Orphan Plans, which goes last
            openGroups()
            assert.are.same({ "Mana Potion", "Healing Potion", "Iron Sword", "Dropped Dagger", "Orphan Plans" }, learnNames())
        end)

        it("the nearer vendor or trainer wins, whichever it is", function()
            -- the vendor of the dagger is 50 yards away now: nearer than the smith, who is 100
            ns.Map_Distance = function(spot)
                if spot.x == 60 then return 50 end -- Vendor Vic
                if spot.x == 20 then return 100 end -- Smith Sam
                return distances[spot.map]
            end
            ns.UI_ShowOverview()
            openGroups()
            assert.are.same({ "Mana Potion", "Healing Potion", "Dropped Dagger", "Iron Sword", "Orphan Plans" }, learnNames())
        end)

        describe("the order button (an icon at the right of the title)", function()
            local function sortButton()
                local found = framesWith("Pick")
                assert.are.equal(1, #found)
                return found[1]
            end

            it("is an icon with no text", function()
                local button = sortButton()
                assert.matches("Sort%.png$", button.icon._set.SetTexture[1])
                assert.is_nil(button._text)
            end)

            it("orders by name", function()
                sortButton().Pick("name")
                openGroups()
                assert.are.same({ "Healing Potion", "Mana Potion", "Dropped Dagger", "Iron Sword", "Orphan Plans" }, learnNames())
            end)

            it("orders by level, lowest first", function()
                sortButton().Pick("level")
                openGroups()
                -- Alchemy: Mana Potion 30, Healing Potion 100. Blacksmithing: Dropped Dagger 40, Iron Sword 50, Orphan Plans 60
                assert.are.same({ "Mana Potion", "Healing Potion", "Dropped Dagger", "Iron Sword", "Orphan Plans" }, learnNames())
            end)

            it("goes back to the nearest first, which is what it starts with", function()
                sortButton().Pick("name")
                sortButton().Pick("near")
                openGroups()
                assert.are.same({ "Mana Potion", "Healing Potion", "Iron Sword", "Dropped Dagger", "Orphan Plans" }, learnNames())
            end)

            it("without the game's menus a click goes to the next order, and it is kept", function()
                click(sortButton()) -- nearest -> level
                assert.are.equal("level", ns.char.learnSort)
                click(sortButton()) -- level -> name
                assert.are.equal("name", ns.char.learnSort)
                click(sortButton()) -- name -> nearest
                assert.are.equal("near", ns.char.learnSort)
            end)

            it("an unknown saved order is the nearest first", function()
                ns.char.learnSort = "whatever"
                ns.UI_ShowOverview()
                openGroups()
                assert.are.same({ "Mana Potion", "Healing Potion", "Iron Sword", "Dropped Dagger", "Orphan Plans" }, learnNames())
            end)
        end)

        it("each recipe has its level and where it is learned", function()
            openGroups()
            local first = framesWith("learn")[1]
            assert.matches("^30", first.skillText._text)
            assert.matches("Trainer", first.skillText._text)
        end)

        it("a group opens and folds with a click on its title, and it is kept", function()
            click(headers()[1].frame)
            assert.are.same({ "Mana Potion", "Healing Potion" }, learnNames())
            assert.is_false(FabrikaoCharDB.folded.learn[171])
            click(headers()[1].frame)
            assert.are.same({}, learnNames())
            assert.is_true(FabrikaoCharDB.folded.learn[171])
        end)

        it("says so when there is nothing", function()
            known = { [1] = true, [2] = true, [3] = true, [5] = true, [7] = true, [9] = true }
            WowMock.level = 5 -- no rank to train either
            ns.UI_ShowOverview()
            assert.are.equal(1, #text("^Nothing new to learn"))
        end)
    end)

    describe("who teaches it, under each recipe and rank", function()
        it("a click on a recipe opens under it the trainers of its profession, nearest first, and another click closes them", function()
            openGroups()
            assert.are.same({}, teachers())
            click(learnRow("Mana Potion"))
            assert.are.same({ "Near Anna", "Far Ben" }, teachers())
            click(learnRow("Mana Potion"))
            assert.are.same({}, teachers())
        end)

        it("shows the vendors that sell what teaches it, for the character's side", function()
            openGroups()
            click(learnRow("Dropped Dagger"))
            assert.are.same({ "Vendor Vic" }, teachers()) -- Horde Hank is the Horde's
            local row = framesWith("teacher")[1]
            assert.matches("^Vendor", row.where._text)
            assert.matches("Stormwind City", row.name._text)
        end)

        it("a recipe taught by a trainer and by a vendor has both, the nearest first", function()
            DATA.recipes[7].k = { 5, 6 }
            openGroups()
            click(learnRow("Dropped Dagger"))
            -- the smith trainer is 100 yards away, the vendor 400
            assert.are.same({ "Smith Sam", "Vendor Vic" }, teachers())
            DATA.recipes[7].k = { 5 }
        end)

        it("says so for a recipe nobody is known to teach", function()
            openGroups()
            click(learnRow("Orphan Plans"))
            assert.are.same({}, teachers())
            assert.are.equal(1, #text("No source is known"))
        end)

        it("lists the creatures that drop what teaches it, after the vendors, with their level and chance", function()
            DATA.recipes[9].i = 902
            DATA.recipes[9].k = { 2, 5 }
            DATA.items[902] = { n = "Plans: Orphan Plans", k = { 2, 5 },
                v = { { id = 15, n = "Hammer Hal", z = { 1519 } } },
                d = { { id = 20, n = "Rare Wolf", z = { 1519 }, lo = 10, hi = 12, pm = 250 } }, dn = 1 }
            openGroups()
            click(learnRow("Orphan Plans"))
            assert.are.same({ "Hammer Hal", "Rare Wolf" }, teachers())
            local row = framesWith("teacher")[2]
            assert.matches("^Drop", row.where._text)
            assert.matches("level 10%-12", row.name._text)
            assert.matches("2.50%%", row.name._text)
            DATA.recipes[9].i, DATA.recipes[9].k, DATA.items[902] = nil, { 2 }, nil
        end)

        it("lists the containers an item is found in, after the vendors, when no creature is known to drop it", function()
            DATA.recipes[9].i = 904
            DATA.items[904] = { n = "Plans: Orphan Plans", lv = 11,
                v = { { id = 15, n = "Hammer Hal", z = { 1519 } } },
                o = { { id = 2850, n = "Solid Chest", z = { 1519 } }, { id = 2849, n = "Battered Chest", z = { 1519 } } } }
            openGroups()
            click(learnRow("Orphan Plans"))
            assert.are.same({ "Hammer Hal", "Solid Chest (Stormwind City)", "Battered Chest (Stormwind City)" }, teachers())
            local row = framesWith("teacher")[2]
            assert.matches("^Found in", row.where._text)
            assert.matches("Solid Chest", row.name._text)
            assert.is_false(row.mapButton:IsShown())
            assert.are.equal(0, #text("No source is known"))
            DATA.recipes[9].i, DATA.items[904] = nil, nil
        end)

        it("says that an item that drops from any creature is a world drop", function()
            DATA.recipes[9].i = 903
            DATA.items[903] = { n = "Plans: Orphan Plans", k = { 2 }, lv = 11, cd = 1 }
            openGroups()
            click(learnRow("Orphan Plans"))
            local row = framesWith("teacher")[1]
            assert.matches("World drop: any creature of about level 11", row.name._text)
            assert.matches("^Drop", row.where._text)
            assert.is_false(row.mapButton:IsShown())
            assert.are.equal(0, #text("No source is known"))
            DATA.recipes[9].i, DATA.items[903] = nil, nil
        end)

        it("each one has the map and waypoint icons, and the map one shows it on the map", function()
            openGroups()
            click(learnRow("Iron Sword"))
            local row = framesWith("teacher")[1]
            assert.are.equal("Smith Sam", row.teacher.name)
            assert.is_true(row.mapButton:IsShown())
            assert.are.equal("map", row.mapButton.iconKind)
            assert.are.equal("pointer", row.tomButton.iconKind)
            click(row.mapButton)
            assert.are.same({ { map = 1453, x = 20, y = 20 } }, mapped)
        end)

        it("has the waypoint icon with TomTom installed", function()
            _G.TomTom = { AddWaypoint = function() return {} end }
            ns.UI_ShowOverview()
            openGroups()
            click(learnRow("Iron Sword"))
            assert.is_true(framesWith("teacher")[1].tomButton:IsShown())
        end)

        it("a right click on a recipe opens its panel instead", function()
            openGroups()
            rightClick(learnRow("Mana Potion"))
            assert.is_true(_G.FabrikaoDetailFrame:IsShown())
            assert.are.equal("Mana Potion", _G.FabrikaoDetailFrame.name._text)
            assert.are.same({}, teachers())
        end)

        it("a click on a rank opens under it the trainers of the profession that can teach it", function()
            local rank = framesWith("ofProfession")[1]
            click(rank)
            assert.are.same({ "Smith Sam" }, teachers())
            local row = framesWith("teacher")[1]
            assert.matches("Blacksmith", row.name._text) -- with its title
            click(framesWith("ofProfession")[1])
            assert.are.same({}, teachers())
        end)

        it("what was opened stays open when the screen is drawn again, and a reset of the settings folds it all", function()
            openGroups()
            click(learnRow("Mana Potion"))
            ns.UI_ShowOverview()
            assert.are.same({ "Near Anna", "Far Ben" }, teachers())
            ns.ResetSettings()
            assert.is_nil(FabrikaoCharDB.folded)
            assert.are.same({}, learnNames())
            assert.are.same({}, teachers())
        end)
    end)

    describe("another character's professions", function()
        before_each(function()
            FabrikaoDB.characters = { ["Elsa-Realm"] = { name = "Elsa", realm = "Realm", class = "MAGE", level = 12, time = 1, professions = {
                { skillLine = 171, name = "Alchemy", icon = 111, rank = 40, maxRank = 75, primary = true, hasRecipes = true, known = { 3 } },
            } } }
            ns.UI_ViewCharacter("Elsa-Realm")
        end)

        it("the learnable recipes are the alt's: its skill and what it knows", function()
            -- skill 40: the Elixir (1) and the Mana Potion (30) are within reach; the alt knows the potion, not the elixir (the
            -- playing character does)
            openGroups()
            assert.are.same({ "Elixir of Wisdom" }, learnNames())
        end)

        it("the craft quadrant says there is no crafting", function()
            assert.are.equal(1, #text("^There is no crafting"))
            assert.are.equal(1, #text("^You can craft now$"))
        end)
    end)
end)

-- The scroll bar that is only there when there is something to scroll
describe("AutoScroll", function()
    local ns, scroll, placed

    before_each(function()
        WowMock.Reset()
        ns = LoadAddon({ files = { "Modules/UI/AutoScroll.lua" } })
        placed = {}
        local parent = CreateFrame("Frame")
        scroll = ns.AutoScroll_Create(parent, function(withBar) placed[#placed + 1] = withBar end)
        scroll._h = 100 -- what the game would say of the frame
    end)

    it("starts with the bar, until it knows the content", function()
        assert.are.same({ true }, placed)
        assert.is_true(ns.AutoScroll_Bar(scroll))
    end)

    it("hides the bar and takes its room when the content fits", function()
        ns.AutoScroll_SetHeight(scroll, 60)
        assert.is_false(ns.AutoScroll_Bar(scroll))
        assert.are.same({ true, false }, placed)
        assert.is_false(scroll.ScrollBar:IsShown())
    end)

    it("shows it when the content is taller than the frame, and goes back to the top when it is not", function()
        ns.AutoScroll_SetHeight(scroll, 60)
        ns.AutoScroll_SetHeight(scroll, 400)
        assert.is_true(ns.AutoScroll_Bar(scroll))
        assert.is_true(scroll.ScrollBar:IsShown())
        scroll:SetVerticalScroll(120)
        ns.AutoScroll_SetHeight(scroll, 30)
        assert.are.equal(0, scroll:GetVerticalScroll())
    end)

    it("does not lay the frame out again while nothing changes", function()
        ns.AutoScroll_SetHeight(scroll, 400)
        ns.AutoScroll_SetHeight(scroll, 500)
        assert.are.same({ true }, placed)
    end)

    it("judges again when the frame is resized", function()
        ns.AutoScroll_SetHeight(scroll, 150)
        assert.is_true(ns.AutoScroll_Bar(scroll))
        scroll._h = 300
        WowMock.Fire(scroll, "OnSizeChanged")
        assert.is_false(ns.AutoScroll_Bar(scroll))
    end)
end)

-- The list of recipes of a profession's page: its bar goes when the rows fit and the room goes to them
describe("The bar of the list of recipes", function()
    local ns

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, m = { { 10, 2 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 100, 120, 140, 160 }, m = { { 11, 1 } }, k = { 6 } },
        },
        items = {}, trainers = {}, npcs = {},
    }

    local function visibleScrolls()
        return WowMock.FindAll(function(f)
            return f._template == "UIPanelScrollFrameTemplate" and f.autoScroll == nil and f:IsVisible()
        end)
    end

    -- where the column titles end on the right: -24 with the bar, -4 without it
    local function headerRight()
        local header = ns.RecipeList_HeaderFrame()
        local right
        for _, point in ipairs(header._points) do
            if point[1] == "RIGHT" then right = point[4] end
        end
        return right
    end

    before_each(function()
        WowMock.Reset()
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end, IsSpellKnown = function() return false end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = {
            GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end,
        }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_Show()
        for _, f in ipairs(WowMock.frames) do
            if f.profession ~= nil and f:IsVisible() and f.profession.skillLine == 171 then f._scripts.OnClick(f) end
        end
    end)

    it("is there when the rows are taller than the list", function()
        local scroll = visibleScrolls()[1]
        scroll._h = 20 -- two recipes and their titles do not fit in that
        ns.RecipeList_Relayout()
        assert.are.equal(-24, headerRight())
        assert.is_true(scroll.ScrollBar:IsShown())
    end)

    it("goes when they fit, and the rows take its room", function()
        local scroll = visibleScrolls()[1]
        scroll._h = 2000
        ns.RecipeList_Relayout()
        assert.are.equal(-4, headerRight())
        assert.is_false(scroll.ScrollBar:IsShown())
        scroll._h = 20
        ns.RecipeList_Relayout()
        assert.are.equal(-24, headerRight())
        assert.is_true(scroll.ScrollBar:IsShown())
    end)
end)

-- The ranks that are a book (Expert) or a quest (Artisan) show who sells the book or gives the quest, and the quest in Completao!!
describe("Ranks of a book or a quest", function()
    local ns, mapped, shown

    local DATA = {
        recipes = {
            [1] = { s = 185, n = "Spiced Wolf Meat", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [2] = { s = 185, n = "Expert Stew", c = { 250, 260, 270, 280 }, m = { { 10, 1 } }, k = { 6 } }, -- the game goes past 225
            [3] = { s = 185, n = "Quest Stew", c = { 5, 25, 45, 65 }, m = { { 10, 1 } }, k = { 4 }, i = 902 }, -- comes from a quest
        },
        items = {
            [902] = { n = "Recipe: Quest Stew", k = { 4 }, qs = {
                { id = 2178, n = "Easy Strider Living", g = { { id = 24, n = "Quest Giver Quinn", z = { 1519 } } } },
                { id = 2179, n = "A Quest Nobody Gives" }, -- (the data does not know who gives it)
            } },
        },
        trainers = { [185] = { { id = 30, n = "Cook Cora", z = { 1519 } } } },
        ranks = {
            [185] = { [225] = { b = { { i = 16072, n = "Expert Cookbook", v = {
                { id = 20, n = "Shandrina", z = { 1519 }, g = 10526, f = "A" },
                { id = 21, n = "Wulan", z = { 1637 }, g = 10526, f = "H" },
            } } } } },
            [356] = { [300] = { q = {
                { id = 6607, n = "Nat Pagle, Angler Extreme", lv = 35, g = { { id = 22, n = "Nat Pagle", z = { 46 } } } },
                { id = 6700, n = "Horde Version", lv = 35, f = "H", g = { { id = 23, n = "Horde Giver", z = { 1637 } } } },
            } } },
        },
        npcs = { [20] = { 1453, 10, 10 }, [21] = { 1454, 10, 10 }, [22] = { 1453, 50, 50 }, [24] = { 1453, 70, 70 }, [30] = { 1453, 90, 90 } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function rankRow(professionName)
        for _, f in ipairs(framesWith("ofProfession")) do
            if f.ofProfession.name == professionName then return f end
        end
    end

    local function teachers()
        local out = {}
        for _, f in ipairs(framesWith("teacher")) do out[#out + 1] = f.teacher end
        return out
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        WowMock.level = 40
        mapped = {}
        shown = {}
        _G.GetProfessions = function() return 1, 2 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Cooking", 111, 150, 150, 1, 10, 185, 0 end -- the cap of its rank: the Expert one can be had
            return "Fishing", 222, 225, 225, 1, 20, 356, 0 -- and the Artisan one
        end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end, IsSpellKnown = function() return false end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = {
            GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end,
        }
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [1637] = "Orgrimmar", [46] = "Burning Steppes" })[id] end,
            GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB, _G.TomTom, _G.CompletaoAPI = nil, nil, nil, nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        ns.Map_Distance = function(spot) return spot.x == 10 and 100 or 400 end
        ns.Map_Show = function(spot) mapped[#mapped + 1] = spot return true end
        StartAddon(ns)
        ns.UI_Show()
    end)

    describe("the data", function()
        it("has the vendors of the book for the character's side, nearest first, with the book and its price", function()
            local list = ns.RecipeDB_RankSources(185, 225)
            assert.are.equal(1, #list) -- Wulan is the Horde's
            assert.are.equal("Shandrina", list[1].name)
            assert.are.equal("vendor", list[1].kind)
            assert.matches("Stormwind City", list[1].text)
            assert.matches("<Item16072>", list[1].text) -- the book as the game names it
            C_Item.GetItemNameByID = function() return nil end -- (not loaded yet: the data's name)
            assert.matches("<Expert Cookbook>", ns.RecipeDB_RankSources(185, 225)[1].text)
        end)

        it("has the quest by its name, with the id, and its giver apart (the name, the place and the distance are the giver's)", function()
            local list = ns.RecipeDB_RankSources(356, 300)
            assert.are.equal(1, #list) -- the Horde's version is not for an Alliance character
            assert.are.equal("Nat Pagle, Angler Extreme", list[1].text)
            assert.are.equal("Nat Pagle", list[1].name)
            assert.matches("Nat Pagle", list[1].giver)
            assert.are.equal("quest", list[1].kind)
            assert.are.equal(6607, list[1].questID)
            assert.are.equal(22, list[1].id)
        end)

        it("has nothing for a rank a trainer teaches", function()
            assert.is_nil(ns.RecipeDB_RankSources(185, 150))
            assert.is_nil(ns.RecipeDB_RankSources(164, 225))
        end)
    end)

    describe("in the list of what can be learned", function()
        it("an Expert rank of a book shows who sells the book, not the trainers", function()
            click(rankRow("Cooking"))
            local list = teachers()
            assert.are.equal(1, #list)
            assert.are.equal("Shandrina", list[1].name)
            assert.are.equal("vendor", list[1].kind)
        end)

        it("an Artisan rank of a quest shows who gives it", function()
            click(rankRow("Fishing"))
            local list = teachers()
            assert.are.equal(1, #list)
            assert.are.equal("Nat Pagle", list[1].name)
            assert.are.equal(6607, list[1].questID)
            local row = framesWith("teacher")[1]
            assert.matches("^Quest", row.where._text)
        end)

        it("is shown by the name of the quest, with who gives it under it", function()
            click(rankRow("Fishing"))
            local row = framesWith("teacher")[1]
            assert.are.equal("Nat Pagle, Angler Extreme", row.name._text)
            assert.matches("^Quest", row.where._text)
            assert.matches("from .*Nat Pagle", row.where._text)
        end)

        it("the giver has the map icon, which shows it on the map", function()
            click(rankRow("Fishing"))
            local row = framesWith("teacher")[1]
            click(row.mapButton)
            assert.are.same({ { map = 1453, x = 50, y = 50 } }, mapped)
        end)

        it("has no Completao button without Completao, or when it does not know the quest", function()
            click(rankRow("Fishing"))
            assert.is_false(framesWith("teacher")[1].questButton:IsShown())
            _G.CompletaoAPI = { HasQuest = function() return false end, ShowQuest = function() return false end }
            ns.UI_ShowOverview()
            assert.is_false(framesWith("teacher")[1].questButton:IsShown())
        end)

        it("has one with Completao's icon when it knows the quest, and it opens the quest there", function()
            _G.CompletaoAPI = { HasQuest = function(id) return id == 6607 end, ShowQuest = function(id) shown[#shown + 1] = id return true end }
            ns.UI_ShowOverview()
            click(rankRow("Fishing"))
            local row = framesWith("teacher")[1]
            assert.is_true(row.questButton:IsShown())
            assert.are.equal("quest", row.questButton.iconKind)
            assert.matches("Completao", row.questButton.icon._set.SetTexture[1])
            click(row.questButton)
            assert.are.same({ 6607 }, shown)
        end)

        it("the vendor of a book has no Completao button", function()
            _G.CompletaoAPI = { HasQuest = function() return true end, ShowQuest = function() return true end }
            ns.UI_ShowOverview()
            click(rankRow("Cooking"))
            assert.is_false(framesWith("teacher")[1].questButton:IsShown())
        end)
    end)
    describe("the quests of a recipe", function()
        local function openCooking()
            for _, f in ipairs(framesWith("kind")) do
                if f.folded and f.key == 185 then click(f) break end
            end
        end

        local function recipeRow(name)
            for _, f in ipairs(framesWith("learn")) do
                if f.name._text == name then return f end
            end
        end

        it("a recipe that comes from a quest lists the quest by its name, with the buttons of who gives it", function()
            openCooking()
            click(recipeRow("Quest Stew"))
            local quests = {}
            for _, row in ipairs(framesWith("teacher")) do
                if row.teacher.kind == "quest" then quests[#quests + 1] = row end
            end
            assert.are.equal(2, #quests)
            -- the one whose giver the data knows is first (it has a distance): its name, who gives it and the map icon
            assert.are.equal("Easy Strider Living", quests[1].name._text)
            assert.matches("Quest Giver Quinn", quests[1].where._text)
            assert.is_true(quests[1].mapButton:IsShown())
            click(quests[1].mapButton)
            assert.are.same({ { map = 1453, x = 70, y = 70 } }, mapped)
        end)

        it("a quest whose giver is not known is still there, by its name, without the map", function()
            openCooking()
            click(recipeRow("Quest Stew"))
            local row
            for _, f in ipairs(framesWith("teacher")) do
                if f.teacher.questID == 2179 then row = f end
            end
            assert.is_not_nil(row)
            assert.are.equal("A Quest Nobody Gives", row.name._text)
            assert.is_false(row.mapButton:IsShown())
        end)

        it("with Completao a quest has its icon, and it opens the quest there", function()
            _G.CompletaoAPI = { HasQuest = function(id) return id == 2178 end, ShowQuest = function(id) shown[#shown + 1] = id return true end }
            ns.UI_ShowOverview()
            openCooking()
            click(recipeRow("Quest Stew"))
            local row
            for _, f in ipairs(framesWith("teacher")) do
                if f.teacher.questID == 2178 then row = f end
            end
            assert.is_true(row.questButton:IsShown())
            click(row.questButton)
            assert.are.same({ 2178 }, shown)
        end)

        it("the panel of the recipe has the same: the quest and the buttons of its giver", function()
            local lines = ns.RecipeDB_Where(DATA.recipes[3], true)
            local quest
            for _, line in ipairs(lines) do
                if line.title == "Quest" then quest = line.entries[1] end
            end
            assert.are.equal("Easy Strider Living", quest.text)
            assert.are.equal(24, quest.id)
            assert.are.equal("Quest Giver Quinn", quest.name)
            assert.are.equal(2178, quest.questID)
        end)
    end)
end)
