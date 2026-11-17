dofile("setupTests.lua")

describe("Locale", function()
    before_each(function() WowMock.Reset() end)

    it("in English returns the key itself", function()
        local ns = LoadAddon({ files = { "Localization/Locale.lua" } })
        assert.are.equal("initializing...", ns.L["initializing..."])
        assert.are.equal("Any text", ns.L["Any text"])
    end)

    it("on esES and esMX uses Spanish", function()
        for _, locale in ipairs({ "esES", "esMX" }) do
            WowMock.locale = locale
            local ns = LoadAddon({ files = { "Localization/Locale.lua" } })
            assert.are.equal("inicializando...", ns.L["initializing..."])
            assert.are.equal("Untranslated text", ns.L["Untranslated text"])
        end
    end)

    it("on frFR uses French, and only there", function()
        local files = { "Localization/Locale.lua", "Localization/Locale.fr.lua" }
        WowMock.locale = "frFR"
        local ns = LoadAddon({ files = files })
        assert.are.equal("initialisation...", ns.L["initializing..."])
        assert.are.equal("Untranslated text", ns.L["Untranslated text"])
        WowMock.locale = "esES"
        ns = LoadAddon({ files = files })
        assert.are.equal("inicializando...", ns.L["initializing..."])
    end)

    -- Keys of a translation file (a translation can equal the English one) that the code uses but it lacks.
    local function untranslated(localeFile)
        local translated = {}
        for key in io.open(localeFile):read("*a"):gmatch('%["(.-)"%]%s*=') do translated[key] = true end
        local missing, seen = {}, {}
        for _, file in ipairs(TocFiles()) do
            if not file:match("^Localization/") then
                local text = io.open(file):read("*a")
                for key in text:gmatch('L%["(.-)"%]') do
                    if not translated[key] and not seen[key] then
                        seen[key] = true
                        missing[#missing + 1] = key .. "  (" .. file .. ")"
                    end
                end
            end
        end
        return missing
    end

    it("every string the code uses has a Spanish translation", function()
        assert.are.same({}, untranslated("Localization/Locale.lua"), "untranslated")
    end)

    it("every string the code uses has a French translation", function()
        assert.are.same({}, untranslated("Localization/Locale.fr.lua"), "untranslated")
    end)
end)
