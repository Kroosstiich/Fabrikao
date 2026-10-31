dofile("setupTests.lua")

-- Integrity of Data/Vanilla/Generated/Recipes.lua and Data/TBC/Generated/Recipes.lua (Classic Era and TBC Anniversary): what the local
-- tool generates must have the shape the addon reads, as for Forever's (Data.test.lua).
for _, client in ipairs({
    {
        toc = "Fabrikao_Vanilla.toc", name = "Classic Era", recipes = 1200, items = 700, maxSkill = 300,
        skills = { 164, 165, 171, 185, 186, 197, 202, 333, 129, 40 },
    },
    {
        toc = "Fabrikao_TBC.toc", name = "TBC Anniversary", recipes = 1800, items = 1000, maxSkill = 375,
        skills = { 164, 165, 171, 185, 186, 197, 202, 333, 129, 40, 755 },
    },
}) do
    describe("Recipe data of " .. client.name, function()
        local db

        setup(function()
            WowMock.Reset()
            db = LoadAddon({ toc = client.toc }).RECIPE_DATA
        end)

        local function count(t)
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n
        end

        it("has the recipes, teaching items and trainers of the client", function()
            assert.is_true(count(db.recipes) > client.recipes)
            assert.is_true(count(db.items) > client.items)
            for _, skill in ipairs(client.skills) do
                local has = false
                for _, r in pairs(db.recipes) do
                    if r.s == skill then has = true break end
                end
                assert.is_true(has, "recipes of " .. skill)
                assert.is_truthy(db.trainers[skill] and #db.trainers[skill] > 0, "trainers of " .. skill)
            end
        end)

        it("has only the professions of the client", function()
            local allowed = {}
            for _, skill in ipairs(client.skills) do allowed[skill] = true end
            for id, r in pairs(db.recipes) do assert.is_true(allowed[r.s] == true, "recipe " .. id .. " of profession " .. r.s) end
        end)

        it("every recipe has its profession, a name, and four skill levels that don't go down", function()
            for id, r in pairs(db.recipes) do
                assert.is_truthy(type(r.s) == "number" and type(r.n) == "string" and r.n ~= "", "recipe " .. id)
                if r.c then
                    assert.are.equal(4, #r.c, "colors of " .. id)
                    local last = 0
                    for _, level in ipairs(r.c) do
                        if level > 0 then
                            assert.is_true(level >= last, "colors of " .. id .. " " .. r.n)
                            last = level
                        end
                    end
                    -- (a little over the profession's end is there: Naxxramas, the Ahn'Qiraj recipes)
                    assert.is_true(r.c[1] <= client.maxSkill + 25, "skill to learn " .. id .. " " .. r.n)
                end
            end
        end)

        it("every ingredient is an item id with a count, and the product too", function()
            for id, r in pairs(db.recipes) do
                assert.is_truthy((r.m and #r.m > 0) or r.p, "recipe " .. id .. " makes nothing and needs nothing")
                for _, m in ipairs(r.m or {}) do
                    assert.is_truthy(type(m[1]) == "number" and type(m[2]) == "number" and m[2] > 0, "reagent of " .. id)
                end
                if r.p then assert.is_truthy(type(r.p[1]) == "number" and r.p[2] >= 1 and r.p[3] >= r.p[2], "product of " .. id) end
            end
        end)

        it("the item that teaches a recipe exists, and no recipe is both a trainer's and a starter one", function()
            for id, r in pairs(db.recipes) do
                if r.i then assert.is_not_nil(db.items[r.i], "item " .. r.i .. " of recipe " .. id) end
                if r.k then
                    for _, code in ipairs(r.k) do assert.is_true(code == 6, "source of recipe " .. id) end
                end
            end
        end)

        it("every teaching item has a name and its sources are named", function()
            for id, item in pairs(db.items) do
                assert.is_truthy(type(item.n) == "string" and item.n ~= "", "item " .. id)
                for _, key in ipairs({ "v", "d", "o" }) do
                    for _, entry in ipairs(item[key] or {}) do
                        assert.is_truthy(type(entry.id) == "number" and type(entry.n) == "string", key .. " of item " .. id)
                    end
                end
                for _, quest in ipairs(item.qs or {}) do
                    assert.is_truthy(type(quest.id) == "number" and type(quest.n) == "string", "quest of item " .. id)
                end
            end
        end)

        it("the positions of the NPCs are a map id and coordinates in percent", function()
            local located = 0
            for id, spot in pairs(db.npcs) do
                located = located + 1
                assert.is_truthy(type(spot[1]) == "number" and spot[1] > 0, "map of npc " .. id)
                assert.is_truthy(type(spot[2]) == "number" and spot[2] >= 0 and spot[2] <= 100, "x of npc " .. id)
                assert.is_truthy(type(spot[3]) == "number" and spot[3] >= 0 and spot[3] <= 100, "y of npc " .. id)
            end
            assert.is_true(located > 300)
        end)

        it("the trainers have a name, a zone and a side that is A or H", function()
            for skill, list in pairs(db.trainers) do
                for _, trainer in ipairs(list) do
                    assert.is_truthy(type(trainer.id) == "number" and type(trainer.n) == "string", "trainer of " .. skill)
                    assert.is_truthy(type(trainer.z) == "table" and #trainer.z > 0, "zones of " .. trainer.n)
                    assert.is_truthy(trainer.f == nil or trainer.f == "A" or trainer.f == "H", "side of " .. trainer.n)
                end
            end
        end)

        it("the sources of an ingredient are for an ingredient of some recipe", function()
            local used = {}
            for _, r in pairs(db.recipes) do
                for _, m in ipairs(r.m or {}) do used[m[1]] = true end
            end
            local listed = 0
            for id, reagent in pairs(db.reagents) do
                listed = listed + 1
                assert.is_true(used[id] == true, "ingredient " .. id .. " is used by no recipe")
                for _, key in ipairs({ "v", "d" }) do
                    for _, entry in ipairs(reagent[key] or {}) do
                        assert.is_truthy(type(entry.id) == "number" and type(entry.n) == "string", key .. " of ingredient " .. id)
                    end
                end
                for _, node in ipairs(reagent.g or {}) do
                    assert.is_truthy(type(node.n) == "string" and type(node.z) == "table", "node of " .. id)
                end
                for _, made in ipairs(reagent.c or {}) do
                    assert.is_truthy(type(made.n) == "string" and type(made.i) == "number" and db.recipes[made.i], "maker of " .. id)
                end
            end
            assert.is_true(listed > 200)
        end)
    end)
end
