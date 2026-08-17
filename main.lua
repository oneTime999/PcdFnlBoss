local BASE_URL = "https://raw.githubusercontent.com/oneTime999/PcdFnlBoss/refs/heads/main/src/"

local function LoadModule(name)
    local url = BASE_URL .. name .. ".lua"

    local success, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error("[Pcd Fnl Boss] Failed to download module '" .. name .. "': " .. tostring(source))
    end

    local compiled, compileError = loadstring(source)

    if not compiled then
        error("[Pcd Fnl Boss] Failed to compile module '" .. name .. "': " .. tostring(compileError))
    end

    return compiled()
end

local Config = LoadModule("config")
local Core = LoadModule("core")
local AutoBuy = LoadModule("autobuy")
local Bosses = LoadModule("bosses")
local UI = LoadModule("ui")

local App = {
    Config = Config,
    Core = Core,
    AutoBuy = AutoBuy,
    Bosses = Bosses,
}

Core:Init(App)
AutoBuy:Init(App)
Bosses:Init(App)
UI:Init(App)
