local AutoBuy = {}

function AutoBuy:Init(App)
    self.App = App
    self.Core = App.Core
    self.Config = App.Config

    self.MerchantLookup = {}

    for _, itemName in ipairs(self.Config.MerchantItems) do
        self.MerchantLookup[string.lower(itemName)] = true
    end
end

function AutoBuy:GetPlayerGui()
    local player = self.Core.Player

    if not player then
        return nil
    end

    return player:FindFirstChild("PlayerGui")
end

function AutoBuy:GetFrames()
    local playerGui = self:GetPlayerGui()

    if not playerGui then
        return nil
    end

    local mainGui = playerGui:FindFirstChild("MainGui")

    if not mainGui then
        return nil
    end

    local root = mainGui:FindFirstChild("Root")

    if not root then
        return nil
    end

    return root:FindFirstChild("Frames")
end

function AutoBuy:GetShopList(shopName)
    local frames = self:GetFrames()

    if not frames then
        return nil
    end

    local shop = frames:FindFirstChild(shopName)

    if not shop then
        return nil
    end

    return shop:FindFirstChild("List", true)
end

function AutoBuy:GetMerchantNPC()
    local world = workspace:FindFirstChild("World")

    if not world then
        return nil
    end

    local map = world:FindFirstChild("Map")

    if not map then
        return nil
    end

    local npcs = map:FindFirstChild("NPCs")

    if not npcs then
        return nil
    end

    return npcs:FindFirstChild("MerchantNPC")
end

function AutoBuy:GetText(instance)
    if not instance then
        return nil
    end

    local success, text = pcall(function()
        return instance.Text
    end)

    if success and type(text) == "string" then
        return text
    end

    return nil
end

function AutoBuy:GetItemName(item)
    local title = item:FindFirstChild("Title", true)

    if title then
        local text = self:GetText(title)

        if text and text ~= "" then
            return text
        end
    end

    return item.Name
end

function AutoBuy:ParseStock(stockText)
    if type(stockText) ~= "string" then
        return 0, false
    end

    local normalized = string.upper(stockText)

    if string.find(normalized, "NO STOCK", 1, true) then
        return 0, false
    end

    local amount = string.match(stockText, "[xX]%s*(%d+)")

    if amount then
        amount = tonumber(amount)

        if amount and amount > 0 then
            return amount, true
        end
    end

    if string.find(normalized, "IN STOCK", 1, true) then
        return 1, true
    end

    return 0, false
end

function AutoBuy:GetStockEntries(list)
    local entries = {}

    if not list then
        return entries
    end

    for _, item in ipairs(list:GetChildren()) do
        if item:IsA("GuiObject") then
            local stockObject = item:FindFirstChild("Stock", true)

            if stockObject then
                local stockText = self:GetText(stockObject)

                if stockText then
                    local amount, inStock = self:ParseStock(stockText)

                    table.insert(entries, {
                        instance = item,
                        name = self:GetItemName(item),
                        stock = stockText,
                        amount = amount,
                        inStock = inStock,
                    })
                end
            end
        end
    end

    return entries
end

function AutoBuy:CallRemote(remoteName, itemName)
    local remote = self.Core.Remotes:FindFirstChild(remoteName)

    if not remote then
        return false
    end

    local success = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(itemName)
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(itemName)
        end
    end)

    return success
end

function AutoBuy:BuyItem(itemName)
    return self:CallRemote("BuyItem", itemName)
end

function AutoBuy:BuyMerchantItem(itemName)
    return self:CallRemote("BuyMerchantItem", itemName)
end

function AutoBuy:PurchaseEntry(entry, buyFunction, stateKey)
    if not entry.inStock then
        return
    end

    local amount = tonumber(entry.amount) or 0

    if amount <= 0 then
        return
    end

    for _ = 1, amount do
        if not self.Core.State[stateKey] then
            return
        end

        local success = buyFunction(entry.name)

        if not success then
            break
        end

        task.wait(0.15)
    end
end

function AutoBuy:StartCapybaras()
    self.Core:StartWorker("AutoBuyCapybaras", function()
        if not self.Core.State.AutoBuyCapybaras then
            self.Core:StopWorker("AutoBuyCapybaras")
            return
        end

        local list = self:GetShopList("EggShop")

        if list then
            local entries = self:GetStockEntries(list)

            for _, entry in ipairs(entries) do
                if not self.Core.State.AutoBuyCapybaras then
                    return
                end

                local name = string.lower(entry.name)

                if string.find(name, "egg", 1, true) then
                    self:PurchaseEntry(
                        entry,
                        function(itemName)
                            return self:BuyItem(itemName)
                        end,
                        "AutoBuyCapybaras"
                    )
                end
            end
        end

        task.wait(self.Config.BuyInterval)
    end)
end

function AutoBuy:StopCapybaras()
    self.Core:StopWorker("AutoBuyCapybaras")
end

function AutoBuy:StartGears()
    self.Core:StartWorker("AutoBuyGears", function()
        if not self.Core.State.AutoBuyGears then
            self.Core:StopWorker("AutoBuyGears")
            return
        end

        local list = self:GetShopList("GearShop")

        if list then
            local entries = self:GetStockEntries(list)

            for _, entry in ipairs(entries) do
                if not self.Core.State.AutoBuyGears then
                    return
                end

                self:PurchaseEntry(
                    entry,
                    function(itemName)
                        return self:BuyItem(itemName)
                    end,
                    "AutoBuyGears"
                )
            end
        end

        task.wait(self.Config.BuyInterval)
    end)
end

function AutoBuy:StopGears()
    self.Core:StopWorker("AutoBuyGears")
end

function AutoBuy:StartMerchant()
    self.Core:StartWorker("AutoBuyMerchant", function()
        if not self.Core.State.AutoBuyMerchant then
            self.Core:StopWorker("AutoBuyMerchant")
            return
        end

        if not self:GetMerchantNPC() then
            task.wait(self.Config.BuyInterval)
            return
        end

        local list = self:GetShopList("MerchantShop")

        if list then
            local entries = self:GetStockEntries(list)

            for _, entry in ipairs(entries) do
                if not self.Core.State.AutoBuyMerchant then
                    return
                end

                local normalizedName = string.lower(entry.name)

                if self.MerchantLookup[normalizedName] then
                    self:PurchaseEntry(
                        entry,
                        function(itemName)
                            return self:BuyMerchantItem(itemName)
                        end,
                        "AutoBuyMerchant"
                    )
                end
            end
        end

        task.wait(self.Config.BuyInterval)
    end)
end

function AutoBuy:StopMerchant()
    self.Core:StopWorker("AutoBuyMerchant")
end

return AutoBuy
