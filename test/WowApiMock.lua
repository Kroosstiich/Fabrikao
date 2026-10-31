-- Simulation of the game's API for the tests (busted or test/busted.lua). It doesn't try to be complete:
-- it covers what the addon uses. Frames are objects that accept any method: Set* stores its arguments
-- (in frame._set), Get*/Is* return what was stored or a sensible value, Create* creates children.
-- The "game" state lives in WowMock: level, faction, race, class, combat state, etc.
-- Compatible with Lua 5.1 (the game's version and CI's).

WowMock = {}
local unpackArgs = unpack or table.unpack -- luacheck: ignore 143 (Lua 5.1 lacks it; 5.2+ has it)
unpack = unpackArgs -- the game (Lua 5.1) has the global; newer Lua (local runs) doesn't

local function resetState()
    WowMock.level = 20
    WowMock.faction = "Alliance"
    WowMock.race = { "Human", "Human", 1 }
    WowMock.class = { "Mage", "MAGE", 8 }
    WowMock.cursor = { 0, 0 }
    WowMock.speed = 0
    WowMock.printed = {}
    WowMock.timers = {}
    WowMock.frames = {}
    WowMock.hooks = {}
    -- units of the "game": WowMock.units[token] = { name =, class = CLASSFILE, role =, exists =, dead =, hostile = },
    -- their threat on the mob: WowMock.threat[token] = { isTanking, status, scaledPct, rawPct, threatValue }
    WowMock.units = {}
    WowMock.threat = {}
    WowMock.group = nil -- nil = solo, { size = n, raid = bool }
    WowMock.sounds = {}
    WowMock.time = 0
    WowMock.inCombat = false
    WowMock.cvars = {}
end
resetState()
WowMock.Reset = resetState

