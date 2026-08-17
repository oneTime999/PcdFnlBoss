local BASE_URL = "https://raw.githubusercontent.com/oneTime999/PcdFnlBoss/refs/heads/main/src/"
local BUILD = "1.5.0"

local ENV = (getgenv and getgenv()) or _G
local CACHE_BUSTER = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

local function safeCleanup(app)
    if type(app) ~= "table" then
        return
    end

    pcall(function()
        if app.Core and app.Core.StopAll then
            app.Core:StopAll()
        end
    end)

    pcall(function()
        if app.Rayfield and app.Rayfield.Destroy then
            app.Rayfield:Destroy()
        end
    end)

    -- Compatibility cleanup for builds that still used Starlight.
    pcall(function()
        if app.Starlight and app.Starlight.Destroy then
            app.Starlight:Destroy()
        end
    end)
end

if ENV.PcdFnlBossApp then
    safeCleanup(ENV.PcdFnlBossApp)
    ENV.PcdFnlBossApp = nil
    task.wait(0.15)
end

local function loadModule(name)
    local url = BASE_URL .. name .. ".lua?build=" .. BUILD .. "&cb=" .. CACHE_BUSTER

    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        error("[Pcd Fnl Boss] HTTP error while loading " .. name .. ": " .. tostring(source))
    end

    if type(source) ~= "string" or source == "" then
        error("[Pcd Fnl Boss] Empty source returned for module: " .. name)
    end

    local lower = string.lower(source:sub(1, 200))

    if string.find(lower, "<!doctype", 1, true)
        or string.find(lower, "<html", 1, true) then
        error("[Pcd Fnl Boss] Invalid HTML response while loading module: " .. name)
    end

    local chunk, compileError = loadstring(source)

    if not chunk then
        error("[Pcd Fnl Boss] Compile error in " .. name .. ": " .. tostring(compileError))
    end

    local runOk, module = pcall(chunk)

    if not runOk then
        error("[Pcd Fnl Boss] Runtime error in " .. name .. ": " .. tostring(module))
    end

    if type(module) ~= "table" then
        error("[Pcd Fnl Boss] Module " .. name .. " did not return a table")
    end

    return module
end

print("[Pcd Fnl Boss] Starting v" .. BUILD)

local Config = loadModule("config")
local Core = loadModule("core")
local AutoBuy = loadModule("autobuy")
local Bosses = loadModule("bosses")
local UI = loadModule("ui")

local App = {
    Build = BUILD,
    Config = Config,
    Core = Core,
    AutoBuy = AutoBuy,
    Bosses = Bosses,
}

ENV.PcdFnlBossApp = App

local ok, err = pcall(function()
    Core:Init(App)
    AutoBuy:Init(App)
    Bosses:Init(App)
    UI:Init(App)
end)

if not ok then
    safeCleanup(App)
    ENV.PcdFnlBossApp = nil
    error("[Pcd Fnl Boss] Startup failed: " .. tostring(err))
end

print("[Pcd Fnl Boss] Loaded successfully - v" .. BUILD)
