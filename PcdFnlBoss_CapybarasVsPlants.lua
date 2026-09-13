--[[
    Pcd Fnl Boss - Capybaras Vs Plants
    First hub build using the modified Fluent-based Pcd Fnl Boss UI.

    Features:
    - Dynamic Capybara shop scanner + multi-select auto buy
    - Dynamic Gear shop scanner + multi-select auto buy
    - Merchant multi-select auto buy (known items + dynamic scan)
    - Buys the full displayed stock amount
    - Anti-AFK
    - Auto refresh of shop options
    - SaveManager / InterfaceManager
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- Clean up an older execution of this hub.
if ENV.PcdFnlBossCVP and type(ENV.PcdFnlBossCVP.Destroy) == "function" then
    pcall(function()
        ENV.PcdFnlBossCVP:Destroy()
    end)
    task.wait(0.15)
end

local Fluent = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/oneTime999/PcdFnlBossUI/refs/heads/main/main.lua"
))()

local SaveManager = Fluent.SaveManager
local InterfaceManager = Fluent.InterfaceManager

local App = {
    Name = "Pcd Fnl Boss",
    Game = "Capybaras Vs Plants",
    Version = "1.0.0",
    Destroyed = false,

    State = {
        AutoBuyCapybaras = false,
        AutoBuyGears = false,
        AutoBuyMerchant = false,
        AntiAFK = false,
    },

    Selection = {
        Capybaras = {},
        Gears = {},
        Merchant = {},
    },

    Workers = {},
    Connections = {},
    RemoteLastCall = {},
    LastPurchaseSignature = {},
}

ENV.PcdFnlBossCVP = App

local Config = {
    BuyLoop = 1.5,
    BuyRemoteDelay = 0.15,
    SameStockCooldown = 2.5,
    DynamicOptionsRefresh = 3.0,

    Shops = {
        Capybaras = {
            UIName = "EggShop",
            Remote = "BuyItem",
        },
        Gears = {
            UIName = "GearShop",
            Remote = "BuyItem",
        },
        Merchant = {
            UIName = "MerchantShop",
            Remote = "BuyMerchantItem",
        },
    },

    MerchantFallback = {
        "Gilded Hatch Hammer",
        "Gold Scroll",
        "Totem Of Status",
        "Raygun",
        "Alien Tesla",
        "Totem Of Stars",
        "Totem Of Might",
        "Totem Of Marrow",
        "Rainbow Scroll",
        "Moonlit Scroll",
        "Chilly Scroll",
        "Toasty Scroll",
        "Tranquil Scroll",
        "Shocked Scroll",
        "Glitched Scroll",
    },
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if not Remotes then
    error("[Pcd Fnl Boss] ReplicatedStorage.Remotes was not found")
end

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------

local function notify(title, content, duration)
    pcall(function()
        Fluent:Notify({
            Title = title or App.Name,
            Content = content or "",
            Duration = duration or 4,
        })
    end)
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(App.Connections, connection)
    return connection
end

local function startWorker(name, callback)
    if App.Destroyed or App.Workers[name] then
        return
    end

    local token = { Cancelled = false }
    App.Workers[name] = token

    task.spawn(function()
        while not App.Destroyed and not token.Cancelled and App.Workers[name] == token do
            local ok, delay = pcall(callback)

            if not ok then
                warn("[Pcd Fnl Boss][" .. name .. "] " .. tostring(delay))
                delay = 1
            elseif delay == false then
                break
            end

            task.wait(math.max(tonumber(delay) or 0.1, 0.03))
        end

        if App.Workers[name] == token then
            App.Workers[name] = nil
        end
    end)
end

local function stopWorker(name)
    local token = App.Workers[name]
    if token then
        token.Cancelled = true
        App.Workers[name] = nil
    end
end

local function callRemote(remoteName, ...)
    local remote = Remotes:FindFirstChild(remoteName)
    if not remote then
        return false, "Remote not found: " .. tostring(remoteName)
    end

    local last = App.RemoteLastCall[remoteName] or 0
    local remaining = Config.BuyRemoteDelay - (os.clock() - last)
    if remaining > 0 then
        task.wait(remaining)
    end

    local args = table.pack(...)
    local unpackArgs = table.unpack or unpack

    local ok, result = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpackArgs(args, 1, args.n))
        elseif remote:IsA("RemoteEvent") then
            remote:FireServer(unpackArgs(args, 1, args.n))
            return true
        end

        error("Unsupported remote class: " .. remote.ClassName)
    end)

    App.RemoteLastCall[remoteName] = os.clock()
    return ok, result
end

