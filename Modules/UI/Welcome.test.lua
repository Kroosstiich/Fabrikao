dofile("setupTests.lua")

describe("Welcome", function()
    local ns, welcome

    before_each(function()
        WowMock.Reset()
        _G.FabrikaoWelcomeFrame = nil
        _G.GetProfessions = function() return nil end
        ns = LoadAddon()
        StartAddon(ns, nil, nil, { welcome = true })
        welcome = _G.FabrikaoWelcomeFrame
    end)

    it("is opaque: the welcome window of another addon behind it does not show through", function()
        assert.matches("ChatFrameBackground", welcome._set.SetBackdrop[1].bgFile)
        assert.are.equal(1, welcome._set.SetBackdropColor[4])
    end)

    it("comes in front of the welcome windows other addons showed before, with all its content", function()
        assert.is_true(welcome._set.SetToplevel[1])
        local raised = 0
        welcome.Raise = function() raised = raised + 1 end
        ns.Welcome_Show()
        assert.are.equal(1, raised)
    end)

    it("shows once by itself, the first time (or after a version bump)", function()
        assert.is_not_nil(welcome)
        assert.is_true(welcome:IsShown())
    end)

    it("the issue tracker URL is there to copy, under a note about reporting bugs", function()
        assert.are.equal("https://github.com/LechuckThePirate/Fabrikao/issues", welcome.urlBox:GetText())
        assert.matches("GitHub", welcome.body:GetText())
    end)

    it("says what's new in this version, with the changelog under it", function()
        assert.matches("What's new in v", welcome.changelogLabel:GetText())
        assert.matches("in the game.s language", welcome.changelogText:GetText())
    end)

    it("links to the other three addons, and not to itself", function()
        local urls = {}
        for _, box in ipairs(welcome.siblingBoxes) do urls[#urls + 1] = box:GetText() end
        assert.are.same({
            "https://www.curseforge.com/wow/addons/embolsao",
            "https://www.curseforge.com/wow/addons/completao-forever",
            "https://www.curseforge.com/wow/addons/aggreao",
        }, urls)
        assert.matches("More addons by the same author", welcome.siblingsLabel:GetText())
    end)

    it("selects a link when clicked, so it can be copied", function()
        local box = welcome.siblingBoxes[1]
        local highlighted = false
        box.HighlightText = function() highlighted = true end
        box._scripts.OnEditFocusGained(box)
        assert.is_true(highlighted)
    end)

    it("Don't show this again remembers the version, and clearing it forgets", function()
        local check = welcome.dontShowAgainCheck
        check:SetChecked(true); check:Click()
        assert.are.equal(ns.Version(), FabrikaoDB.welcomeDismissedVersion)
        check:SetChecked(false); check:Click()
        assert.are.equal("", FabrikaoDB.welcomeDismissedVersion)
    end)

    it("does not show again once dismissed for this version, but does after a version bump", function()
        welcome:Hide()
        FabrikaoDB.welcomeDismissedVersion = ns.Version()
        local savedDB = FabrikaoDB

        _G.FabrikaoWelcomeFrame = nil
        local ns2 = LoadAddon()
        StartAddon(ns2, savedDB, nil, { welcome = true })
        assert.is_nil(_G.FabrikaoWelcomeFrame)

        savedDB.welcomeDismissedVersion = "0.0.0-old"
        local ns3 = LoadAddon()
        StartAddon(ns3, savedDB, nil, { welcome = true })
        assert.is_true(_G.FabrikaoWelcomeFrame:IsShown())
    end)

    it("/fab changelog reopens it even if dismissed", function()
        welcome:Hide()
        FabrikaoDB.welcomeDismissedVersion = ns.Version()
        SlashCmdList.FABRIKAO("changelog")
        assert.is_true(welcome:IsShown())
    end)

    it("the preferences have a button for it", function()
        welcome:Hide()
        ns.Prefs_Toggle()
        local button = WowMock.Find(function(f) return f._text == "What's new" and f._scripts.OnClick ~= nil end)
        assert.is_not_nil(button)
        button._scripts.OnClick(button)
        assert.is_true(welcome:IsShown())
    end)
end)
