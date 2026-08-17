local UI = {}

function UI:Init(App)
    self.App = App
    self.Core = App.Core
    self.AutoBuy = App.AutoBuy
    self.Bosses = App.Bosses
    self.Config = App.Config

    self:CreateWindow()
end

function UI:CreateWindow()
    getgenv().InterfaceName = "PcdFnlBoss"

    local success, Starlight = pcall(function()
        return loadstring(
            game:HttpGet(
                "https://raw.nebulasoftworks.xyz/starlight"
            )
        )()
    end)

    if not success or not Starlight then
        error(
            "[Pcd Fnl Boss] Failed to load Starlight: " ..
            tostring(Starlight)
        )
    end

    self.Starlight = Starlight
    self.App.Starlight = Starlight

    local Window = Starlight:CreateWindow({
        Name = self.Config.Title,
        Subtitle = "by " .. self.Config.Author,

        LoadingEnabled = false,

        BuildWarnings = true,
        InterfaceAdvertisingPrompts = false,
        NotifyOnCallbackError = true,

        FileSettings = {
            ConfigFolder = "PcdFnlBoss",
        },
    })

    self.Window = Window

    local Navigation = Window:CreateTabSection(
        "Pcd Fnl Boss",
        true
    )

    local MainTab = Navigation:CreateTab({
        Name = "Main",
        Columns = 2,
    }, "Main")

    local EventTab = Navigation:CreateTab({
        Name = "Event",
        Columns = 1,
    }, "Event")

    --------------------------------------------------
    -- MAIN / AUTO BUY
    --------------------------------------------------

    local AutoBuyGroup = MainTab:CreateGroupbox({
        Name = "Auto Buy",
        Column = 1,
    }, "AutoBuy")

    AutoBuyGroup:CreateToggle({
        Name = "Auto Buy Capybaras",
        CurrentValue = false,
        Style = 2,

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

        Callback = function(value)
            self.Core.State.AutoBuyMerchant = value

            if value then
                self.AutoBuy:StartMerchant()
            else
                self.AutoBuy:StopMerchant()
            end
        end,
    }, "AutoBuyMerchant")

    --------------------------------------------------
    -- MAIN / BOSSES
    --------------------------------------------------

    local BossGroup = MainTab:CreateGroupbox({
        Name = "Bosses",
        Column = 2,
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

        Callback = function(value)
            self.Core.State.AutoBoss = value

            if value then
                self.Bosses:StartNormal()
            else
                self.Core:StopWorker("NormalBoss")
            end
        end,
    }, "AutoSummonBoss")

    BossGroup:CreateButton({
        Name = "Summon Selected Boss",

        Callback = function()
            local boss = self.Core.State.SelectedBoss

            if boss then
                self.Bosses:Summon(boss)
            end
        end,
    }, "SummonSelectedBoss")

    --------------------------------------------------
    -- EVENT
    --------------------------------------------------

    local EventGroup = EventTab:CreateGroupbox({
        Name = "Dr Carrot Challenge",
        Column = 1,
    }, "DrCarrotChallenge")

    EventGroup:CreateToggle({
        Name = "Auto Challenge Dr. Carrot",
        CurrentValue = false,
        Style = 2,

        Callback = function(value)
            self.Core.State.AutoEvent = value

            if value then
                self.Bosses:StartEvent()
            else
                self.Core:StopWorker("EventBoss")
            end
        end,
    }, "AutoChallengeDrCarrot")

    --------------------------------------------------
    -- CLEANUP
    --------------------------------------------------

    Starlight:OnDestroy(function()
        self.Core:StopAll()

        local env = getgenv and getgenv() or _G

        if env.PcdFnlBossApp == self.App then
            env.PcdFnlBossApp = nil
        end
    end)

    print("[Pcd Fnl Boss] Interface created.")
end

return UI