local function setSelection(key, value)
    local lookup = {}

    if type(value) == "table" then
        for itemName, enabled in pairs(value) do
            if type(itemName) == "string" and enabled == true then
                lookup[string.lower(itemName)] = true
            elseif type(enabled) == "string" then
                lookup[string.lower(enabled)] = true
            end
        end
    elseif type(value) == "string" then
        lookup[string.lower(value)] = true
    end

    App.Selection[key] = lookup
end

local function isSelected(key, itemName)
    if type(itemName) ~= "string" then
        return false
    end

    return App.Selection[key][string.lower(itemName)] == true
end

local function getPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
end

local function getFrames()
    local playerGui = getPlayerGui()
    if not playerGui then return nil end

    local mainGui = playerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end

    local root = mainGui:FindFirstChild("Root")
    if not root then return nil end

    return root:FindFirstChild("Frames")
end

local function getShopList(shopName)
    local frames = getFrames()
    if not frames then return nil end

    local shop = frames:FindFirstChild(shopName) or frames:FindFirstChild(shopName, true)
    if not shop then return nil end

    return shop:FindFirstChild("List", true)
end

local function getText(instance)
    if not instance then return nil end

    if not instance:IsA("TextLabel")
        and not instance:IsA("TextButton")
        and not instance:IsA("TextBox") then
        return nil
    end

    local text = instance.Text
    if type(text) ~= "string" or text == "" then
        return nil
    end

    return text
end

local function getItemName(item)
    local candidates = {
        "Title",
        "ItemName",
        "ItemTitle",
        "NameLabel",
        "DisplayName",
    }

    for _, candidate in ipairs(candidates) do
        local object = item:FindFirstChild(candidate, true)
        local text = getText(object)
        if text then
            return text
        end
    end

    for _, object in ipairs(item:GetDescendants()) do
        local text = getText(object)
        if text then
            local objectName = string.lower(object.Name)
            local lowerText = string.lower(text)

            local ignored =
                objectName == "stock"
                or objectName == "price"
                or objectName == "cost"
                or objectName == "amount"
                or string.find(lowerText, "in stock", 1, true)
                or string.find(lowerText, "no stock", 1, true)
                or string.find(lowerText, "sold out", 1, true)

            if not ignored then
                return text
            end
        end
    end

    return item.Name
end

local function parseStock(stockText)
    if type(stockText) ~= "string" then
        return 0, false
    end

    local normalized = string.upper(stockText):gsub(",", "")

    if string.find(normalized, "NO STOCK", 1, true)
        or string.find(normalized, "OUT OF STOCK", 1, true)
        or string.find(normalized, "SOLD OUT", 1, true)
        or string.find(normalized, "UNAVAILABLE", 1, true) then
        return 0, false
    end

    local amount =
        normalized:match("X%s*(%d+)")
        or normalized:match("(%d+)%s*X")
        or normalized:match("STOCK%s*[:%-]?%s*(%d+)")

    amount = tonumber(amount)
    if amount then
        return amount, amount > 0
    end

    if string.find(normalized, "IN STOCK", 1, true)
        or string.find(normalized, "AVAILABLE", 1, true) then
        return 1, true
    end

    return 0, false
end

local function getCardFromStock(list, stockObject)
    local current = stockObject

    while current and current.Parent and current.Parent ~= list do
        current = current.Parent
    end

    if current and current.Parent == list and current:IsA("GuiObject") then
        return current
    end

    return nil
end

local function getStockEntries(list)
    local entries = {}
    if not list then return entries end

    local seen = {}

    for _, object in ipairs(list:GetDescendants()) do
        if object.Name == "Stock" then
            local stockText = getText(object)
            if stockText then
                local card = getCardFromStock(list, object)

                if card and not seen[card] then
                    seen[card] = true
                    local amount, inStock = parseStock(stockText)

                    table.insert(entries, {
                        Instance = card,
                        Name = getItemName(card),
                        StockText = stockText,
                        Amount = amount,
                        InStock = inStock,
                    })
                end
            end
        end
    end

    return entries
end

local function getShopItemNames(shopName)
    local names = {}
    local seen = {}
    local list = getShopList(shopName)

    if list then
        for _, entry in ipairs(getStockEntries(list)) do
            local name = entry.Name
            if type(name) == "string" and name ~= "" then
                local key = string.lower(name)
                if not seen[key] then
                    seen[key] = true
                    table.insert(names, name)
                end
            end
        end
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return names
end

