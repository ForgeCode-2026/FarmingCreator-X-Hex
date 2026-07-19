function Locale(key, ...)
    local texts = Locales and Locales[Config.Locale]
    local text = texts and texts[key]
    if not text then
        return key
    end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then
            return formatted
        end
        return text
    end
    return text
end
