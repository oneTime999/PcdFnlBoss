local Bosses = {}

function Bosses:Init(App)
    self.App = App
    self.Core = App.Core
    self.Config = App.Config
end

function Bosses:Summon(name)
    local remote = self.Core.Remotes:FindFirstChild("SummonBoss")

    if not remote then
        return
    end

    pcall(function()
        remote:InvokeServer(
            "Summon",
            name
        )
    end)
end

function Bosses:StartNormal()
    self.Core:StartWorker("NormalBoss", function()
        if not self.Core.State.AutoBoss then
            self.Core:StopWorker("NormalBoss")
            return
        end

        self:Summon(self.Core.State.SelectedBoss)

        task.wait(self.Config.BossInterval)
    end)
end

function Bosses:StartEvent()
    self.Core:StartWorker("EventBoss", function()
        for _, boss in ipairs(self.Config.EventBosses) do
            if not self.Core.State.AutoEvent then
                break
            end

            self:Summon(boss)

            task.wait(self.Config.BossInterval)
        end
    end)
end

return Bosses
