local _, ns = ...
local L = ns.L

-- What the character wears next to the tooltip of an item it could craft (armor, weapons, anything wearable), as Retail and Forever do by
-- themselves. The Classic clients only compare from their own bag buttons, so the tooltips of this addon ask for it (the same as Embolsao).

-- Makes a comparison tooltip say loudly that it is what you wear, so it can't be mistaken for the item under the cursor. Where the client
-- already starts it with a small grey "Currently Equipped", that line is restyled (big, white, on a colored strip); otherwise a title bar
-- goes on top of it.
local function labelEquipped(shopping)
    if not shopping or not shopping:IsShown() then return end
    local name = shopping:GetName()
    local first = name and _G[name .. "TextLeft1"]
    local firstText = first and first.GetText and first:GetText()
    if firstText and (firstText == L["Equipped"] or firstText == _G.CURRENTLY_EQUIPPED) then
        first:SetFontObject("GameFontHighlightLarge")
        local strip = shopping.fabrikaoEquippedStrip
        if not strip then
            strip = shopping:CreateTexture(nil, "BORDER")
            strip:SetColorTexture(0.1, 0.5, 0.15, 0.85)
            strip:SetPoint("TOPLEFT", shopping, "TOPLEFT", 4, -4)
            strip:SetPoint("TOPRIGHT", shopping, "TOPRIGHT", -4, -4)
            shopping.fabrikaoEquippedStrip = strip
        end
        strip:SetHeight(first:GetStringHeight() + 8)
        strip:Show()
        shopping:Show() -- (the bigger font changes its size: measure it again)
        return
    end

    local bar = shopping.fabrikaoEquippedBar
    if not bar then
        bar = CreateFrame("Frame", nil, shopping, "BackdropTemplate")
        bar:SetHeight(22)
        bar:SetPoint("BOTTOMLEFT", shopping, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMRIGHT", shopping, "TOPRIGHT", 0, 0)
        bar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        bar:SetBackdropColor(0, 0, 0, 0.9)
        local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(L["Equipped"])
        shopping.fabrikaoEquippedBar = bar
    end
    bar:Show()
end

local shown = false
local hooked = false

-- The comparison goes away with the tooltip. Hooked on the first comparison, not at load: an addon's OnHide hook on the
-- game's tooltip taints the Blizzard code that hides it, and on Forever (which never compares here) that blocked the bank
-- ("Fabrikao has been blocked from an action", PurchaseBankTab when the banker's tooltip hid).
local function hookHide(tooltip)
    if hooked or not tooltip.HookScript then return end
    hooked = true
    pcall(tooltip.HookScript, tooltip, "OnHide", function()
        if not shown then return end
        shown = false
        for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
            local shopping = _G[name]
            if shopping and shopping.Hide then shopping:Hide() end
        end
    end)
end

-- Shows what the character wears in the slot (both slots for rings, trinkets and weapons) of the item in `tooltip`, when it is wearable
-- and not worn. Only on the Classic clients.
function ns.Compare_Show(tooltip)
    if not ns.IsClassic() then return end
    if not tooltip or not GameTooltip_ShowCompareItem or not IsEquippableItem or not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if not link or not IsEquippableItem(link) then return end
    if tooltip.IsEquippedItem and tooltip:IsEquippedItem() then return end
    hookHide(tooltip)
    GameTooltip_ShowCompareItem(tooltip)
    shown = true
    labelEquipped(_G.ShoppingTooltip1)
    labelEquipped(_G.ShoppingTooltip2)
end
