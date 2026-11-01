local _, ns = ...
local L = ns.L

-- Crafting happens in the game's own profession window: the game does not let an addon craft (C_TradeSkillUI.CraftRecipe is blocked:
-- "Interface action failed because of an AddOn"), and the secure workaround casts only one at a time. So the addon's "Craft" button opens
-- that window already on the recipe, the way the game does it for its own alerts and objective tracker (ProfessionsUtil).

-- (Classic Era and TBC Anniversary open the window from a secure overlay on the buttons: ns.Craft_Secure / ns.Craft_Prepare, Classic.lua.)

-- Opens the game's profession window on the profession (not on a recipe). False when there is no way.
local function openProfession(skillLine)
    if skillLine and _G.OpenProfessionUIToSkillLine then
        return pcall(_G.OpenProfessionUIToSkillLine, skillLine)
    end
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        return pcall(C_TradeSkillUI.OpenTradeSkill, skillLine)
    end
    return false
end

-- Opens the profession window with the recipe selected, ready to craft there. \`skillLine\` (the recipe's profession) is the way out
-- when the game's own helper can't place it. Tells the player when nothing could be opened. Returns whether something was.
function ns.Craft_Open(recipeID, skillLine)
    if ns.IsClassic() then
        -- the window opens from the secure overlay of the button (ns.Craft_Secure); here the recipe is picked in it
        if ns.Classic_Select(recipeID) then return true end
        ns.Print(L["Could not open the profession window."])
        return false
    end
    local util = _G.ProfessionsUtil
    if util and util.OpenProfessionFrameToRecipe then
        local ok, opened = pcall(util.OpenProfessionFrameToRecipe, recipeID)
        if ok and opened then return true end
    end
    if openProfession(skillLine) then return true end
    ns.Print(L["Could not open the profession window."])
    return false
end
