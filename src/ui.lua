local UI = {}

local PLACEHOLDER = "Waiting for shop items..."

local function sameArray(a, b)
    if #a ~= #b then
        return false
    end

    for index = 1, #a do
        if a[index] ~= b[index] then
            return false
        end
    end

    return true
end

function UI:Init(App)
    self.App = App
    self.Config = App.Config
    self.Core = App.Core
    self.Selection = App.Selection
    self.AutoBuy = App.AutoBuy
    self.Bosses = App.Bosses

    self.DynamicDropdowns = {}

    self:CreateWindow()
end

function UI:LoadRayfield()
    local ok, source = pcall(function()
        return game:HttpGet(self.Config.UI.RayfieldURL)
    end)

    if not ok then
        error("[Pcd Fnl Boss] Rayfield HTTP error: " .. tostring(source))
    end

    if type(source) ~= "string" or source == "" then
        error("[Pcd Fnl Boss] Rayfield returned empty source")
    end

    local chunk, compileError = loadstring(source)

    if not chunk then
        error("[Pcd Fnl Boss] Rayfield compile error: " .. tostring(compileError))
    end

    local runOk, Rayfield = pcall(chunk)

    if not runOk or type(Rayfield) ~= "table" then
        error("[Pcd Fnl Boss] Rayfield runtime error: " .. tostring(Rayfield))
    end

    return Rayfield
end

function UI:CleanDropdownValues(values)
    local cleaned = {}

    for _, value in ipairs(self.Selection:Normalize(values)) do
        if value ~= PLACEHOLDER then
            cleaned[#cleaned + 1] = value
        end
    end

    return cleaned
end

function UI:CreateShopControls(tab, shopKey)
    local shop = self.Config.Shops[shopKey]

    if not shop then
        return
    end

    tab:CreateSection(shop.Label)

    local selectionKey = self.AutoBuy:SelectionKey(shopKey)
    local initialOptions = self.AutoBuy:GetAvailableOptions(shopKey)

    local displayOptions = initialOptions

    if #displayOptions == 0 then
        displayOptions = {PLACEHOLDER}
    end

    local dropdown = tab:CreateDropdown({
        Name = shop.DropdownLabel,
        Options = displayOptions,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "ShopSelection_" .. shopKey,

        Callback = function(options)
            self.Selection:Set(
                selectionKey,
                self:CleanDropdownValues(options)
            )
        end,
    })

    tab:CreateToggle({
        Name = shop.ToggleLabel,
        CurrentValue = false,
        Flag = "ShopToggle_" .. shopKey,

        Callback = function(value)
            if value then
                self.AutoBuy:Start(shopKey)
            else
                self.AutoBuy:Stop(shopKey)
            end
        end,
    })

    if shop.DynamicOptions == true then
        self.DynamicDropdowns[shopKey] = {
            Dropdown = dropdown,
            LastOptions = initialOptions,
        }
    end
end

function UI:CreateBossControls(tab, groupKey)
    local group = self.Config.BossGroups[groupKey]

    if not group then
        return
    end

    tab:CreateSection(group.Section)

    local selectionKey = self.Bosses:SelectionKey(groupKey)

    tab:CreateDropdown({
        Name = group.DropdownLabel,
        Options = group.Options,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "BossSelection_" .. groupKey,

        Callback = function(options)
            self.Selection:Set(selectionKey, options)
        end,
    })

    tab:CreateToggle({
        Name = group.ToggleLabel,
        CurrentValue = false,
        Flag = "BossToggle_" .. groupKey,

        Callback = function(value)
            if value then
                self.Bosses:Start(groupKey)
            else
                self.Bosses:Stop(groupKey)
            end
        end,
    })

    tab:CreateButton({
        Name = group.ButtonLabel,

        Callback = function()
            self.Bosses:SummonSelectedOnce(groupKey)
        end,
    })
end

function UI:StartDynamicDropdownSync()
    self.Core:StartWorker("UI:DynamicShopOptions", function()
        for shopKey, state in pairs(self.DynamicDropdowns) do
            local options = self.AutoBuy:GetAvailableOptions(shopKey)

            if #options > 0 and not sameArray(options, state.LastOptions) then
                local selected = self.Selection:FilterToOptions(
                    self.AutoBuy:SelectionKey(shopKey),
                    options
                )

                state.Dropdown:Refresh(options)
                state.Dropdown:Set(selected)

                state.LastOptions = options
            end
        end

        return self.Config.Timing.DynamicOptionsRefresh
    end)
end

function UI:CreateWindow()
    local Rayfield = self:LoadRayfield()

    self.Rayfield = Rayfield
    self.App.Rayfield = Rayfield

    local Window = Rayfield:CreateWindow({
        Name = self.Config.UI.Title,
        Icon = 0,

        LoadingTitle = self.Config.UI.Title,
        LoadingSubtitle =
            "v" .. self.Config.Version .. " • by " .. self.Config.UI.Author,

        ShowText = self.Config.UI.Title,
        Theme = self.Config.UI.Theme,

        ToggleUIKeybind = self.Config.UI.ToggleKey,

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
        error("[Pcd Fnl Boss] Rayfield failed to create window")
    end

    self.Window = Window

    local MainTab = Window:CreateTab("Main", 0)

    for _, shopKey in ipairs(self.Config.ShopOrder) do
        self:CreateShopControls(MainTab, shopKey)
    end

    self:CreateBossControls(MainTab, "Normal")

    local EventTab = Window:CreateTab("Event", 0)
    self:CreateBossControls(EventTab, "Event")

    self:StartDynamicDropdownSync()

    Rayfield:Notify({
        Title = self.Config.UI.Title,
        Content =
            "Loaded v" .. self.Config.Version .. " • by " .. self.Config.UI.Author,
        Duration = 4,
    })

    print("[Pcd Fnl Boss] Rayfield interface ready")
end

return UI
