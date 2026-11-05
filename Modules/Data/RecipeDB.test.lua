dofile("setupTests.lua")

describe("RecipeDB", function()
    local ns

    local DATA = {
        recipes = {
            [100] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 }, { 11, 1 } }, k = { 6 }, g = 5000 },
            [101] = { s = 171, n = "Mighty Flask", c = { 250, 270, 290, 310 }, l = 240, m = { { 12, 3 } }, k = { 2 }, i = 900 },
            [102] = { s = 164, n = "Iron Sword", c = { 100, 120, 140, 160 }, k = { 5 }, i = 901 },
            [103] = { s = 164, n = "Sword of Quests", c = { 50, 60, 70, 80 }, k = { 4 }, i = 902 },
        },
        items = {
            [900] = { n = "Recipe: Mighty Flask", lv = 50, k = { 2 }, d = {
                { id = 1, n = "Black Drake", z = { 46 }, lo = 55, hi = 57, pm = 125 }, { id = 2, n = "Red Whelp", z = { 46 }, lo = 50, hi = 50 },
            }, dn = 6 },
            [901] = { n = "Plans: Iron Sword", lv = 20, k = { 5 }, v = {
                { id = 3, n = "Alliance Smith", z = { 1519 }, f = "A", g = 12345 }, { id = 4, n = "Horde Smith", z = { 1637 }, f = "H" },
            } },
            [902] = { n = "Plans: Sword of Quests", lv = 20, k = { 4 }, qs = { { id = 5, n = "The Sword Quest" }, { id = 6, n = "Horde Quest", f = "H" } } },
        },
        trainers = {
            [171] = {
                { id = 7, n = "Alchemist Anna", z = { 1519 }, f = "A" }, { id = 8, n = "Alchemist Orc", z = { 1637 }, f = "H" },
                { id = 9, n = "Neutral Nick", z = { 1519 } },
            },
        },
    }

    before_each(function()
        WowMock.Reset()
        _G.UnitFactionGroup = function() return "Alliance" end
        _G.C_Map = { GetAreaInfo = function(id) return ({ [1519] = "Stormwind City", [1637] = "Orgrimmar", [46] = "Burning Steppes" })[id] end }
        _G.C_Item = { GetItemNameByID = function(id) return ({ [10] = "Peacebloom", [11] = "Silverleaf", [12] = "Dreamfoil" })[id] end }
        ns = LoadAddon({ files = { "Modules/Data/RecipeDB.lua" } })
        ns.RECIPE_DATA = DATA
    end)

    describe("a recipe's name", function()
        after_each(function() _G.C_Spell, _G.GetSpellInfo = nil, nil end)

        it("is its spell's, in the player's language", function()
            _G.C_Spell = { GetSpellName = function(id) return id == 102 and "Espada de hierro" or nil end }
            assert.are.equal("Espada de hierro", ns.RecipeDB_Name(102, ns.RecipeDB_Get(102)))
        end)

        it("on the clients with only the older query, asks that one", function()
            _G.GetSpellInfo = function(id) return id == 102 and "Eisenschwert" or nil end
            assert.are.equal("Eisenschwert", ns.RecipeDB_Name(102, ns.RecipeDB_Get(102)))
        end)

        it("is the data's when the client doesn't know the spell", function()
            _G.C_Spell = { GetSpellName = function() return nil end }
            assert.are.equal("Iron Sword", ns.RecipeDB_Name(102, ns.RecipeDB_Get(102)))
        end)
    end)

    it("gets a recipe by its spell id", function()
        assert.are.equal("Iron Sword", ns.RecipeDB_Get(102).n)
        assert.is_nil(ns.RecipeDB_Get(1))
    end)

    it("gives the skill levels where the recipe changes color", function()
        assert.are.same({ 1, 55, 75, 95 }, ns.RecipeDB_Colors(ns.RecipeDB_Get(100)))
        -- the skill to learn it can be lower than where it turns orange
        assert.are.equal(240, ns.RecipeDB_Required(ns.RecipeDB_Get(101)))
        assert.are.equal(100, ns.RecipeDB_Required(ns.RecipeDB_Get(102)))
        assert.are.same({ 240, 270, 290, 310 }, ns.RecipeDB_Colors(ns.RecipeDB_Get(101)))
    end)

    it("joins the sources of the recipe and of the item that teaches it", function()
        assert.are.same({ 6 }, ns.RecipeDB_Sources(ns.RecipeDB_Get(100)))
        assert.are.same({ 5 }, ns.RecipeDB_Sources(ns.RecipeDB_Get(102)))
        assert.are.equal("Trainer", ns.RecipeDB_ShortSource(ns.RecipeDB_Get(100)))
        assert.are.equal("Quest", ns.RecipeDB_ShortSource(ns.RecipeDB_Get(103)))
    end)

    describe("where it is learned", function()
        -- (the tests below change the vendors of an item of the shared data)
        local savedVendors
        before_each(function() savedVendors = DATA.items[901].v end)
        after_each(function() DATA.items[901].v = savedVendors end)

        it("lists the trainers of the character's side, with their zone and the cost", function()
            local lines = ns.RecipeDB_Where(ns.RecipeDB_Get(100))
            assert.are.equal("Trainer", lines[1].title)
            assert.matches("Alchemist Anna %(Stormwind City%)", lines[1].text)
            assert.matches("Neutral Nick", lines[1].text)
            assert.is_nil(lines[1].text:find("Alchemist Orc", 1, true))
            assert.matches("costs", lines[1].text)
        end)

        it("lists the vendors of the character's side", function()
            local text = ns.RecipeDB_Where(ns.RecipeDB_Get(102))[1].text
            assert.matches("Alliance Smith %(Stormwind City%)", text)
            assert.is_nil(text:find("Horde Smith", 1, true))
            _G.UnitFactionGroup = function() return "Horde" end
            text = ns.RecipeDB_Where(ns.RecipeDB_Get(102))[1].text
            assert.matches("Horde Smith %(Orgrimmar%)", text)
        end)

        it("leaves out the vendors without a side that stand where only the other side can be", function()
            ns.RECIPE_DATA.items[901].v = {
                { id = 3, n = "Stormwind Smith", z = { 1519 } }, { id = 4, n = "Orgrimmar Smith", z = { 1637 } },
                { id = 5, n = "Wandering Smith", z = { 46 } }, { id = 6, n = "Both Smith", z = { 1637, 46 } },
            }
            local text = ns.RecipeDB_Where(ns.RecipeDB_Get(102))[1].text
            assert.matches("Stormwind Smith %(Stormwind City%)", text)
            assert.matches("Wandering Smith %(Burning Steppes%)", text)
            assert.matches("Both Smith", text) -- one of its zones is open to everybody
            assert.is_nil(text:find("Orgrimmar Smith", 1, true))
            _G.UnitFactionGroup = function() return "Horde" end
            text = ns.RecipeDB_Where(ns.RecipeDB_Get(102))[1].text
            assert.matches("Orgrimmar Smith %(Orgrimmar%)", text)
            assert.is_nil(text:find("Stormwind Smith", 1, true))
        end)

        it("lists several vendors, and how many more there are past five", function()
            local vendors = {}
            for i = 1, 7 do vendors[i] = { id = 20 + i, n = "Smith " .. i, z = { 46 } } end
            ns.RECIPE_DATA.items[901].v = vendors
            local text = ns.RecipeDB_Where(ns.RecipeDB_Get(102))[1].text
            assert.matches("Smith 5 %(Burning Steppes%)", text)
            assert.is_nil(text:find("Smith 6", 1, true))
            assert.matches("and 2 more", text)
        end)

        it("lists the quests of the character's side", function()
            local text = ns.RecipeDB_Where(ns.RecipeDB_Get(103))[1].text
            assert.are.equal("The Sword Quest", text)
            assert.are.same({ "The Sword Quest" }, { ns.RecipeDB_Where(ns.RecipeDB_Get(103))[1].entries[1].text })
        end)

        it("lists who drops it, with level and chance, and how many more there are", function()
            local line = ns.RecipeDB_Where(ns.RecipeDB_Get(101))[1]
            assert.are.equal("Drop", line.title)
            assert.matches("Black Drake %(Burning Steppes%) level 55%-57 %-%- 1%.25%%", line.text)
            assert.matches("Red Whelp %(Burning Steppes%) level 50", line.text)
            assert.matches("and 4 more", line.text)
            -- the panel puts each one on its own line
            assert.are.equal(2, #line.entries)
            assert.matches("^Black Drake %(Burning Steppes%) level 55%-57", line.entries[1].text)
            assert.are.equal(4, line.more)
        end)

        it("says so when nothing is known", function()
            ns.RECIPE_DATA.recipes[104] = { s = 171, n = "Mystery", c = { 1, 2, 3, 4 } }
            local lines = ns.RecipeDB_Where(ns.RecipeDB_Get(104))
            assert.are.equal("Unknown", lines[1].title)
        end)
    end)

    it("tells how a recipe looks at a given skill", function()
        local r = ns.RecipeDB_Get(100) -- 1, 55, 75, 95
        assert.are.equal(0, ns.RecipeDB_Difficulty(r, 1))
        assert.are.equal(0, ns.RecipeDB_Difficulty(r, 54))
        assert.are.equal(1, ns.RecipeDB_Difficulty(r, 55))
        assert.are.equal(2, ns.RecipeDB_Difficulty(r, 75))
        assert.are.equal(3, ns.RecipeDB_Difficulty(r, 95))
        assert.are.equal(3, ns.RecipeDB_Difficulty(r, 300))
    end)

    it("a recipe that skips colors goes from orange to grey", function()
        local r = { s = 165, n = "Medium Leather", c = { 100, 0, 0, 120 } }
        assert.are.equal(0, ns.RecipeDB_Difficulty(r, 119))
        assert.are.equal(3, ns.RecipeDB_Difficulty(r, 120))
        assert.are.equal(0, ns.RecipeDB_Difficulty({ s = 1, n = "No colors" }, 50))
    end)

    it("lists the professions in the data in order, with their names", function()
        assert.are.same({ 171, 164 }, ns.RecipeDB_Skills())
        assert.are.equal("Alchemy", ns.RecipeDB_SkillName(171))
        assert.are.equal("#999", ns.RecipeDB_SkillName(999))
        _G.C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function() return { professionName = "Alquimia" } end }
        assert.are.equal("Alquimia", ns.RecipeDB_SkillName(171))
    end)

    describe("search", function()
        local function names(results)
            local out = {}
            for _, r in ipairs(results) do out[#out + 1] = r.recipe.n end
            return out
        end

        it("finds by name, ignoring case, sorted by name", function()
            assert.are.same({ "Iron Sword", "Sword of Quests" }, names(ns.RecipeDB_Search("SWORD")))
        end)

        it("every word has to match", function()
            assert.are.same({ "Sword of Quests" }, names(ns.RecipeDB_Search("sword quests")))
            assert.are.same({}, names(ns.RecipeDB_Search("sword banana")))
        end)

        it("finds by ingredient", function()
            assert.are.same({ "Elixir of Wisdom" }, names(ns.RecipeDB_Search("peacebloom")))
            assert.are.same({ "Mighty Flask" }, names(ns.RecipeDB_Search("dreamfoil")))
        end)

        it("finds by who sells, drops or gives it, and by zone", function()
            assert.are.same({ "Mighty Flask" }, names(ns.RecipeDB_Search("black drake")))
            assert.are.same({ "Iron Sword" }, names(ns.RecipeDB_Search("alliance smith")))
            assert.are.same({ "Mighty Flask" }, names(ns.RecipeDB_Search("burning steppes")))
            assert.are.same({ "Sword of Quests" }, names(ns.RecipeDB_Search("sword quest")))
        end)

        it("can be limited to one profession", function()
            assert.are.same({ "Elixir of Wisdom", "Mighty Flask" }, names(ns.RecipeDB_Search("i", { skill = 171 })))
        end)

        it("can be limited to the recipes that use an item, even with no text", function()
            assert.are.same({ "Elixir of Wisdom" }, names(ns.RecipeDB_Search("", { ingredient = 10 })))
            assert.are.same({ "Mighty Flask" }, names(ns.RecipeDB_Search("", { ingredient = 12 })))
            assert.are.same({}, names(ns.RecipeDB_Search("", { ingredient = 999 })))
            assert.are.same({}, names(ns.RecipeDB_Search("flask", { ingredient = 10 })))
        end)

        describe("in the player's language", function()
            before_each(function()
                _G.C_Spell = { GetSpellName = function(id) return ({ [102] = "Espada de hierro", [103] = "Espada de misiones" })[id] end }
            end)
            after_each(function() _G.C_Spell = nil end)

            it("finds by the game's name and by the data's, sorted by the game's", function()
                assert.are.same({ "Iron Sword", "Sword of Quests" }, names(ns.RecipeDB_Search("espada")))
                assert.are.same({ "Iron Sword" }, names(ns.RecipeDB_Search("hierro")))
                assert.are.same({ "Iron Sword" }, names(ns.RecipeDB_Search("iron sword")))
                assert.are.equal("Espada de hierro", ns.RecipeDB_Search("hierro")[1].name)
            end)
        end)

        it("an empty search finds nothing", function()
            assert.are.same({}, ns.RecipeDB_Search(""))
            assert.are.same({}, ns.RecipeDB_Search("   "))
        end)
    end)
end)
