local Core = {}

local unpackArgs = table.unpack or unpack

function Core:Init(App)
    self.App = App

    self.Services = {
        Players = game:GetService("Players"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
    }

    self.Player = self.Services.Players.LocalPlayer

    if not self.Player then
        error("[Pcd Fnl Boss] LocalPlayer not found")
    end

    self.Remotes = self.Services.ReplicatedStorage:WaitForChild("Remotes", 15)

    if not self.Remotes then
        error("[Pcd Fnl Boss] ReplicatedStorage.Remotes not found")
    end

    self.Enabled = {}
    self.Workers = {}

    self.RemoteBusy = {}
    self.RemoteLastCall = {}

    self.LastWarnings = {}
    self.Destroyed = false
end

function Core:SetEnabled(key, value)
    self.Enabled[key] = value == true
end

function Core:IsEnabled(key)
    return self.Enabled[key] == true
end

function Core:Warn(key, message, cooldown)
    cooldown = tonumber(cooldown) or 5

    local now = os.clock()
    local last = self.LastWarnings[key] or 0

    if now - last < cooldown then
        return
    end

    self.LastWarnings[key] = now
    warn("[Pcd Fnl Boss][" .. tostring(key) .. "] " .. tostring(message))
end

function Core:IsWorkerRunning(name)
    local token = self.Workers[name]
    return token ~= nil and token.Cancelled ~= true
end

function Core:StartWorker(name, callback)
    if self.Destroyed or self:IsWorkerRunning(name) then
        return false
    end

    local token = {
        Cancelled = false,
    }

    self.Workers[name] = token

    task.spawn(function()
        while not self.Destroyed
            and not token.Cancelled
            and self.Workers[name] == token do

            local ok, result = pcall(callback, token)

            if not ok then
                self:Warn("Worker:" .. name, result, 2)

                local delay = tonumber(self.App.Config.Timing.WorkerErrorDelay) or 1
                task.wait(math.max(delay, 0.1))
            else
                if result == false then
                    break
                end

                local delay = tonumber(result) or 0.1
                task.wait(math.max(delay, 0.03))
            end
        end

        token.Cancelled = true

        if self.Workers[name] == token then
            self.Workers[name] = nil
        end
    end)

    return true
end

function Core:StopWorker(name)
    local token = self.Workers[name]

    if token then
        token.Cancelled = true

        if self.Workers[name] == token then
            self.Workers[name] = nil
        end
    end
end

function Core:StopAll()
    for name, token in pairs(self.Workers) do
        if token then
            token.Cancelled = true
        end

        self.Workers[name] = nil
    end

    for key in pairs(self.Enabled) do
        self.Enabled[key] = false
    end
end

function Core:GetRemote(name)
    if not self.Remotes then
        return nil
    end

    return self.Remotes:FindFirstChild(name)
end

function Core:CallRemote(remoteName, minInterval, ...)
    if self.Destroyed then
        return false, "Core destroyed"
    end

    local remote = self:GetRemote(remoteName)

    if not remote then
        self:Warn("Remote:" .. remoteName, "Remote not found", 5)
        return false, "Remote not found"
    end

    local args = table.pack(...)

    while self.RemoteBusy[remoteName] and not self.Destroyed do
        task.wait(0.03)
    end

    if self.Destroyed then
        return false, "Core destroyed"
    end

    self.RemoteBusy[remoteName] = true

    local interval = tonumber(minInterval) or 0
    local last = self.RemoteLastCall[remoteName] or 0
    local remaining = interval - (os.clock() - last)

    if remaining > 0 then
        task.wait(remaining)
    end

    local ok, result = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpackArgs(args, 1, args.n))
        end

        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpackArgs(args, 1, args.n))
            return true
        end

        error("Unsupported remote class: " .. remote.ClassName)
    end)

    self.RemoteLastCall[remoteName] = os.clock()
    self.RemoteBusy[remoteName] = nil

    if not ok then
        self:Warn("Remote:" .. remoteName, result, 2)
        return false, result
    end

    return true, result
end

function Core:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true
    self:StopAll()

    for key in pairs(self.RemoteBusy) do
        self.RemoteBusy[key] = nil
    end
end

return Core
