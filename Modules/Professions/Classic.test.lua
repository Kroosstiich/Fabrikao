dofile("setupTests.lua")

-- Classic Era and TBC Anniversary: the professions are skill lines, the recipes a character knows are what its profession windows list,
-- and the window opens from a secure overlay on the Craft buttons.
describe("Classic clients", function()
    local ns, trade, craft, spellbook

    local DATA = {
        recipes = {
            [2259] = { s = 171, n = "Alchemy Thing", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
            [3101] = { s = 171, n = "Elixir of Lion's Strength", c = { 10, 30, 50, 70 }, m = { { 11, 1 } }, k = { 6 } },
            [2549] = { s = 185, n = "Boiled Clams", c = { 1, 20, 40, 60 }, m = { { 12, 1 } }, k = { 6 } },
            [7418] = { s = 333, n = "Enchant Bracer - Minor Health", c = { 1, 10, 20, 30 }, m = { { 13, 1 } }, k = { 6 } },
            [2018] = { s = 164, n = "Copper Bracers", c = { 1, 20, 40, 60 }, m = { { 14, 1 } }, k = { 6 } },
        },
        items = {}, trainers = {}, npcs = {},
    }

    local function link(id) return "|cffffd000|Henchant:" .. id .. "|h[x]|h|r" end

    -- the skill lines the game lists: { name, header, expanded, rank, max, abandonable }
    local function skillRows(rows)
        _G.GetNumSkillLines = function() return #rows end
        _G.GetSkillLineInfo = function(i)
            local r = rows[i]
            return r[1], r[2], r[3], r[4], 0, 0, r[5], r[6]
        end
        _G.ExpandSkillHeader = function(i) rows[i][3] = true end
    end

    -- a trade skill window with these lines: { name, kind, spell, expanded }
    local function tradeWindow(lines, shown)
        trade = lines
        _G.TradeSkillFrame = WowMock.NewFrame("Frame", "TradeSkillFrame", nil)
        _G.TradeSkillFrame:SetShown(shown ~= false)
        _G.GetNumTradeSkills = function() return #trade end
        _G.GetTradeSkillInfo = function(i) local l = trade[i]; return l[1], l[2], 0, l[4] end
        _G.GetTradeSkillRecipeLink = function(i) return trade[i][3] and link(trade[i][3]) end
        _G.GetTradeSkillLine = function() return "Alquimia", 120, 150 end
        _G.ExpandTradeSkillSubClass = function(i) trade[i][4] = true end
        _G.CollapseTradeSkillSubClass = function(i) trade[i][4] = false end
    end

    local function craftWindow(lines)
        craft = lines
        _G.CraftFrame = WowMock.NewFrame("Frame", "CraftFrame", nil)
        _G.CraftFrame:Show()
        _G.GetNumCrafts = function() return #craft end
        _G.GetCraftInfo = function(i) local l = craft[i]; return l[1], "", l[2], 0, l[4] end
        _G.GetCraftItemLink = function(i) return craft[i][3] and link(craft[i][3]) end
        _G.GetCraftDisplaySkillLine = function() return "Encantamiento", 50, 75 end
        _G.ExpandCraftSkillLine = function(i) craft[i][4] = true end
        _G.CollapseCraftSkillLine = function(i) craft[i][4] = false end
    end

    local function setup(flavor)
        WowMock.Reset()
        trade, craft, spellbook = nil, nil, {}
        for _, name in ipairs({ "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillRecipeLink", "GetTradeSkillLine", "TradeSkillFrame",
            "ExpandTradeSkillSubClass", "CollapseTradeSkillSubClass", "GetNumCrafts", "GetCraftInfo", "GetCraftItemLink", "CraftFrame",
            "GetCraftDisplaySkillLine", "ExpandCraftSkillLine", "CollapseCraftSkillLine", "GetProfessions", "GetProfessionInfo",
            "C_TradeSkillUI", "C_SpellBook", "C_Spell", "TradeSkillFrame_SetSelection", "TradeSkillFrame_Update", "CraftFrame_SetSelection",
            "CraftFrame_Update" }) do
            _G[name] = nil
        end
        _G.IsPlayerSpell = function(id) return spellbook[id] == true end
        _G.IsSpellKnown = nil
        _G.GetSpellInfo = function(id)
            return ({ [2259] = "Alquimia", [3908] = "Sastrería", [2550] = "Cocina", [7411] = "Encantar", [2656] = "Fundir", [2018] = "Herrería" })[id]
        end
        _G.GetSpellTexture = function(id) return 1000 + id end
        _G.C_Item = {
            GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end,
        }
        _G.C_Map = { GetAreaInfo = function() return "Stormwind City" end, GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB, _G.TomTom, _G.CompletaoAPI = nil, nil, nil, nil
        skillRows({})
        ns = LoadAddon()
        ns.flavor = flavor or "vanilla"
        ns.RECIPE_DATA = DATA
        StartAddon(ns)
    end

    local function names(list)
        local out = {}
        for _, p in ipairs(list) do out[#out + 1] = p.name end
        return out
    end

    describe("which client", function()
        it("is classic on Classic Era and on TBC Anniversary, not on Forever", function()
            setup("vanilla")
            assert.is_true(ns.IsClassic())
            ns.flavor = "tbc"
            assert.is_true(ns.IsClassic())
            ns.flavor = "forever"
            assert.is_false(ns.IsClassic())
            ns.flavor = nil
            assert.is_false(ns.IsClassic())
        end)

        it("loads the tocs of the three clients", function()
            for _, toc in ipairs({ "Fabrikao.toc", "Fabrikao_Vanilla.toc", "Fabrikao_TBC.toc" }) do
                local files = TocFiles(toc)
                assert.is_true(#files > 25, toc)
                for _, file in ipairs(files) do
                    local handle = io.open(file)
                    assert.is_truthy(handle, toc .. " lists " .. file)
                    handle:close()
                end
            end
            local last = function(toc) local f = TocFiles(toc); return f[#f] end
            assert.are.equal("Fabrikao.lua", last("Fabrikao_TBC.toc"))
        end)
    end)

    describe("the professions", function()
        it("are the skill lines of the game's skills list that are professions", function()
            setup()
            skillRows({
                { "Professions", true, true },
                { "Alchemy", false, false, 120, 150, true },
                { "Cooking", false, false, 40, 75, false },
                { "Fishing", false, false, 1, 75, false },
                { "Swords", false, false, 100, 100, false },
            })
            local list = ns.Professions_Mine()
            assert.are.same({ "Alchemy", "Cooking", "Fishing" }, names(list))
            assert.are.equal(171, list[1].skillLine)
            assert.are.equal(120, list[1].rank)
            assert.are.equal(150, list[1].maxRank)
            assert.is_true(list[1].primary)
            assert.is_false(list[2].primary)
            assert.is_true(list[1].hasRecipes)
            assert.is_false(list[3].hasRecipes) -- Fishing: nothing to craft
        end)

        it("lists the primary ones first", function()
            setup()
            skillRows({
                { "Cooking", false, false, 40, 75, false },
                { "Blacksmithing", false, false, 10, 75, true },
            })
            assert.are.same({ "Blacksmithing", "Cooking" }, names(ns.Professions_Mine()))
        end)

        it("opens a folded header to see the skills in it", function()
            setup()
            local rows = {
                { "Professions", true, false },
                { "Alchemy", false, false, 120, 150, true },
            }
            skillRows(rows)
            -- (the game hides the skills of a folded header)
            _G.GetNumSkillLines = function() return rows[1][3] and 2 or 1 end
            assert.are.same({ "Alchemy" }, names(ns.Professions_Mine()))
            assert.is_true(rows[1][3])
        end)

        it("know the name the game gives the spell: the player's language", function()
            setup()
            skillRows({ { "Alquimia", false, false, 75, 150, true }, { "Cocina", false, false, 10, 75, false } })
            assert.are.same({ "Alquimia", "Cocina" }, names(ns.Professions_Mine()))
            assert.are.equal("Alquimia", ns.RecipeDB_SkillName(171))
            assert.are.equal("Mining", ns.RecipeDB_SkillName(186)) -- (the client has no other name for it here)
        end)

        it("have the icon of the profession's spell", function()
            setup()
            skillRows({ { "Alchemy", false, false, 1, 75, true } })
            assert.are.equal(1000 + 2259, ns.Professions_Mine()[1].icon)
        end)

        it("are not taken from the retail list, which the Classic clients do not have", function()
            setup()
            _G.GetProfessions = function() return 1 end
            _G.GetProfessionInfo = function() return "Alchemy", 1, 1, 1, 1, 1, 171 end
            skillRows({})
            assert.are.same({}, ns.Professions_Mine())
        end)

        it("are still the retail list on Forever", function()
            setup("forever")
            _G.GetProfessions = function() return 1 end
            _G.GetProfessionInfo = function() return "Alchemy", 1, 120, 150, 1, 1, 171 end
            assert.are.same({ "Alchemy" }, names(ns.Professions_Mine()))
        end)

        it("remember a name learned from a window the addon did not know", function()
            setup()
            skillRows({ { "Alquimia Avanzada", false, false, 75, 150, true } })
            assert.are.same({}, ns.Professions_Mine())
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 }, { "Elixir", "easy", 3101 } })
            _G.GetTradeSkillLine = function() return "Alquimia Avanzada", 120, 150 end
            ns.Classic_Scan()
            assert.are.same({ "Alquimia Avanzada" }, names(ns.Professions_Mine()))
            assert.are.equal(171, FabrikaoDB.skillAliases["alquimia avanzada"])
        end)
    end)

    describe("the recipes known", function()
        it("are the ones the open profession window lists", function()
            setup()
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 }, { "Elixir", "easy", 3101 }, { "Boiled Clams", "header", nil, true } })
            assert.is_false(ns.RecipeDB_Known(2259))
            assert.are.equal(2, ns.Classic_Scan())
            assert.is_true(ns.RecipeDB_Known(2259))
            assert.is_true(ns.RecipeDB_Known(3101))
            assert.is_false(ns.RecipeDB_Known(2549))
            assert.is_true(FabrikaoCharDB.knownRecipes[2259])
        end)

        it("are also read from the craft window (Enchanting, Poisons)", function()
            setup()
            craftWindow({ { "Enchant Bracer - Minor Health", "optimal", 7418, true } })
            assert.are.equal(1, ns.Classic_Scan())
            assert.is_true(ns.RecipeDB_Known(7418))
        end)

        it("add up between windows and are kept", function()
            setup()
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 } })
            ns.Classic_Scan()
            tradeWindow({ { "Elixir", "easy", 3101 } })
            assert.are.equal(1, ns.Classic_Scan())
            assert.is_true(ns.RecipeDB_Known(2259))
            assert.is_true(ns.RecipeDB_Known(3101))
        end)

        it("leave out what the data does not have", function()
            setup()
            tradeWindow({ { "Mystery", "optimal", 99999 } })
            assert.are.equal(0, ns.Classic_Scan())
        end)

        it("are not read from a window that is closed", function()
            setup()
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 } }, false)
            assert.are.equal(0, ns.Classic_Scan())
        end)

        it("include the lines under a folded header, which is folded again after", function()
            setup()
            local lines = {
                { "Potions", "header", nil, false },
                { "Elixir", "easy", 3101 },
            }
            tradeWindow(lines)
            -- (the game lists the lines under a folded header only when it is open)
            _G.GetNumTradeSkills = function() return lines[1][4] and 2 or 1 end
            assert.are.equal(1, ns.Classic_Scan())
            assert.is_true(ns.RecipeDB_Known(3101))
            assert.is_false(lines[1][4])
        end)

        it("are also the spells the client says the character knows", function()
            setup()
            spellbook[2549] = true
            assert.is_true(ns.RecipeDB_Known(2549))
            assert.is_false(ns.RecipeDB_Known(2259))
        end)

        it("are scanned when the window shows or updates", function()
            setup()
            ns.Classic_Start()
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 } })
            FireEvent("TRADE_SKILL_SHOW")
            assert.is_true(FabrikaoCharDB.knownRecipes[2259])
            craftWindow({ { "Enchant Bracer - Minor Health", "optimal", 7418 } })
            FireEvent("CRAFT_UPDATE")
            assert.is_true(FabrikaoCharDB.knownRecipes[7418])
        end)

        it("are saved for the roster as soon as they are found", function()
            setup()
            skillRows({ { "Alchemy", false, false, 120, 150, true } })
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 } })
            ns.Classic_Scan()
            local record = FabrikaoDB.characters["Tester-Realm"]
            assert.are.same({ 2259 }, record.professions[1].known)
        end)

        it("are forgotten with a profession the character dropped", function()
            setup()
            FabrikaoCharDB.knownRecipes = { [2259] = true, [2018] = true }
            skillRows({ { "Blacksmithing", false, false, 10, 75, true } })
            ns.Professions_Mine()
            assert.is_nil(FabrikaoCharDB.knownRecipes[2259])
            assert.is_true(FabrikaoCharDB.knownRecipes[2018])
        end)

        it("are kept when a primary profession could not be named", function()
            setup()
            FabrikaoCharDB.knownRecipes = { [2259] = true }
            skillRows({ { "Nombre Desconocido", false, false, 10, 75, true } })
            ns.Professions_Mine()
            assert.is_true(FabrikaoCharDB.knownRecipes[2259])
        end)

        it("are kept while the skills list is not there yet", function()
            setup()
            FabrikaoCharDB.knownRecipes = { [2259] = true }
            skillRows({})
            ns.Professions_Mine()
            assert.is_true(FabrikaoCharDB.knownRecipes[2259])
        end)

        it("come from the spell book, as before, on Forever", function()
            setup("forever")
            _G.C_SpellBook = { IsSpellKnown = function(id) return id == 2549 end }
            FabrikaoCharDB.knownRecipes = { [2259] = true }
            assert.is_true(ns.RecipeDB_Known(2549))
            assert.is_false(ns.RecipeDB_Known(2259))
        end)
    end)

    describe("who teaches a recipe", function()
        local function trainerNames(recipe)
            for _, line in ipairs(ns.RecipeDB_Where(recipe, true)) do
                if line.title == ns.L["Trainer"] then
                    local out = {}
                    for _, entry in ipairs(line.entries) do out[#out + 1] = entry.name end
                    table.sort(out)
                    return out
                end
            end
            return {}
        end

        it("is every trainer of the profession when the data does not say which", function()
            setup()
            ns.RECIPE_DATA = {
                recipes = { [1] = { s = 185, n = "Soup", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } } },
                items = {}, npcs = {},
                trainers = { [185] = { { id = 7, n = "Eunice", z = { 9001 } }, { id = 8, n = "Ghilm", z = { 9002 } } } },
            }
            assert.are.same({ "Eunice", "Ghilm" }, trainerNames(ns.RecipeDB_Get(1)))
        end)

        it("is only those the data names when it does (Classic Era and TBC)", function()
            setup()
            ns.RECIPE_DATA = {
                recipes = { [1] = { s = 185, n = "Soup", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 }, t = { 8 } } },
                items = {}, npcs = {},
                trainers = { [185] = { { id = 7, n = "Eunice", z = { 9001 } }, { id = 8, n = "Ghilm", z = { 9002 } } } },
            }
            assert.are.same({ "Ghilm" }, trainerNames(ns.RecipeDB_Get(1)))
        end)

        it("makes the nearest of those the key to order the recipes you can learn by", function()
            setup()
            ns.RECIPE_DATA = {
                recipes = { [1] = { s = 185, n = "Soup", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 }, t = { 8 } } },
                items = {}, npcs = { [7] = { 1453, 1, 1 }, [8] = { 1453, 2, 2 } },
                trainers = { [185] = { { id = 7, n = "Eunice", z = { 9001 } }, { id = 8, n = "Ghilm", z = { 9002 } } } },
            }
            ns.Map_Distance = function(spot) return spot.x == 1 and 10 or 500 end
            local recipe = ns.RecipeDB_Get(1)
            assert.are.equal(500, ns.RecipeDB_TeacherKey(recipe, ns.RecipeDB_TrainerKey(185)))
            recipe.t = nil -- (every trainer of the profession: the nearest one, Eunice)
            assert.are.equal(10, ns.RecipeDB_TeacherKey(recipe, ns.RecipeDB_TrainerKey(185)))
        end)
    end)

    describe("the recipes lists", function()
        it("come from the data, with what the windows said is known", function()
            setup()
            skillRows({ { "Alchemy", false, false, 120, 150, true } })
            FabrikaoCharDB.knownRecipes = { [3101] = true }
            local copy
            ns.Recipes_Request(171, function(c) copy = c end, { name = "Alchemy", rank = 120 })
            assert.are.equal(1, #copy.known)
            assert.are.equal("Elixir of Lion's Strength", copy.known[1].name)
            assert.are.equal(1, #copy.unknown)
        end)
    end)

    describe("crafting", function()
        local function click(button) button.secure._scripts.PostClick(button.secure) end -- (the game runs it after the secure cast)

        it("puts a secure overlay on the button that casts the profession's spell", function()
            setup()
            local button = WowMock.NewFrame("Button", nil, nil)
            local secure = ns.Craft_Secure(button)
            assert.are.equal(secure, button.secure)
            assert.are.equal("spell", secure:GetAttribute("type"))
            assert.is_false(secure:IsShown())
            ns.Craft_Prepare(button, 2259, 171)
            assert.are.equal("Alquimia", secure:GetAttribute("spell"))
            assert.is_true(secure:IsShown())
            ns.Craft_Prepare(button, 2549, 185)
            assert.are.equal("Cocina", secure:GetAttribute("spell"))
            ns.Craft_Prepare(button, 7418, 333)
            assert.are.equal("Encantar", secure:GetAttribute("spell"))
        end)

        it("opens Mining with the spell of Smelting", function()
            setup()
            local button = WowMock.NewFrame("Button", nil, nil)
            ns.Craft_Secure(button)
            ns.Craft_Prepare(button, 100, 186)
            assert.are.equal("Fundir", button.secure:GetAttribute("spell"))
        end)

        it("hides the overlay when there is nothing to craft", function()
            setup()
            local button = WowMock.NewFrame("Button", nil, nil)
            ns.Craft_Secure(button)
            ns.Craft_Prepare(button, 2259, 171)
            ns.Craft_Prepare(button, nil, 171)
            assert.is_false(button.secure:IsShown())
        end)

        it("leaves the spell as it was during combat: the game locks it", function()
            setup()
            local button = WowMock.NewFrame("Button", nil, nil)
            ns.Craft_Secure(button)
            ns.Craft_Prepare(button, 2259, 171)
            _G.InCombatLockdown = function() return true end
            ns.Craft_Prepare(button, 2549, 185)
            _G.InCombatLockdown = nil
            assert.are.equal("Alquimia", button.secure:GetAttribute("spell"))
        end)

        it("picks the recipe in the window once it is up", function()
            setup()
            tradeWindow({ { "Alchemy Thing", "optimal", 2259 }, { "Elixir", "easy", 3101 } })
            local picked
            _G.TradeSkillFrame_SetSelection = function(i) picked = i end
            _G.TradeSkillFrame_Update = function() end
            local button = WowMock.NewFrame("Button", nil, nil)
            ns.Craft_Secure(button)
            ns.Craft_Prepare(button, 3101, 171)
            click(button)
            assert.are.equal(2, picked)
        end)

        it("acts once per click, on the half of the click the game acts on", function()
            setup()
            tradeWindow({ { "Elixir", "easy", 3101 } })
            local picks = 0
            _G.TradeSkillFrame_SetSelection = function() picks = picks + 1 end
            local button = WowMock.NewFrame("Button", nil, nil)
            ns.Craft_Secure(button)
            ns.Craft_Prepare(button, 3101, 171)
            local post = button.secure._scripts.PostClick
            _G.GetCVarBool = function() return true end -- (on the key down)
            post(button.secure, "LeftButton", true)
            post(button.secure, "LeftButton", false)
            assert.are.equal(1, picks)
            _G.GetCVarBool = function() return false end -- (on the key up)
            post(button.secure, "LeftButton", true)
            post(button.secure, "LeftButton", false)
            _G.GetCVarBool = nil
            assert.are.equal(2, picks)
        end)

        it("picks it in the craft window too", function()
            setup()
            craftWindow({ { "Enchant Bracer - Minor Health", "optimal", 7418 } })
            local picked
            _G.CraftFrame_SetSelection = function(i) picked = i end
            assert.is_true(ns.Craft_Open(7418, 333))
            assert.are.equal(1, picked)
        end)

        it("says so when no window is open", function()
            setup()
            assert.is_false(ns.Craft_Open(3101, 171))
            assert.is_truthy(WowMock.printed[#WowMock.printed])
        end)

        it("has no overlay on Forever", function()
            setup("forever")
            local button = WowMock.NewFrame("Button", nil, nil)
            assert.is_nil(ns.Craft_Secure(button))
            assert.is_nil(button.secure)
            ns.Craft_Prepare(button, 2259, 171) -- (nothing to do)
        end)
    end)
end)
