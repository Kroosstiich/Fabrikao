dofile("setupTests.lua")

-- On Classic Era and TBC, the tooltip of what a recipe makes also shows what the character wears in that slot.
describe("Compare with what is worn", function()
    local ns, compared, equippable, worn

    local function setup(flavor)
        WowMock.Reset()
        compared, equippable, worn = 0, true, false
        _G.ShoppingTooltip1 = WowMock.NewFrame("GameTooltip", "ShoppingTooltip1")
        _G.ShoppingTooltip2 = WowMock.NewFrame("GameTooltip", "ShoppingTooltip2")
        _G.GameTooltip_ShowCompareItem = function()
            compared = compared + 1
            ShoppingTooltip1:Show()
        end
        _G.IsEquippableItem = function() return equippable end
        GameTooltip.GetItem = function() return "Item", "|cff1eff00|Hitem:2302::::::::|h[Handstitched Leather Boots]|h|r" end
        GameTooltip.IsEquippedItem = function() return worn end
        ns = LoadAddon({ files = { "Modules/Tooltip/Compare.lua", "Modules/Data/RecipeDB.lua" } })
        ns.flavor = flavor or "tbc"
    end

    after_each(function()
        _G.GameTooltip_ShowCompareItem, _G.IsEquippableItem = nil, nil
        _G.ShoppingTooltip1, _G.ShoppingTooltip2 = nil, nil
        GameTooltip.GetItem, GameTooltip.IsEquippedItem = nil, nil
    end)

    it("asks for the comparison of a wearable item", function()
        setup()
        ns.Compare_Show(GameTooltip)
        assert.are.equal(1, compared)
    end)

    it("says that what it shows is what is worn", function()
        setup()
        ns.Compare_Show(GameTooltip)
        assert.is_truthy(ShoppingTooltip1.fabrikaoEquippedBar)
    end)

    it("restyles the line the client already puts on top", function()
        setup()
        _G.CURRENTLY_EQUIPPED = "Currently Equipped"
        ShoppingTooltip1.GetName = function() return "ShoppingTooltip1" end
        _G.ShoppingTooltip1TextLeft1 = WowMock.NewFrame("FontString", nil, ShoppingTooltip1)
        ShoppingTooltip1TextLeft1:SetText("Currently Equipped")
        ns.Compare_Show(GameTooltip)
        _G.CURRENTLY_EQUIPPED, _G.ShoppingTooltip1TextLeft1 = nil, nil
        assert.is_truthy(ShoppingTooltip1.fabrikaoEquippedStrip)
        assert.is_nil(ShoppingTooltip1.fabrikaoEquippedBar)
    end)

    it("does nothing on Forever, which compares by itself", function()
        setup("forever")
        ns.Compare_Show(GameTooltip)
        assert.are.equal(0, compared)
    end)

    it("does nothing for what cannot be worn, or is worn already", function()
        setup()
        equippable = false
        ns.Compare_Show(GameTooltip)
        equippable, worn = true, true
        ns.Compare_Show(GameTooltip)
        assert.are.equal(0, compared)
    end)

    it("does nothing while the client has not loaded the item", function()
        setup()
        GameTooltip.GetItem = function() return nil end
        ns.Compare_Show(GameTooltip)
        assert.are.equal(0, compared)
    end)

    it("goes away with the tooltip", function()
        setup()
        GameTooltip:Show()
        ns.Compare_Show(GameTooltip)
        assert.is_true(ShoppingTooltip1:IsShown())
        GameTooltip:Hide()
        assert.is_false(ShoppingTooltip1:IsShown())
    end)

    it("is asked for by the tooltip of what a recipe makes", function()
        setup()
        GameTooltip.SetItemByID = function() end
        local owner = WowMock.NewFrame("Button", nil, nil)
        ns.RecipeDB_ShowProductTooltip(owner, 2149, { p = { 2302, 1, 1 } })
        GameTooltip.SetItemByID = nil
        assert.are.equal(1, compared)
    end)
end)
