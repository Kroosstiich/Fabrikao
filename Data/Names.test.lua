dofile("setupTests.lua")

-- Data/.../Generated/Names.lua (tools/classic/build_names.mjs): the world objects of each client's recipe data in other languages.
describe("Object names", function()
    for _, client in ipairs({ { toc = "Fabrikao.toc" }, { toc = "Fabrikao_Vanilla.toc" }, { toc = "Fabrikao_TBC.toc" } }) do
        describe(client.toc, function()
            local ns

            setup(function()
                WowMock.Reset()
                ns = LoadAddon({ toc = client.toc })
            end)
            teardown(function() WowMock.locale = nil end)

            it("are loaded, as [locale][English name] = name, with Spanish among them", function()
                assert.are.equal("table", type(ns.OBJECT_NAMES))
                assert.are.equal("table", type(ns.OBJECT_NAMES.esES))
                for locale, names in pairs(ns.OBJECT_NAMES) do
                    assert.is_truthy(locale:match("^%l%l%u%u$"), locale)
                    for english, name in pairs(names) do
                        assert.is_truthy(type(english) == "string" and type(name) == "string" and name ~= "", locale .. " " .. tostring(english))
                    end
                end
            end)

            it("name the objects of the data (and only those)", function()
                local inData = {}
                for _, item in pairs(ns.RECIPE_DATA.items) do
                    for _, o in ipairs(item.o or {}) do inData[o.n] = true end
                end
                for _, reagent in pairs(ns.RECIPE_DATA.reagents or {}) do
                    for _, g in ipairs(reagent.g or {}) do inData[g.n] = true end
                end
                for english in pairs(ns.OBJECT_NAMES.esES) do assert.is_true(inData[english], english) end
            end)

            it("give a Spanish client the Spanish name", function()
                local english, spanish = next(ns.OBJECT_NAMES.esES)
                WowMock.locale = "esES"
                assert.are.equal(spanish, ns.ObjectName(english))
                WowMock.locale = nil
                assert.are.equal(english, ns.ObjectName(english))
            end)
        end)
    end
end)
