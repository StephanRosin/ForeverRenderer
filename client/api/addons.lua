-- Addon-Liste (C_AddOns) aus den geladenen TOC-Dateien.
local A = {}

function A.Install(state, env)
    local Ld = require("loader")
    local function info(name)
        if type(name) == "number" then name = Ld.order[name] end
        return name, name and Ld.toc[name]
    end
    _G.C_AddOns = _G.C_AddOns or {}
    C_AddOns.GetAddOnMetadata = function(name, key)
        local _, toc = info(name)
        return toc and toc.meta[key]
    end
    C_AddOns.IsAddOnLoaded = function(name)
        local n = info(name)
        local loaded = n and Ld.loaded[n] or false
        return loaded, loaded
    end
    C_AddOns.GetNumAddOns = function() return #Ld.order end
    C_AddOns.GetAddOnInfo = function(name)
        local n, toc = info(name)
        if not toc then return nil end
        return n, toc.meta.Title or n, toc.meta.Notes, true, nil, "INSECURE", false
    end
    C_AddOns.LoadAddOn = function(name) return Ld.loaded[name] or false, Ld.loaded[name] and nil or "MISSING" end
    C_AddOns.EnableAddOn = function() end
    C_AddOns.DisableAddOn = function() end
    C_AddOns.GetAddOnEnableState = function(name) return Ld.loaded[name] and 2 or 0 end
    C_AddOns.IsAddOnLoadable = function(name) return Ld.toc[name] ~= nil end
    C_AddOns.DoesAddOnExist = function(name) return Ld.toc[name] ~= nil end
    _G.GetAddOnMetadata = C_AddOns.GetAddOnMetadata
    _G.IsAddOnLoaded = C_AddOns.IsAddOnLoaded
end

return A
