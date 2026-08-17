local BASE_URL = "https://raw.githubusercontent.com/oneTime999/PcdFnlBoss/refs/heads/main/src/"
local BUILD = "1.2.1"

local ENV = getgenv and getgenv() or _G

if ENV.PcdFnlBossApp then
    pcall(function()
        if ENV.PcdFnlBossApp.Core then
            ENV.PcdFnlBossApp.Core:StopAll()
        end
    end)

    pcall(function()
        if ENV.PcdFnlBossApp.Starlight then
            ENV.PcdFnlBossApp.Starlight:Destroy()
        end
    end)

    ENV.PcdFnlBossApp = nil
end

local function LoadModule(name)
    local url = BASE_URL .. name .. ".lua?build=" .. BUILD

    local success, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not success then
        error(
            "[Pcd Fnl Boss] Failed to download module '" ..
            name ..
            "': " ..
            tostring(source)
        )
    end

    local compiled, compileError = loadstring(source)

    if not compiled then
        error(
            "[Pcd Fnl Boss] Failed to compile module '" ..
            name ..
            "': " ..
            tostring(compileError)
        )
    end

    local moduleSuccess, module = pcall(compiled)

    if not moduleSuccess then
        error(
            "[Pcd Fnl Boss] Failed to execute module '" ..
            name ..
            "': " ..
            tostring(module)
        )
    end

    return module
end

print("[Pcd Fnl Boss] Starting v" .. BUILD)

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
    Build = BUILD,
}

ENV.PcdFnlBossApp = App

Core:Init(App)
AutoBuy:Init(App)
Bosses:Init(App)

print("[Pcd Fnl Boss] Modules loaded")
print("[Pcd Fnl Boss] Creating interface...")

UI:Init(App)

print("[Pcd Fnl Boss] Successfully loaded v" .. BUILD)
