local Core = {}

function Core:Init(App)
    self.App = App

    self.Services = {
        Players = game:GetService("Players"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
    }

    self.Player = self.Services.Players.LocalPlayer

    self.Remotes = self.Services.ReplicatedStorage:WaitForChild("Remotes")

    self.State = {
        AutoBuyCapybaras = false,
        AutoBuyGears = false,
        AutoBuyMerchant = false,

        AutoBoss = false,
        AutoEvent = false,

        SelectedBoss = App.Config.NormalBosses[1],
    }

    self.Workers = {}
end

function Core:StartWorker(name, callback)
    if self.Workers[name] then
        return
    end

    self.Workers[name] = true

    task.spawn(function()
        while self.Workers[name] do
            local success, err = pcall(callback)

            if not success then
                warn("[Pcd Fnl Boss][" .. name .. "]", err)
            end

            task.wait()
        end
    end)
end

function Core:StopWorker(name)
    self.Workers[name] = nil
end

function Core:StopAll()
    table.clear(self.Workers)

    for key in pairs(self.State) do
        if typeof(self.State[key]) == "boolean" then
            self.State[key] = false
        end
    end
end

return Core
