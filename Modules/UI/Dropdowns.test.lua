dofile("setupTests.lua")

-- The category filter and the filters as dropdowns (the game's menus), and as buttons when the game has no menu templates.
describe("Filter dropdowns", function()
    local ns

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Gloves A", c = { 1, 55, 75, 95 }, p = { 301, 1, 1 }, m = { { 10, 1 } }, k = { 6 } },
            [2] = { s = 171, n = "Bag B", c = { 1, 20, 40, 60 }, p = { 302, 1, 1 }, m = { { 10, 1 } }, k = { 5 } },
            [3] = { s = 171, n = "Potion C", c = { 1, 30, 50, 70 }, p = { 303, 1, 1 }, m = { { 10, 1 } }, k = { 4 } },
            [4] = { s = 171, n = "Robe D", c = { 1, 40, 60, 80 }, p = { 304, 1, 1 }, m = { { 10, 1 } }, k = { 6 } },
            [5] = { s = 171, n = "Enchant Bracer - Health", c = { 1, 40, 60, 80 }, m = { { 10, 1 } }, k = { 6 } },
            [6] = { s = 171, n = "Mystery", c = { 1, 40, 60, 80 }, p = { 999, 1, 1 }, m = { { 10, 1 } }, k = { 6 } },
        },
        items = {}, trainers = {},
    }
    -- what the game says of the items: itemID, type, subtype, equip location, icon, class id, subclass id
    local ITEMS = {
        [301] = { "Armor", "Leather", "INVTYPE_HAND", 0, 4, 2 },
        [302] = { "Container", "Bag", "INVTYPE_BAG", 0, 1, 0 },
        [303] = { "Consumable", "Potion", "", 0, 0, 1 },
        [304] = { "Armor", "Cloth", "INVTYPE_ROBE", 0, 4, 1 },
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f, button) f._scripts.OnClick(f, button or "LeftButton") end

    local function recipeNames()
        local out = {}
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" then out[#out + 1] = row.data.recipe.name end
        end
        return out
    end

    local function dropdowns()
        return WowMock.FindAll(function(f) return f._template == "WowStyle1DropdownTemplate" and f:IsVisible() end)
    end

    local function entry(dropdown, text)
        for _, e in ipairs(dropdown.menu) do if e.text == text then return e end end
    end

    local function texts(dropdown)
        local list = {}
        for _, e in ipairs(dropdown.menu) do list[#list + 1] = e.text or "-" end
        return list
    end

    local function setup(menus)
        WowMock.Reset()
        WowMock.menuDropdowns = menus
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 60, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 1 end }
        _G.INVTYPE_HAND, _G.INVTYPE_CHEST, _G.INVTYPE_WRIST = "Hands", "Chest", "Wrist"
        _G.C_Item = {
            GetItemCount = function() return 0 end,
            GetItemNameByID = function(id) return "Item" .. id end,
            GetItemInfoInstant = function(id)
                local item = ITEMS[id]
                if item then return id, item[1], item[2], item[3], item[4], item[5], item[6] end
            end,
        }
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
        ns.UI_Toggle()
        click(visible("profession")[1])
    end

    after_each(function() WowMock.menuDropdowns = nil end)

    describe("the category of a recipe", function()
        before_each(function() setup(false) end)

        it("is the slot of armor, bags, the kind of consumable, the enchanted slot, or other", function()
            assert.are.equal("Hands", ns.RecipeDB_Category(DATA.recipes[1]))
            assert.are.equal("Bags", ns.RecipeDB_Category(DATA.recipes[2]))
            assert.are.equal("Potion", ns.RecipeDB_Category(DATA.recipes[3]))
            assert.are.equal("Chest", ns.RecipeDB_Category(DATA.recipes[4])) -- a robe is a chest
            assert.are.equal("Wrist", ns.RecipeDB_Category(DATA.recipes[5])) -- an enchantment: from its name
            assert.are.equal("Other", ns.RecipeDB_Category(DATA.recipes[6])) -- the game knows nothing of the item
        end)

        it("is on every recipe of the page, with the set of them on the copy", function()
            local copy = ns.Recipes_Cached(171) or ns.Recipes_FromData(171, 60)
            assert.are.same({ Bags = true, Chest = true, Hands = true, Other = true, Potion = true, Wrist = true }, copy.categories)
        end)

        it("filters the rows", function()
            local copy = ns.Recipes_FromData(171, 60)
            local rows = ns.Recipes_Rows(copy, { known = true, unknown = true, category = "Bags" })
            local names = {}
            for _, row in ipairs(rows) do if row.kind == "recipe" then names[#names + 1] = row.recipe.name end end
            assert.are.same({ "Bag B" }, names)
        end)
    end)

    describe("without the game's menus (buttons)", function()
        before_each(function() setup(false) end)

        it("the category button goes through the categories of the profession", function()
            local button = WowMock.FindButton("Category:")
            assert.matches("All", button._text)
            click(button)
            assert.are.equal("Category: Bags", button._text)
            assert.are.same({ "Bag B" }, recipeNames())
            click(button)
            assert.are.same({ "Robe D" }, recipeNames()) -- Chest
        end)

        it("Clear brings the category back to all", function()
            local button = WowMock.FindButton("Category:")
            click(button)
            click(WowMock.FindButton("Clear"))
            assert.are.equal("Category: All", button._text)
            assert.are.equal(6, #recipeNames())
        end)
    end)

    describe("with the game's menus", function()
        before_each(function() setup(true) end)

        it("source, category, color, skill and sort are dropdowns", function()
            assert.are.equal(5, #dropdowns())
            assert.is_nil(WowMock.FindButton("Source:"))
        end)

        it("the category dropdown lists All and the categories, and choosing one filters", function()
            local category = dropdowns()[2]
            assert.are.same({ "All", "Bags", "Chest", "Hands", "Other", "Potion", "Wrist" }, texts(category))
            assert.are.equal("Category: All", category.shownText)
            assert.is_true(entry(category, "All").selected)
            entry(category, "Hands").choose()
            assert.are.same({ "Gloves A" }, recipeNames())
            assert.are.equal("Category: Hands", category.shownText)
            assert.is_true(entry(category, "Hands").selected)
            assert.is_false(entry(category, "All").selected)
            assert.is_nil(ns.char.filters.category) -- depends on the profession: not kept
        end)

        it("the source dropdown filters by where the recipes are learned", function()
            local source = dropdowns()[1]
            assert.are.same({ "All", "Quest", "Vendor", "Trainer" }, texts(source))
            entry(source, "Quest").choose()
            assert.are.same({ "Potion C" }, recipeNames())
            assert.are.equal("Source: Quest", source.shownText)
        end)

        it("the skill dropdown says what it filters", function()
            local skill = dropdowns()[4]
            assert.are.equal("Skill: All", skill.shownText)
            entry(skill, "Needs more skill").choose()
            assert.are.equal("Needs more skill", skill.shownText)
            entry(skill, "All").choose()
            assert.are.equal("Skill: All", skill.shownText)
        end)

        it("the sort dropdown picks the key, and a checkbox turns the order around", function()
            local sort = dropdowns()[5]
            assert.are.same({ "Default", "Name", "Level", "Cost", "AH value", "Can make", "-", "Descending" }, texts(sort))
            entry(sort, "Name").choose()
            assert.are.equal("name", ns.char.filters.sort.key)
            assert.are.equal("Sort: Name ^", sort.shownText)
            assert.is_false(entry(sort, "Descending").selected)
            entry(sort, "Descending").choose()
            assert.is_true(ns.char.filters.sort.desc)
            assert.are.equal("Sort: Name v", sort.shownText)
            assert.is_true(entry(sort, "Descending").selected)
        end)

        -- An open menu built again from the addon's code is built tainted, and with the gamepad UI on the game then blocks the
        -- addon when the menu closes: the game updates an open dropdown itself after a pick, so the addon leaves it alone.
        it("a choice in an open menu does not build that menu again", function()
            local sort, skill = dropdowns()[5], dropdowns()[4]
            sort:OpenMenu()
            local generated, others = sort.generated, skill.generated
            entry(sort, "Name").choose()
            assert.are.equal(generated, sort.generated)
            assert.are.equal("Sort: Name ^", sort.shownText)
            assert.is_true(entry(sort, "Name").selected)
            entry(sort, "Descending").choose()
            assert.are.equal(generated, sort.generated)
            assert.are.equal("Sort: Name v", sort.shownText)
            assert.is_true(entry(sort, "Descending").selected)
            assert.is_true(skill.generated > others) -- (the closed ones still show the change)
            sort:CloseMenu()
            entry(sort, "Level").choose()
            assert.is_true(sort.generated > generated)
            assert.are.equal("Sort: Level ^", sort.shownText)
        end)

        it("Clear shows everything again in all of them", function()
            entry(dropdowns()[2], "Bags").choose()
            entry(dropdowns()[1], "Vendor").choose()
            click(WowMock.FindButton("Clear"))
            assert.are.equal("Category: All", dropdowns()[2].shownText)
            assert.are.equal("Source: All", dropdowns()[1].shownText)
            assert.are.equal(6, #recipeNames())
        end)
    end)
end)
