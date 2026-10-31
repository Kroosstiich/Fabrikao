-- Loading the addon in tests: the files in TOC order (like the game), each with ("Fabrikao", ns).
-- LoadAddon() loads everything (LoadAddon({ toc = "Fabrikao_Vanilla.toc" }) for another client's toc);
-- LoadAddon({ files = {...} }) only those files (with the core ones in front: Flavor, Compat and Locale). StartAddon(ns) simulates entering the game.

-- The .xml files of the toc (Load_*.xml: <Script file> and <Include file>, paths relative to the xml) are
-- expanded in place, like the game does.
local function addFiles(path, files)
    path = path:gsub("\\", "/")
    if not path:match("%.xml$") then
        files[#files + 1] = path
        return
    end
    local dir = path:match("^(.*/)[^/]*$") or ""
    local handle = assert(io.open(path))
    local xml = handle:read("*a"):gsub("<!%-%-.-%-%->", "")
    handle:close()
    for tag, ref in xml:gmatch('<(%a+)%s+file="([^"]+)"') do
        if tag == "Script" or tag == "Include" then addFiles(dir .. ref, files) end
    end
end

-- The Lua files the toc loads, in order. `toc` picks another toc (default Fabrikao.toc).
function TocFiles(toc)
    local files = {}
    for line in io.lines(toc or "Fabrikao.toc") do
        line = line:gsub("%s+$", "") -- also drops the CR of CRLF files
        if line ~= "" and not line:match("^##") then addFiles(line, files) end
    end
    return files
end

function LoadAddon(opts)
    opts = opts or {}
    local ns = {}
    local files = opts.files
    if files then
        -- (the files every module counts on: which client this is, the compat queries and the text)
        local withCore = { "Modules/Core/Flavor.lua", "Modules/Core/Compat.lua", "Localization/Locale.lua" }
        for _, f in ipairs(files) do
            if f ~= withCore[1] and f ~= withCore[2] and f ~= withCore[3] then withCore[#withCore + 1] = f end
        end
        files = withCore
    else
        files = TocFiles(opts.toc)
    end
    for _, f in ipairs(files) do
        local chunk = assert(loadfile(f))
        chunk("Fabrikao", ns)
    end
    return ns
end

-- Every frame that registered the event and has an OnEvent receives it (as if the game fired it).
function FireEvent(event, ...)
    for _, f in ipairs(WowMock.frames) do
        local handler = f._scripts.OnEvent
        if handler and f._events and f._events[event] then handler(f, event, ...) end
    end
end

-- ADDON_LOADED + PLAYER_ENTERING_WORLD, with fresh saved variables (or the ones passed in). The welcome window is dismissed
-- for this version unless opts.welcome: it would be one more window among the ones the tests look at.
function StartAddon(ns, db, charDB, opts)
    FabrikaoDB, FabrikaoCharDB = db, charDB
    FireEvent("ADDON_LOADED", "Fabrikao")
    if not (opts and opts.welcome) then FabrikaoDB.welcomeDismissedVersion = ns.Version() end
    FireEvent("PLAYER_ENTERING_WORLD")
    return ns
end
