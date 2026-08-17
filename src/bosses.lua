local Bosses = {}

function Bosses:Init(App)
    self.App = App
    self.Core = App.Core
    self.Config = App.Config
    self.EventIndex = 1
end

function Bosses:Summon(name)
    if type(name) ~= "string" or name == "" then
        return false, "Invalid boss name"
    end

    return self.Core:CallRemote(
        "SummonBoss",
        self.Config.BossRemoteDelay,
        "Summon",
        name
    )
end

function Bosses:StartNormal()
    self.Core:StartWorker("NormalBoss", function()
        if not self.Core.State.AutoBoss then
            return false
        end

        local boss = self.Core.State.SelectedBoss

        if boss then
            self:Summon(boss)
        end

        return self.Config.BossInterval
    end)
end

function Bosses:StopNormal()
    self.Core:StopWorker("NormalBoss")
end

function Bosses:StartEvent()
    self.EventIndex = 1

    self.Core:StartWorker("EventBoss", function()
        if not self.Core.State.AutoEvent then
            return false
        end

        local bosses = self.Config.EventBosses

        if #bosses == 0 then
            return false
        end

        if self.EventIndex > #bosses then
            self.EventIndex = 1
        end

        local boss = bosses[self.EventIndex]
        self:Summon(boss)

        self.EventIndex = self.EventIndex + 1

        if self.EventIndex > #bosses then
            self.EventIndex = 1
        end

        return self.Config.BossInterval
    end)
end

function Bosses:StopEvent()
    self.Core:StopWorker("EventBoss")
end

return Bosses
