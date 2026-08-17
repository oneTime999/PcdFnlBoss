local Selection = {}

local function cleanString(value)
    if type(value) ~= "string" then
        return nil
    end

    local cleaned = value:match("^%s*(.-)%s*$")

    if cleaned == "" then
        return nil
    end

    return cleaned
end

function Selection:Init(App)
    self.App = App
    self.Values = {}
    self.Lookup = {}
end

function Selection:Normalize(values)
    local ordered = {}
    local seen = {}

    if type(values) ~= "table" then
        values = {}
    end

    for key, value in pairs(values) do
        local candidate

        if type(value) == "string" then
            candidate = value
        elseif value == true and type(key) == "string" then
            candidate = key
        end

        candidate = cleanString(candidate)

        if candidate then
            local normalized = string.lower(candidate)

            if not seen[normalized] then
                seen[normalized] = true
                ordered[#ordered + 1] = candidate
            end
        end
    end

    return ordered
end

function Selection:Set(key, values)
    local ordered = self:Normalize(values)
    local lookup = {}

    for _, value in ipairs(ordered) do
        lookup[string.lower(value)] = true
    end

    self.Values[key] = ordered
    self.Lookup[key] = lookup

    return ordered
end

function Selection:Get(key)
    local source = self.Values[key] or {}
    local copy = {}

    for index, value in ipairs(source) do
        copy[index] = value
    end

    return copy
end

function Selection:Contains(key, value)
    if type(value) ~= "string" then
        return false
    end

    local lookup = self.Lookup[key]

    if not lookup then
        return false
    end

    return lookup[string.lower(value)] == true
end

function Selection:FilterToOptions(key, options)
    local allowed = {}

    for _, option in ipairs(options or {}) do
        if type(option) == "string" then
            allowed[string.lower(option)] = option
        end
    end

    local filtered = {}

    for _, selected in ipairs(self:Get(key)) do
        local canonical = allowed[string.lower(selected)]

        if canonical then
            filtered[#filtered + 1] = canonical
        end
    end

    return self:Set(key, filtered)
end

function Selection:Clear(key)
    self.Values[key] = {}
    self.Lookup[key] = {}
end

return Selection