local function mergeUnique(primary, fallback)
    local result = {}
    local seen = {}

    local function append(list)
        for _, value in ipairs(list or {}) do
            if type(value) == "string" and value ~= "" then
                local key = string.lower(value)
                if not seen[key] then
                    seen[key] = true
                    table.insert(result, value)
                end
            end
        end
    end

    append(primary)
    append(fallback)

    table.sort(result, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return result
end

local function sameArray(a, b)
    if #a ~= #b then return false end
    for index = 1, #a do
        if a[index] ~= b[index] then
            return false
        end
    end
    return true
end

local function runShop(selectionKey, stateKey, shopConfig)
    local list = getShopList(shopConfig.UIName)
    if not list then return end

    for _, entry in ipairs(getStockEntries(list)) do
        if not App.State[stateKey] then
            return
        end

        if entry.InStock and entry.Amount > 0 and isSelected(selectionKey, entry.Name) then
            local signatureKey = selectionKey .. "|" .. string.lower(entry.Name) .. "|" .. tostring(entry.StockText)
            local last = App.LastPurchaseSignature[signatureKey] or 0

            if os.clock() - last >= Config.SameStockCooldown then
                App.LastPurchaseSignature[signatureKey] = os.clock()

                for _ = 1, entry.Amount do
                    if not App.State[stateKey] then
                        return
                    end

                    local ok, result = callRemote(shopConfig.Remote, entry.Name)
                    if not ok or result == false then
                        break
                    end
                end
            end
        end
    end
end

-- --------------------------------------------------------------------------
-- UI
-- --------------------------------------------------------------------------

local Window = Fluent:CreateWindow({
    Title = "Pcd Fnl Boss",
    SubTitle = "Capybaras Vs Plants • v" .. App.Version,
    TabWidth = 155,
    Size = UDim2.fromOffset(580, 440),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

App.Window = Window
App.Fluent = Fluent

local Tabs = {
    Shop = Window:AddTab({ Title = "Auto Buy", Icon = "shopping-cart" }),
    Utility = Window:AddTab({ Title = "Utility", Icon = "wrench" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local CapybaraSection = Tabs.Shop:AddSection("Capybaras")
local GearSection = Tabs.Shop:AddSection("Gears")
local MerchantSection = Tabs.Shop:AddSection("Merchant")

local initialCapybaras = getShopItemNames(Config.Shops.Capybaras.UIName)
local initialGears = getShopItemNames(Config.Shops.Gears.UIName)
local initialMerchant = mergeUnique(
    getShopItemNames(Config.Shops.Merchant.UIName),
    Config.MerchantFallback
)

local CapybaraDropdown = CapybaraSection:AddDropdown("SelectedCapybaras", {
    Title = "Select Capybaras",
    Description = "Select which Capybaras should be bought when they are in stock.",
    Values = initialCapybaras,
    Multi = true,
    Default = {},
    Callback = function(value)
        setSelection("Capybaras", value)
    end,
})

CapybaraSection:AddToggle("AutoBuyCapybaras", {
    Title = "Auto Buy Capybaras",
    Description = "Buys the full visible stock of the selected Capybaras.",
    Default = false,
    Callback = function(value)
        App.State.AutoBuyCapybaras = value

        if value then
            startWorker("AutoBuyCapybaras", function()
                if not App.State.AutoBuyCapybaras then return false end
                runShop("Capybaras", "AutoBuyCapybaras", Config.Shops.Capybaras)
                return Config.BuyLoop
            end)
        else
            stopWorker("AutoBuyCapybaras")
        end
    end,
})

local GearDropdown = GearSection:AddDropdown("SelectedGears", {
    Title = "Select Gears",
    Description = "Select which Gears should be bought when they are in stock.",
    Values = initialGears,
    Multi = true,
    Default = {},
    Callback = function(value)
        setSelection("Gears", value)
    end,
})

GearSection:AddToggle("AutoBuyGears", {
    Title = "Auto Buy Gears",
    Description = "Buys the full visible stock of the selected Gears.",
    Default = false,
    Callback = function(value)
        App.State.AutoBuyGears = value

        if value then
            startWorker("AutoBuyGears", function()
                if not App.State.AutoBuyGears then return false end
                runShop("Gears", "AutoBuyGears", Config.Shops.Gears)
                return Config.BuyLoop
            end)
        else
            stopWorker("AutoBuyGears")
        end
    end,
})

local MerchantDropdown = MerchantSection:AddDropdown("SelectedMerchantItems", {
    Title = "Select Merchant Items",
    Description = "Select Merchant items to buy automatically while they are available.",
    Values = initialMerchant,
    Multi = true,
    Default = {},
    Callback = function(value)
        setSelection("Merchant", value)
    end,
})

MerchantSection:AddToggle("AutoBuyMerchant", {
    Title = "Auto Buy Merchant",
    Description = "Buys the full visible stock of the selected Merchant items.",
    Default = false,
    Callback = function(value)
        App.State.AutoBuyMerchant = value

        if value then
            startWorker("AutoBuyMerchant", function()
                if not App.State.AutoBuyMerchant then return false end
                runShop("Merchant", "AutoBuyMerchant", Config.Shops.Merchant)
                return Config.BuyLoop
            end)
        else
            stopWorker("AutoBuyMerchant")
        end
    end,
})

MerchantSection:AddButton({
    Title = "Refresh Shop Lists",
    Description = "Scans EggShop, GearShop and MerchantShop again.",
    Callback = function()
        local capybaras = getShopItemNames(Config.Shops.Capybaras.UIName)
        local gears = getShopItemNames(Config.Shops.Gears.UIName)
        local merchant = mergeUnique(
            getShopItemNames(Config.Shops.Merchant.UIName),
            Config.MerchantFallback
        )

        CapybaraDropdown:SetValues(capybaras)
        GearDropdown:SetValues(gears)
        MerchantDropdown:SetValues(merchant)

        notify(
            App.Name,
            string.format("Shop scan complete • %d Capybaras • %d Gears • %d Merchant items", #capybaras, #gears, #merchant),
            4
        )
    end,
})

-- Keep dropdown options synced with the game's shop UI.
startWorker("DynamicShopOptions", function()
    local capybaras = getShopItemNames(Config.Shops.Capybaras.UIName)
    local gears = getShopItemNames(Config.Shops.Gears.UIName)
    local merchant = mergeUnique(
        getShopItemNames(Config.Shops.Merchant.UIName),
        Config.MerchantFallback
    )

    if not sameArray(CapybaraDropdown.Values or {}, capybaras) then
        CapybaraDropdown:SetValues(capybaras)
    end

    if not sameArray(GearDropdown.Values or {}, gears) then
        GearDropdown:SetValues(gears)
    end

    if not sameArray(MerchantDropdown.Values or {}, merchant) then
        MerchantDropdown:SetValues(merchant)
    end

    return Config.DynamicOptionsRefresh
end)

-- --------------------------------------------------------------------------
-- Utility
-- --------------------------------------------------------------------------

local UtilitySection = Tabs.Utility:AddSection("Player")
local AntiAFKConnection = nil

local function setAntiAFK(enabled)
    App.State.AntiAFK = enabled

    if AntiAFKConnection then
        AntiAFKConnection:Disconnect()
        AntiAFKConnection = nil
    end

    if not enabled then
        return
    end

    AntiAFKConnection = connect(LocalPlayer.Idled, function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
end

UtilitySection:AddToggle("AntiAFK", {
    Title = "Anti AFK",
    Description = "Prevents the Roblox idle kick while the hub is running.",
    Default = true,
    Callback = setAntiAFK,
})

UtilitySection:AddButton({
    Title = "Minimize Interface",
    Description = "On mobile, use the draggable Pcd Fnl Boss icon to restore it.",
    Callback = function()
        Window:Minimize()
    end,
})

-- --------------------------------------------------------------------------
-- Settings
-- --------------------------------------------------------------------------

local HubSection = Tabs.Settings:AddSection("Hub")

HubSection:AddParagraph({
    Title = "Pcd Fnl Boss",
    Content = "Capybaras Vs Plants • v" .. App.Version .. "\nAuto Buy + Anti AFK base build.",
})

function App:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    for name, token in pairs(self.Workers) do
        if token then token.Cancelled = true end
        self.Workers[name] = nil
    end

    if AntiAFKConnection then
        pcall(function()
            AntiAFKConnection:Disconnect()
        end)
        AntiAFKConnection = nil
    end

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Connections)

    pcall(function()
        Fluent:Destroy()
    end)

    if ENV.PcdFnlBossCVP == self then
        ENV.PcdFnlBossCVP = nil
    end
end

HubSection:AddButton({
    Title = "Unload Hub",
    Description = "Stops all automation and destroys the interface.",
    Callback = function()
        App:Destroy()
    end,
})

if InterfaceManager then
    InterfaceManager:SetLibrary(Fluent)
    InterfaceManager:SetFolder("PcdFnlBoss/CapybarasVsPlants")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
end

if SaveManager then
    SaveManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("PcdFnlBoss/CapybarasVsPlants")
    SaveManager:BuildConfigSection(Tabs.Settings)
end

Window:SelectTab(1)

notify(
    App.Name,
    "Capybaras Vs Plants hub loaded • Auto Buy + Anti AFK ready.",
    5
)

return App
