local BASE_URL = "https://raw.githubusercontent.com/oneTime999/PcdFnlBoss/refs/heads/main/src/"
local ENV = (getgenv and getgenv()) or _G

local function cleanupOldApp()
    local old = ENV.PcdFnlBossApp

    if type(old) ~= "table" then
        return
    end

    pcall(function()
        if old.Core and old.Core.Destroy then
            old.Core:Destroy()
        elseif old.Core and old.Core.StopAll then
            old.Core:StopAll()
        end
    end)

    pcall(function()
        if old.Rayfield and old.Rayfield.Destroy then
            old.Rayfield:Destroy()
        end
    end)

    pcall(function()
        if old.Starlight and old.Starlight.Destroy then
            old.Starlight:Destroy()
        end
    end)

    ENV.PcdFnlBossApp = nil
    task.wait(0.15)
end

local function loadModule(name, cacheToken)
    local url = BASE_URL .. name .. ".lua?cb=" .. cacheToken

    local httpOk, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not httpOk then
        error("[Pcd Fnl Boss] HTTP error [" .. name .. "]: " .. tostring(source))
    end

    if type(source) ~= "string" or source == "" then
        error("[Pcd Fnl Boss] Empty module [" .. name .. "]")
    end

    local head = string.lower(source:sub(1, 256))

    if string.find(head, "<!doctype", 1, true)
        or string.find(head, "<html", 1, true) then
        error("[Pcd Fnl Boss] Invalid HTML response [" .. name .. "]")
    end

    local chunk, compileError = loadstring(source)

    if not chunk then
        error("[Pcd Fnl Boss] Compile error [" .. name .. "]: " .. tostring(compileError))
    end

    local runOk, module = pcall(chunk)

    if not runOk then
        error("[Pcd Fnl Boss] Runtime error [" .. name .. "]: " .. tostring(module))
    end

    if type(module) ~= "table" then
        error("[Pcd Fnl Boss] Invalid module [" .. name .. "]: expected table")
    end

    return module
end

cleanupOldApp()

local cacheToken = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

local Config = loadModule("config", cacheToken)
local Core = loadModule("core", cacheToken)
local Selection = loadModule("selection", cacheToken)
local AutoBuy = loadModule("autobuy", cacheToken)
local Bosses = loadModule("bosses", cacheToken)
local UI = loadModule("ui", cacheToken)

local App = {
    Config = Config,
    Core = Core,
    Selection = Selection,
    AutoBuy = AutoBuy,
    Bosses = Bosses,
    UI = UI,
}

ENV.PcdFnlBossApp = App

local startupOk, startupError = pcall(function()
    Core:Init(App)
    Selection:Init(App)
    AutoBuy:Init(App)
    Bosses:Init(App)
    UI:Init(App)
end)

if not startupOk then
    pcall(function()
        Core:Destroy()
    end)

    pcall(function()
        if App.Rayfield and App.Rayfield.Destroy then
            App.Rayfield:Destroy()
        end
    end)

    ENV.PcdFnlBossApp = nil
    error("[Pcd Fnl Boss] Startup failed: " .. tostring(startupError))
end

print("[Pcd Fnl Boss] Loaded v" .. tostring(Config.Version))
