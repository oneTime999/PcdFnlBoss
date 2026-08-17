local AutoBuy = {}

function AutoBuy:Init(App)
    self.App = App
    self.Core = App.Core
    self.Config = App.Config
end

function AutoBuy:GetPlayerGui()
    local player = self.Core.Player

    if not player then
        return nil
    end

    return player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
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

    local shop = frames:FindFirstChild(shopName) or frames:FindFirstChild(shopName, true)

    if not shop then
        return nil
    end

    return shop:FindFirstChild("List", true)
end

function AutoBuy:GetText(instance)
    if not instance then
        return nil
    end

    if not instance:IsA("TextLabel")
        and not instance:IsA("TextButton")
        and not instance:IsA("TextBox") then
        return nil
    end

    local text = instance.Text

    if type(text) ~= "string" or text == "" then
        return nil
    end

    return text
end

function AutoBuy:GetItemName(item)
    local candidates = {
        "Title",
        "ItemName",
        "ItemTitle",
        "NameLabel",
        "DisplayName",
    }

    for _, candidate in ipairs(candidates) do
        local object = item:FindFirstChild(candidate, true)
        local text = self:GetText(object)

        if text then
            return text
        end
    end

    for _, object in ipairs(item:GetDescendants()) do
        local text = self:GetText(object)

        if text then
            local objectName = string.lower(object.Name)
            local lowerText = string.lower(text)

            local ignored =
                objectName == "stock"
                or objectName == "price"
                or objectName == "cost"
                or objectName == "amount"
                or string.find(lowerText, "in stock", 1, true)
                or string.find(lowerText, "no stock", 1, true)
                or string.find(lowerText, "sold out", 1, true)

            if not ignored then
                return text
            end
        end
    end

    return item.Name
end

function AutoBuy:ParseStock(stockText)
    if type(stockText) ~= "string" then
        return 0, false
    end

    local normalized = string.upper(stockText):gsub(",", "")

    if string.find(normalized, "NO STOCK", 1, true)
        or string.find(normalized, "OUT OF STOCK", 1, true)
        or string.find(normalized, "SOLD OUT", 1, true)
        or string.find(normalized, "UNAVAILABLE", 1, true) then
        return 0, false
    end

    local amount =
        normalized:match("X%s*(%d+)")
        or normalized:match("(%d+)%s*X")
        or normalized:match("STOCK%s*[:%-]?%s*(%d+)")

    amount = tonumber(amount)

    if amount then
        return amount, amount > 0
    end

    if string.find(normalized, "IN STOCK", 1, true)
        or string.find(normalized, "AVAILABLE", 1, true) then
        return 1, true
    end

    return 0, false
end

function AutoBuy:GetCardFromStock(list, stockObject)
    local current = stockObject

    while current and current.Parent and current.Parent ~= list do
        current = current.Parent
    end

    if current and current.Parent == list and current:IsA("GuiObject") then
        return current
    end

    return nil
end

function AutoBuy:GetStockEntries(list)
    local entries = {}

    if not list then
        return entries
    end

    local seen = {}

    for _, object in ipairs(list:GetDescendants()) do
        if object.Name == "Stock" then
            local stockText = self:GetText(object)

            if stockText then
                local card = self:GetCardFromStock(list, object)

                if card and not seen[card] then
                    seen[card] = true

                    local amount, inStock = self:ParseStock(stockText)

                    entries[#entries + 1] = {
                        Instance = card,
                        Name = self:GetItemName(card),
                        StockText = stockText,
                        Amount = amount,
                        InStock = inStock,
                    }
                end
            end
        end
    end

    return entries
end

function AutoBuy:BuyItem(itemName)
    return self.Core:CallRemote(
        "BuyItem",
        self.Config.BuyRemoteDelay,
        itemName
    )
end

function AutoBuy:BuyMerchantItem(itemName)
    return self.Core:CallRemote(
        "BuyMerchantItem",
        self.Config.BuyRemoteDelay,
        itemName
    )
end

function AutoBuy:PurchaseEntry(entry, stateKey, buyer)
    if not entry or not entry.InStock then
        return
    end

    local amount = tonumber(entry.Amount) or 0

    if amount <= 0 then
        return
    end

    for _ = 1, amount do
        if not self.Core.State[stateKey] then
            return
        end

        local ok, result = buyer(entry.Name)

        if not ok or result == false then
            return
        end
    end
end

function AutoBuy:RunShop(shopName, stateKey, buyer, predicate)
    local list = self:GetShopList(shopName)

    if not list then
        self.Core:WarnThrottled(
            "Shop:" .. shopName,
            "Shop list not found: " .. shopName,
            10
        )
        return
    end

    local entries = self:GetStockEntries(list)

    for _, entry in ipairs(entries) do
        if not self.Core.State[stateKey] then
            return
        end

        local shouldBuy = true

        if predicate then
            shouldBuy = predicate(entry)
        end

        if shouldBuy then
            self:PurchaseEntry(entry, stateKey, buyer)
        end
    end
end

function AutoBuy:StartCapybaras()
    self.Core:StartWorker("AutoBuyCapybaras", function()
        if not self.Core.State.AutoBuyCapybaras then
            return false
        end

        self:RunShop(
            self.Config.ShopNames.Capybaras,
            "AutoBuyCapybaras",
            function(itemName)
                return self:BuyItem(itemName)
            end
        )

        return self.Config.BuyInterval
    end)
end

function AutoBuy:StopCapybaras()
    self.Core:StopWorker("AutoBuyCapybaras")
end

function AutoBuy:StartGears()
    self.Core:StartWorker("AutoBuyGears", function()
        if not self.Core.State.AutoBuyGears then
            return false
        end

        self:RunShop(
            self.Config.ShopNames.Gears,
            "AutoBuyGears",
            function(itemName)
                return self:BuyItem(itemName)
            end
        )

        return self.Config.BuyInterval
    end)
end

function AutoBuy:StopGears()
    self.Core:StopWorker("AutoBuyGears")
end

function AutoBuy:StartMerchant()
    self.Core:StartWorker("AutoBuyMerchant", function()
        if not self.Core.State.AutoBuyMerchant then
            return false
        end

        self:RunShop(
            self.Config.ShopNames.Merchant,
            "AutoBuyMerchant",
            function(itemName)
                return self:BuyMerchantItem(itemName)
            end,
            function(entry)
                return self.Core:IsMerchantSelected(entry.Name)
            end
        )

        return self.Config.BuyInterval
    end)
end

function AutoBuy:StopMerchant()
    self.Core:StopWorker("AutoBuyMerchant")
end

return AutoBuy
