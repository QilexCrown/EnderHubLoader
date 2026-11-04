--[[
    Language index — returns a builder that the loader calls with (fetch, compile).
    Each bundle is a flat table of loc: keys, so the whole UI repaints on language switch.
]]

return function(fetch, compile)
    local order = {
        "en", "es", "ar", "ru", "de", "fr", "he", "id",
        "it", "nl", "pl", "pt", "tr", "vi", "zh",
    }
    local bundles = {}

    for _, code in ipairs(order) do
        local rel = "languages/" .. code .. ".luau"
        local ok, data = pcall(function()
            local src = fetch(rel)
            local chunk = compile(src, rel)
            return chunk()
        end)
        if ok and type(data) == "table" then
            bundles[code] = data
        else
            warn("[enderhub] language bundle " .. code .. " failed: " .. tostring(data))
        end
    end

    if not bundles.en then
        error("[enderhub] english bundle is required", 0)
    end

    return {
        Enabled = true,
        Prefix = "loc:",
        DefaultLanguage = "en",
        Translations = bundles,
    }
end
