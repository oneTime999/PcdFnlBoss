local UI = {}

local RAYFIELD_URL = "https://sirius.menu/rayfield"

function UI:Init(App)
    self.App = App
    self.Core = App.Core
    self.AutoBuy = App.AutoBuy
    self.Bosses = App.Bosses
    self.Config = App.Config

    self:CreateWindow()
end

function UI:LoadRayfield()
    local ok, source = pcall(function()
        return game:HttpGet(RAYFIELD_URL)
    end)

    if not ok then
        error("[Pcd Fnl Boss] Failed to download Rayfield: " .. tostring(source))
    end

    if type(source) ~= "string" or source == "" then
        error("[Pcd Fnl Boss] Rayfield returned an empty source")
    end

    local chunk, compileError = loadstring(source)

    if not chunk then
        error("[Pcd Fnl Boss] Rayfield compile error: " .. tostring(compileError))
    end

    local runOk, Rayfield = pcall(chunk)

    if not runOk then
        error("[Pcd Fnl Boss] Rayfield runtime error: " .. tostring(Rayfield))
    end

    if type(Rayfield) ~= "table" then
        error("[Pcd Fnl Boss] Rayfield did not return a valid library table")
    end

    return Rayfield
end

function UI:CreateWindow()
    local Rayfield = self:LoadRayfield()

    self.Rayfield = Rayfield
    self.App.Rayfield = Rayfield

    local Window = Rayfield:CreateWindow({
        Name = self.Config.Title,
        Icon = 0,

        LoadingTitle = self.Config.Title,
        LoadingSubtitle = "v" .. self.Config.Version .. " • by " .. self.Config.Author,

        ShowText = "Pcd Fnl Boss",
        Theme = "Default",

        ToggleUIKeybind = "K",

        DisableRayfieldPrompts = true,
        DisableBuildWarnings = false,

        ConfigurationSaving = {
            Enabled = false,
            FolderName = "PcdFnlBoss",
            FileName = "PcdFnlBoss",
        },

        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = true,
        },

        KeySystem = false,
    })

    if not Window then
        error("[Pcd Fnl Boss] Rayfield failed to create the window")
    end

    self.Window = Window

    --------------------------------------------------
    -- MAIN
    --------------------------------------------------

    local MainTab = Window:CreateTab("Main", 0)

    MainTab:CreateSection("Auto Buy")

    MainTab:CreateToggle({
        Name = "Auto Buy Capybaras",
        CurrentValue = false,
        Flag = "AutoBuyCapybaras",

        Callback = function(value)
            self.Core.State.AutoBuyCapybaras = value

            if value then
                self.AutoBuy:StartCapybaras()
            else
                self.AutoBuy:StopCapybaras()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Buy Gears",
        CurrentValue = false,
        Flag = "AutoBuyGears",

        Callback = function(value)
            self.Core.State.AutoBuyGears = value

            if value then
                self.AutoBuy:StartGears()
            else
                self.AutoBuy:StopGears()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Buy Merchant",
        CurrentValue = false,
        Flag = "AutoBuyMerchant",

        Callback = function(value)
            self.Core.State.AutoBuyMerchant = value

            if value then
                self.AutoBuy:StartMerchant()
            else
                self.AutoBuy:StopMerchant()
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Buy Every Merchant Item",
        CurrentValue = true,
        Flag = "MerchantBuyAll",

        Callback = function(value)
            self.Core.State.MerchantBuyAll = value
        end,
    })

    MainTab:CreateSection("Bosses")

    MainTab:CreateDropdown({
        Name = "Select Boss",
        Options = self.Config.NormalBosses,
        CurrentOption = {self.Core.State.SelectedBoss},
        MultipleOptions = false,
        Flag = "SelectedBoss",

        Callback = function(options)
            local selected

            if type(options) == "table" then
                selected = options[1]
            elseif type(options) == "string" then
                selected = options
            end

            if type(selected) == "string" and selected ~= "" then
                self.Core.State.SelectedBoss = selected
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Summon Boss",
        CurrentValue = false,
        Flag = "AutoSummonBoss",

        Callback = function(value)
            self.Core.State.AutoBoss = value

            if value then
                self.Bosses:StartNormal()
            else
                self.Bosses:StopNormal()
            end
        end,
    })

    MainTab:CreateButton({
        Name = "Summon Selected Boss",

        Callback = function()
            local boss = self.Core.State.SelectedBoss

            if boss then
                self.Bosses:Summon(boss)
            end
        end,
    })

    --------------------------------------------------
    -- EVENT
    --------------------------------------------------

    local EventTab = Window:CreateTab("Event", 0)

    EventTab:CreateSection("Dr Carrot Challenge")

    EventTab:CreateToggle({
        Name = "Auto Challenge Dr. Carrot",
        CurrentValue = false,
        Flag = "AutoChallengeDrCarrot",

        Callback = function(value)
            self.Core.State.AutoEvent = value

            if value then
                self.Bosses:StartEvent()
            else
                self.Bosses:StopEvent()
            end
        end,
    })

    EventTab:CreateSection("Challenge Rotation")

    EventTab:CreateLabel(
        "Dr Carrot → Dr Carrot MkI → Dr Carrot MkII → Dr Carrot MkIII"
    )

    --------------------------------------------------
    -- CONTROL
    --------------------------------------------------

    MainTab:CreateSection("Control")

    MainTab:CreateButton({
        Name = "Disable All Automation",

        Callback = function()
            self.Core.State.AutoBuyCapybaras = false
            self.Core.State.AutoBuyGears = false
            self.Core.State.AutoBuyMerchant = false
            self.Core.State.AutoBoss = false
            self.Core.State.AutoEvent = false

            self.Core:StopAll()

            Rayfield:Notify({
                Title = "Pcd Fnl Boss",
                Content = "All automation workers were stopped.",
                Duration = 4,
            })
        end,
    })

    Rayfield:Notify({
        Title = self.Config.Title,
        Content = "Loaded v" .. self.Config.Version .. " • by " .. self.Config.Author,
        Duration = 4,
    })

    print("[Pcd Fnl Boss] Rayfield interface created successfully")
end

return UI
