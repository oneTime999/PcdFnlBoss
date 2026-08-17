local BASE_URL = "https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPOSITORIO/main/src/"

local function LoadModule(name)
    return loadstring(game:HttpGet(BASE_URL .. name .. ".lua"))()
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
