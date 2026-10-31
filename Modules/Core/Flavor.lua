local _, ns = ...

-- Which game client this is, from the interface number (the first part of GetBuildInfo's 4th value): the data that
-- is loaded depends on it (Load_Data_<Flavor>.xml, picked by the toc) and a few features do too.
--   "forever" (16xxx), "vanilla" (Classic Era, 11xxx), "tbc" (TBC Anniversary, 20xxx), "mainline" (Retail, 10xxxx+).
-- nil for any other client.
function ns.DetectFlavor(interface)
    if type(interface) ~= "number" then return nil end
    if interface >= 100000 then return "mainline" end
    local major = math.floor(interface / 10000)
    if major == 1 then
        local minor = math.floor(interface / 1000)
        if minor == 11 then return "vanilla" end
        if minor == 16 then return "forever" end
    elseif major == 2 then
        return "tbc"
    end
    return nil
end

ns.flavor = ns.DetectFlavor(GetBuildInfo and select(4, GetBuildInfo()))

function ns.IsFlavor(name)
    return ns.flavor == name
end

-- Classic Era and TBC Anniversary: the clients that have the old professions API (see Modules/Professions/Classic.lua) instead of
-- Forever's retail one. Asked at run time, never at load, so the same files serve every client.
function ns.IsClassic()
    return ns.flavor == "vanilla" or ns.flavor == "tbc"
end