-- Timers: run immediately by default (tests don't wait).
C_Timer = { After = function(_, f) f() end, NewTicker = function() return { Cancel = function() end } end }

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------
local frameMethods = {}

local function fire(self, name, ...)
    local s = self._scripts[name]
    if s then s(self, ...) end
    for _, h in ipairs(self._hooks[name] or {}) do h(self, ...) end
end
WowMock.Fire = fire

function frameMethods:RegisterEvent(event)
    if WowMock.unknownEvents and WowMock.unknownEvents[event] then
        error("Frame:RegisterEvent(): Attempt to register unknown event \"" .. event .. "\"")
    end
    self._events = self._events or {}
    self._events[event] = true
end
function frameMethods:UnregisterEvent(event) if self._events then self._events[event] = nil end end
function frameMethods:IsEventRegistered(event) return self._events ~= nil and self._events[event] == true end
function frameMethods:SetScript(name, f) self._scripts[name] = f end
function frameMethods:GetScript(name) return self._scripts[name] end
function frameMethods:HookScript(name, f)
    self._hooks[name] = self._hooks[name] or {}
    table.insert(self._hooks[name], f)
end
function frameMethods:Show()
    local was = self._shown
    self._shown = true
    if not was then fire(self, "OnShow") end
end
function frameMethods:Hide()
    local was = self._shown
    self._shown = false
    if was then fire(self, "OnHide") end
end
function frameMethods:SetShown(v) if v then self:Show() else self:Hide() end end
function frameMethods:IsShown() return self._shown end
function frameMethods:IsVisible()
    local f = self
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end
function frameMethods:GetParent() return self._parent end
function frameMethods:SetParent(parent) self._parent = parent end
function frameMethods:SetText(s)
    self._text = s
    if issecretvalue and issecretvalue(s) then self._shownSecret = true end -- (the game: its measures become hidden)
end
function frameMethods:GetText() return self._text end
function frameMethods:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function frameMethods:GetStringWidth()
    if self._shownSecret then error("attempt to perform numeric conversion on a secret number value") end
    return #(self._text or "") * 6
end
function frameMethods:GetStringHeight() return 14 end
function frameMethods:SetChecked(v) self._checked = v and true or false end
function frameMethods:GetChecked() return self._checked end
function frameMethods:SetEnabled(v) self._enabled = v and true or false end
function frameMethods:Enable() self._enabled = true end
function frameMethods:Disable() self._enabled = false end
function frameMethods:IsEnabled() return self._enabled ~= false end
function frameMethods:SetAlpha(a) self._alpha = a end
function frameMethods:GetAlpha() return self._alpha or 1 end
function frameMethods:SetSize(w, h) self._w, self._h = w, h end
function frameMethods:SetWidth(w) self._w = w end
function frameMethods:SetHeight(h) self._h = h end
function frameMethods:GetWidth() return self._w or 100 end
function frameMethods:GetHeight() return self._h or 20 end
function frameMethods:GetSize() return self:GetWidth(), self:GetHeight() end
function frameMethods:SetFrameLevel(l) self._level = l end
function frameMethods:GetFrameLevel() return self._level or 1 end
function frameMethods:SetScale(s) self._scale = s end
function frameMethods:GetScale() return self._scale or 1 end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:SetPoint(...) self._points = self._points or {}; table.insert(self._points, { ... }); self._set.SetPoint = { ... } end
function frameMethods:ClearAllPoints() self._points = {} end
function frameMethods:GetPoint(i) local p = self._points and self._points[i or 1]; if p then return unpackArgs(p) end end
function frameMethods:GetNumPoints() return self._points and #self._points or 0 end
function frameMethods:GetLeft() return 0 end
function frameMethods:GetTop() return 0 end
function frameMethods:GetRight() return self:GetWidth() end
function frameMethods:GetBottom() return 0 end
function frameMethods:GetCenter() return 100, 100 end
function frameMethods:GetHorizontalScroll() return self._hs or 0 end
function frameMethods:GetVerticalScroll() return self._vs or 0 end
function frameMethods:SetHorizontalScroll(v) self._hs = v end
function frameMethods:SetVerticalScroll(v) self._vs = v end
function frameMethods:IsMouseOver() return self._mouseOver or false end
function frameMethods:EnableMouse(v) self._mouse = v and true or false end
function frameMethods:IsMouseEnabled() return self._mouse or false end
function frameMethods:EnableMouseWheel(v) self._wheel = v and true or false end
function frameMethods:IsMouseWheelEnabled() return self._wheel or false end
-- child frames (not textures or font strings), as the game's GetChildren returns them
function frameMethods:GetChildren()
    local list = {}
    for _, f in ipairs(WowMock.frames) do
        if f._parent == self and f._kind ~= "Texture" and f._kind ~= "FontString" and f._kind ~= "Line"
            and f._kind ~= "MaskTexture" and f._kind ~= "AnimationGroup" then
            list[#list + 1] = f
        end
    end
    return unpackArgs(list)
end
function frameMethods:GetFontString() self._fontString = self._fontString or WowMock.NewFrame("FontString", nil, self); return self._fontString end
function frameMethods:GetNormalTexture() self._normal = self._normal or WowMock.NewFrame("Texture", nil, self); return self._normal end
function frameMethods:GetHighlightTexture() self._highlight = self._highlight or WowMock.NewFrame("Texture", nil, self); return self._highlight end
function frameMethods:GetThumbTexture() self._thumb = self._thumb or WowMock.NewFrame("Texture", nil, self); return self._thumb end
function frameMethods:Click(...) fire(self, "OnClick", ...) end
-- secure buttons keep their attributes by name
function frameMethods:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v end
function frameMethods:GetAttribute(k) return self._attrs and self._attrs[k] end
function frameMethods:GetObjectType() return self._kind end

local function methodFor(self, k)
    if frameMethods[k] then return frameMethods[k] end
    -- only methods (they start with a verb); an undefined field or child (TitleContainer, CloseButton...)
    -- is nil, as in the game
    if type(k) ~= "string" then return nil end
    local verbs = { "Set", "Get", "Is", "Has", "Can", "Create", "Register", "Unregister", "Enable", "Disable",
        "Start", "Stop", "Lock", "Unlock", "Raise", "Lower", "Play", "Add", "Clear", "Hook", "Adjust", "Update" }
    local isMethod = false
    for _, v in ipairs(verbs) do
        if k:sub(1, #v) == v and (k:len() == #v or k:sub(#v + 1, #v + 1):match("%u")) then isMethod = true break end
    end
    if not isMethod then return nil end
    if k:match("^Create") then
        return function(owner, ...)
            local kind = k:sub(7)
            if kind == "Line" or kind == "Texture" or kind == "FontString" or kind == "MaskTexture" or kind == "AnimationGroup" then
                return WowMock.NewFrame(kind, nil, owner)
            end
            return WowMock.NewFrame(kind, nil, owner)
        end
    end
    if k:match("^Set") then
        return function(owner, ...) owner._set[k] = { ... } end
    end
    if k:match("^Get") then
        return function(owner) local v = owner._set["S" .. k:sub(2)]; if v then return unpackArgs(v) end end
    end
    if k:match("^Is") or k:match("^Has") or k:match("^Can") then return function() return false end end
    -- the rest (Register*, Enable*, Start*, Stop*, Play, Lock*, Raise...): do nothing
    return function() end
end

-- The game's dropdown (WowStyle1DropdownTemplate, a DropdownButton with menus), when WowMock.menuDropdowns is on: SetupMenu runs
-- the generator on a root that records its entries in dropdown.menu = { { kind = "radio" | "checkbox" | "divider" | "title", text =,
-- selected =, choose = function() }... }; dropdown.shownText is what the button says (the translator's text for the selected
-- radio, else the default text).
local function addDropdownMethods(f)
    function f:SetSelectionTranslator(translator) self._translator = translator end
    function f:SetDefaultText(text) self._defaultText = text end
    function f:SetupMenu(generator) self._generator = generator; self:GenerateMenu() end
    function f:GenerateMenu()
        local menu = {}
        local root = {}
        function root.CreateRadio(_, text, isSelected, setSelected, data)
            menu[#menu + 1] = { kind = "radio", text = text, selected = isSelected(data), choose = function() setSelected(data) end }
        end
        function root.CreateCheckbox(_, text, isSelected, setSelected, data)
            menu[#menu + 1] = { kind = "checkbox", text = text, selected = isSelected(data), choose = function() setSelected(data) end }
        end
        function root.CreateDivider() menu[#menu + 1] = { kind = "divider" } end
        function root.CreateTitle(_, text) menu[#menu + 1] = { kind = "title", text = text } end
        self._generator(self, root)
        self.menu = menu
        self.shownText = self._defaultText
        for _, entry in ipairs(menu) do
            if entry.kind == "radio" and entry.selected and self._translator then self.shownText = self._translator(entry) end
        end
    end
end

function WowMock.NewFrame(kind, name, parent, template)
    local f = { _kind = kind, _name = name, _parent = parent, _template = template, _scripts = {}, _hooks = {},
        _set = {}, _shown = true }
    setmetatable(f, { __index = function(t, k) return methodFor(t, k) end })
    table.insert(WowMock.frames, f)
    if name then _G[name] = f end
    if template == "WowStyle1DropdownTemplate" and WowMock.menuDropdowns then addDropdownMethods(f) end
    -- the title of the game's framed windows: frame.TitleContainer.TitleText (a font string)
    if template == "UIPanelScrollFrameTemplate" then
        f.ScrollBar = WowMock.NewFrame("Slider", nil, f)
    end
    if template == "PortraitFrameFlatTemplate" then
        f.TitleContainer = { TitleText = WowMock.NewFrame("FontString", nil, f) }
    end
    return f
end

CreateFrame = function(kind, name, parent, template)
    if WowMock.missingTemplates and template and WowMock.missingTemplates[template] then
        error("template not available: " .. template)
    end
    return WowMock.NewFrame(kind, name, parent, template)
end

-- Finds created frames: by a predicate, or the first with that text.
function WowMock.Find(pred)
    for _, f in ipairs(WowMock.frames) do
        if pred(f) then return f end
    end
end
function WowMock.FindAll(pred)
    local list = {}
    for _, f in ipairs(WowMock.frames) do
        if pred(f) then list[#list + 1] = f end
    end
    return list
end
function WowMock.FindByText(text)
    return WowMock.Find(function(f) return f._text == text end)
end
function WowMock.FindButton(textPart)
    return WowMock.Find(function(f)
        return type(f._text) == "string" and f._text:find(textPart, 1, true) and f._scripts.OnClick ~= nil
    end)
end

UIParent = WowMock.NewFrame("Frame", "UIParent")
Minimap = WowMock.NewFrame("Frame", "Minimap")
GameTooltip = WowMock.NewFrame("GameTooltip", "GameTooltip")
GameTooltip_Hide = function() end
UISpecialFrames = {}

---------------------------------------------------------------------------------------------------
-- The game's functions and tables
---------------------------------------------------------------------------------------------------
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
hooksecurefunc = function(name, f)
    WowMock.hooks[name] = WowMock.hooks[name] or {}
    table.insert(WowMock.hooks[name], f)
    local original = _G[name]
    _G[name] = function(...)
        local r = { original(...) }
        for _, h in ipairs(WowMock.hooks[name]) do h(...) end
        return unpackArgs(r)
    end
end
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    table.insert(WowMock.printed, table.concat(parts, " "))
end
issecretvalue = nil

GetLocale = function() return WowMock.locale or "enUS" end
UnitLevel = function() return WowMock.level end
UnitFactionGroup = function() return WowMock.faction end
UnitRace = function() return unpackArgs(WowMock.race) end
-- WowMock.AddUnit("party1", "Thrall", "SHAMAN", "HEALER"): a unit that exists in the game
function WowMock.AddUnit(token, name, class, role, extra)
    local u = { name = name, class = class, role = role or "NONE" }
    for k, v in pairs(extra or {}) do u[k] = v end
    WowMock.units[token] = u
    return u
end
local function unitOf(token)
    if token == nil or token == "player" then
        return WowMock.units.player or { name = "Tester", class = WowMock.class[2], role = "NONE" }
    end
    return WowMock.units[token]
end
UnitExists = function(token) return unitOf(token) ~= nil end
UnitClass = function(token)
    local u = unitOf(token)
    if not u then return nil end
    if (token == nil or token == "player") and not WowMock.units.player then return unpackArgs(WowMock.class) end
    return u.class, u.class
end
UnitName = function(token) local u = unitOf(token); return u and u.name end
UnitIsUnit = function(a, b)
    local ua, ub = unitOf(a), unitOf(b)
    return a == b or (ua ~= nil and ua == ub)
end
UnitCanAttack = function(_, token) local u = unitOf(token); return u ~= nil and u.hostile == true end
UnitIsDead = function(token) local u = unitOf(token); return u ~= nil and u.dead == true end
UnitGroupRolesAssigned = function(token) local u = unitOf(token); return u and u.role or "NONE" end
UnitDetailedThreatSituation = function(token, mob)
    local t = WowMock.threat[token .. "@" .. tostring(mob)] or WowMock.threat[token] -- "player@nameplate1" = on that mob
    if t then return unpackArgs(t, 1, 5) end
end
IsInRaid = function() return WowMock.group ~= nil and WowMock.group.raid == true end
IsInGroup = function() return WowMock.group ~= nil end
GetNumGroupMembers = function() return WowMock.group and WowMock.group.size or 0 end
PlaySound = function(id, channel) table.insert(WowMock.sounds, { id, channel }) end
RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    PRIEST = { r = 1, g = 1, b = 1 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
}
CLOSE = "Close"
GetCVar = function(name) return WowMock.cvars[name] end
GetUnitSpeed = function() return WowMock.speed end
UnitAffectingCombat = function(token)
    if token == nil or token == "player" then return WowMock.inCombat or false end
    local u = unitOf(token)
    return u ~= nil and u.inCombat == true
end
UnitGUID = function(token) local u = unitOf(token); return u and (u.guid or token) end
UnitIsPlayer = function(token) local u = unitOf(token); return u ~= nil and u.npc ~= true and u.pet ~= true end
UnitPlayerControlled = function(token) local u = unitOf(token); return u ~= nil and u.npc ~= true end
InCombatLockdown = function() return WowMock.inCombat or false end
GetCursorPosition = function() return WowMock.cursor[1], WowMock.cursor[2] end
IsShiftKeyDown = function() return WowMock.shift or false end
IsControlKeyDown = function() return WowMock.ctrl or false end
GetRealmName = function() return "Realm" end
GetTime = function() return WowMock.time or 0 end
BreakUpLargeNumbers = function(n) return tostring(n) end

C_AddOns = { GetAddOnMetadata = function(_, key) return key == "Version" and "0.0.0-test" or nil end }
SlashCmdList = {}
