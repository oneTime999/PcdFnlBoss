local UI = {}

local STARLIGHT_URLS = {
    "https://raw.nebulasoftworks.xyz/starlight",
    "https://raw.githubusercontent.com/Nebula-Softworks/Starlight-Interface-Suite/master/Source.lua",
}

function UI:Init(App)
    self.App = App
    self.Core = App.Core
    self.AutoBuy = App.AutoBuy
    self.Bosses = App.Bosses
    self.Config = App.Config

    self:CreateWindow()
end

function UI:LoadStarlight()
    local errors = {}

    for _, url in ipairs(STARLIGHT_URLS) do
        local ok, source = pcall(function()
            return game:HttpGet(url .. "?cb=" .. tostring(os.time()))
        end)

        if ok and type(source) == "string" and source ~= "" then
            local chunk, compileError = loadstring(source)

            if chunk then
                local runOk, library = pcall(chunk)

                if runOk and type(library) == "table" then
                    return library
                end

                errors[#errors + 1] = "runtime: " .. tostring(library)
            else
                errors[#errors + 1] = "compile: " .. tostring(compileError)
            end
        else
            errors[#errors + 1] = "http: " .. tostring(source)
        end
    end

    error("[Pcd Fnl Boss] Starlight failed to load: " .. table.concat(errors, " | "))
end

function UI:CreateWindow()
    local env = (getgenv and getgenv()) or _G
    env.InterfaceName = "PcdFnlBoss"

    local Starlight = self:LoadStarlight()

    self.Starlight = Starlight
    self.App.Starlight = Starlight

    local Window = Starlight:CreateWindow({
        Name = self.Config.Title,
        Subtitle = "v" .. self.Config.Version .. " • by " .. self.Config.Author,

        LoadingEnabled = false,
        BuildWarnings = true,
        InterfaceAdvertisingPrompts = false,
        NotifyOnCallbackError = true,

        FileSettings = {
            ConfigFolder = "PcdFnlBoss",
        },

        KeySystem = {
            Enabled = false,
        },
    })

    self.Window = Window

    local Navigation = Window:CreateTabSection("Pcd Fnl Boss", true)

    local MainTab = Navigation:CreateTab({
        Name = "Main",
        Columns = 2,
    }, "Main")

    local EventTab = Navigation:CreateTab({
        Name = "Event",
        Columns = 1,
    }, "Event")

    local AutoBuyGroup = MainTab:CreateGroupbox({
        Name = "Auto Buy",
        Column = 1,
        Style = 1,
    }, "AutoBuy")

    AutoBuyGroup:CreateToggle({
        Name = "Auto Buy Capybaras",
        CurrentValue = false,
        Style = 2,
        Tooltip = "Buys every available item shown in the Capybara/Egg shop.",

        Callback = function(value)
            self.Core.State.AutoBuyCapybaras = value

            if value then
                self.AutoBuy:StartCapybaras()
            else
                self.AutoBuy:StopCapybaras()
            end
        end,
    }, "AutoBuyCapybaras")

    AutoBuyGroup:CreateToggle({
        Name = "Auto Buy Gears",
        CurrentValue = false,
        Style = 2,
        Tooltip = "Buys every available Gear shop item.",

        Callback = function(value)
            self.Core.State.AutoBuyGears = value

            if value then
                self.AutoBuy:StartGears()
            else
                self.AutoBuy:StopGears()
            end
        end,
    }, "AutoBuyGears")

    AutoBuyGroup:CreateToggle({
        Name = "Auto Buy Merchant",
        CurrentValue = false,
        Style = 2,
        Tooltip = "Automatically buys available Merchant stock.",

        Callback = function(value)
            self.Core.State.AutoBuyMerchant = value

            if value then
                self.AutoBuy:StartMerchant()
            else
                self.AutoBuy:StopMerchant()
            end
        end,
    }, "AutoBuyMerchant")

    AutoBuyGroup:CreateToggle({
        Name = "Buy Every Merchant Item",
        CurrentValue = true,
        Style = 2,
        Tooltip = "ON: buys every visible Merchant item. OFF: only buys the configured known list.",

        Callback = function(value)
            self.Core.State.MerchantBuyAll = value
        end,
    }, "MerchantBuyAll")

    local BossGroup = MainTab:CreateGroupbox({
        Name = "Bosses",
        Column = 2,
        Style = 1,
    }, "Bosses")

    BossGroup:CreateDropdown({
        Name = "Select Boss",
        Options = self.Config.NormalBosses,
        CurrentOption = self.Core.State.SelectedBoss,
        MultipleOptions = false,

        Callback = function(value)
            if type(value) == "table" then
                value = value[1]
            end

            if type(value) == "string" and value ~= "" then
                self.Core.State.SelectedBoss = value
            end
        end,
    })

    BossGroup:CreateToggle({
        Name = "Auto Summon Boss",
        CurrentValue = false,
        Style = 2,
        Tooltip = "Repeatedly summons the selected normal boss.",

        Callback = function(value)
            self.Core.State.AutoBoss = value

            if value then
                self.Bosses:StartNormal()
            else
                self.Bosses:StopNormal()
            end
        end,
    }, "AutoSummonBoss")

    BossGroup:CreateButton({
        Name = "Summon Selected Boss",
        Style = 2,

        Callback = function()
            local boss = self.Core.State.SelectedBoss

            if boss then
                self.Bosses:Summon(boss)
            end
        end,
    }, "SummonSelectedBoss")

    local EventGroup = EventTab:CreateGroupbox({
        Name = "Dr Carrot Challenge",
        Column = 1,
        Style = 1,
    }, "DrCarrotChallenge")

    EventGroup:CreateToggle({
        Name = "Auto Challenge Dr. Carrot",
        CurrentValue = false,
        Style = 2,
        Tooltip = "Cycles Dr Carrot, MkI, MkII and MkIII continuously.",

        Callback = function(value)
            self.Core.State.AutoEvent = value

            if value then
                self.Bosses:StartEvent()
            else
                self.Bosses:StopEvent()
            end
        end,
    }, "AutoChallengeDrCarrot")

    Starlight:OnDestroy(function()
        pcall(function()
            self.Core:Destroy()
        end)

        local currentEnv = (getgenv and getgenv()) or _G

        if currentEnv.PcdFnlBossApp == self.App then
            currentEnv.PcdFnlBossApp = nil
        end
    end)

    print("[Pcd Fnl Boss] Starlight interface created successfully")
end

return UI
