local Bosses = {}

function Bosses:Init(App)
    self.App = App
    self.Config = App.Config
    self.Core = App.Core
    self.Selection = App.Selection

    self.Cursors = {}
end

function Bosses:FeatureKey(groupKey)
    return "Boss:" .. groupKey
end

function Bosses:SelectionKey(groupKey)
    return "Boss:" .. groupKey
end

function Bosses:GetGroup(groupKey)
    return self.Config.BossGroups[groupKey]
end

function Bosses:Summon(name)
    if type(name) ~= "string" or name == "" then
        return false, "Invalid boss name"
    end

    return self.Core:CallRemote(
        "SummonBoss",
        self.Config.Timing.BossRemote,
        "Summon",
        name
    )
end

function Bosses:GetNextSelected(groupKey)
    local selected = self.Selection:Get(self:SelectionKey(groupKey))

    if #selected == 0 then
        self.Cursors[groupKey] = 1
        return nil
    end

    local cursor = self.Cursors[groupKey] or 1

    if cursor > #selected then
        cursor = 1
    end

    local boss = selected[cursor]

    cursor = cursor + 1

    if cursor > #selected then
        cursor = 1
    end

    self.Cursors[groupKey] = cursor

    return boss
end

function Bosses:Start(groupKey)
    if not self:GetGroup(groupKey) then
        return false
    end

    local featureKey = self:FeatureKey(groupKey)
    local workerName = "AutoBoss:" .. groupKey

    self.Core:SetEnabled(featureKey, true)

    return self.Core:StartWorker(workerName, function()
        if not self.Core:IsEnabled(featureKey) then
            return false
        end

        local boss = self:GetNextSelected(groupKey)

        if boss then
            self:Summon(boss)
        end

        return self.Config.Timing.BossLoop
    end)
end

function Bosses:Stop(groupKey)
    self.Core:SetEnabled(self:FeatureKey(groupKey), false)
    self.Core:StopWorker("AutoBoss:" .. groupKey)
end

function Bosses:SummonSelectedOnce(groupKey)
    local selected = self.Selection:Get(self:SelectionKey(groupKey))

    task.spawn(function()
        for _, boss in ipairs(selected) do
            self:Summon(boss)
        end
    end)
end

return Bosses
