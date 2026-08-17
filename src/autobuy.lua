local AutoBuy = {}

local function trim(value)
    if type(value) ~= "string" then
        return nil
    end

    local cleaned = value:match("^%s*(.-)%s*$")

    if cleaned == "" then
        return nil
    end

    return cleaned
end

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

function AutoBuy:Init(App)
    self.App = App
    self.Config = App.Config
    self.Core = App.Core
    self.Selection = App.Selection

    self.OptionCache = {}
    self.RecentPurchases = {}
end

function AutoBuy:FeatureKey(shopKey)
    return "Shop:" .. shopKey
end

function AutoBuy:SelectionKey(shopKey)
    return "Shop:" .. shopKey
end

function AutoBuy:GetShopConfig(shopKey)
    return self.Config.Shops[shopKey]
end

function AutoBuy:GetPlayerGui()
    local player = self.Core.Player

    if not player then
        return nil
    end

    return player:FindFirstChildOfClass("PlayerGui")
        or player:FindFirstChild("PlayerGui")
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

function AutoBuy:GetShopList(shopKey)
    local shopConfig = self:GetShopConfig(shopKey)

    if not shopConfig then
        return nil
    end

    local frames = self:GetFrames()

    if not frames then
        return nil
    end

    local shop = frames:FindFirstChild(shopConfig.UIName)
        or frames:FindFirstChild(shopConfig.UIName, true)

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

    return trim(instance.Text)
end

function AutoBuy:GetItemName(card)
    local preferredNames = {
        "Title",
        "ItemName",
        "ItemTitle",
        "NameLabel",
        "DisplayName",
    }

    for _, objectName in ipairs(preferredNames) do
        local object = card:FindFirstChild(objectName, true)
        local text = self:GetText(object)

        if text then
            return text
        end
    end

    for _, object in ipairs(card:GetDescendants()) do
        local text = self:GetText(object)

        if text then
            local objectName = string.lower(object.Name)
            local lower = string.lower(text)

            local ignored =
                objectName == "stock"
                or objectName == "price"
                or objectName == "cost"
                or objectName == "amount"
                or string.find(lower, "in stock", 1, true)
                or string.find(lower, "no stock", 1, true)
                or string.find(lower, "out of stock", 1, true)
                or string.find(lower, "sold out", 1, true)

            if not ignored then
                return text
            end
        end
    end

    return trim(card.Name)
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

    if current
        and current.Parent == list
        and current:IsA("GuiObject") then
        return current
    end

    return nil
end

function AutoBuy:GetStockEntries(shopKey)
    local list = self:GetShopList(shopKey)
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

                    local name = self:GetItemName(card)

                    if name then
                        local amount, inStock = self:ParseStock(stockText)

                        entries[#entries + 1] = {
                            Name = name,
                            StockText = stockText,
                            Amount = amount,
                            InStock = inStock,
                            Instance = card,
                        }
                    end
                end
            end
        end
    end

    return entries
end

function AutoBuy:GetAvailableOptions(shopKey)
    local shopConfig = self:GetShopConfig(shopKey)

    if not shopConfig then
        return {}
    end

    if shopConfig.DynamicOptions ~= true then
        local options = {}

        for _, option in ipairs(shopConfig.Options or {}) do
            options[#options + 1] = option
        end

        return options
    end

    local options = {}
    local seen = {}

    for _, entry in ipairs(self:GetStockEntries(shopKey)) do
        local normalized = string.lower(entry.Name)

        if not seen[normalized] then
            seen[normalized] = true
            options[#options + 1] = entry.Name
        end
    end

    table.sort(options, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    local cached = self.OptionCache[shopKey] or {}

    if #options == 0 and #cached > 0 then
        return cached
    end

    if not sameArray(options, cached) then
        self.OptionCache[shopKey] = options
    end

    return options
end

function AutoBuy:IsSameStockRecentlyPurchased(shopKey, entry)
    local shopCache = self.RecentPurchases[shopKey]

    if not shopCache then
        shopCache = {}
        self.RecentPurchases[shopKey] = shopCache
    end

    local key = string.lower(entry.Name)
    local record = shopCache[key]

    if not record then
        return false
    end

    local cooldown = tonumber(self.Config.Timing.SameStockCooldown) or 2.5

    return record.StockText == entry.StockText
        and (os.clock() - record.Time) < cooldown
end

function AutoBuy:MarkPurchased(shopKey, entry)
    local shopCache = self.RecentPurchases[shopKey]

    if not shopCache then
        shopCache = {}
        self.RecentPurchases[shopKey] = shopCache
    end

    shopCache[string.lower(entry.Name)] = {
        StockText = entry.StockText,
        Time = os.clock(),
    }
end

function AutoBuy:PurchaseEntry(shopKey, entry)
    local shopConfig = self:GetShopConfig(shopKey)

    if not shopConfig or not entry.InStock then
        return
    end

    if self:IsSameStockRecentlyPurchased(shopKey, entry) then
        return
    end

    local featureKey = self:FeatureKey(shopKey)
    local amount = math.max(0, tonumber(entry.Amount) or 0)

    if amount <= 0 then
        return
    end

    for _ = 1, amount do
        if not self.Core:IsEnabled(featureKey) then
            return
        end

        local ok, result = self.Core:CallRemote(
            shopConfig.Remote,
            self.Config.Timing.BuyRemote,
            entry.Name
        )

        if not ok or result == false then
            break
        end
    end

    self:MarkPurchased(shopKey, entry)
end

function AutoBuy:RunCycle(shopKey)
    local selectionKey = self:SelectionKey(shopKey)

    if #self.Selection:Get(selectionKey) == 0 then
        return
    end

    for _, entry in ipairs(self:GetStockEntries(shopKey)) do
        if not self.Core:IsEnabled(self:FeatureKey(shopKey)) then
            return
        end

        if self.Selection:Contains(selectionKey, entry.Name) then
            self:PurchaseEntry(shopKey, entry)
        end
    end
end

function AutoBuy:Start(shopKey)
    local shopConfig = self:GetShopConfig(shopKey)

    if not shopConfig then
        return false
    end

    local featureKey = self:FeatureKey(shopKey)
    local workerName = "AutoBuy:" .. shopKey

    self.Core:SetEnabled(featureKey, true)

    return self.Core:StartWorker(workerName, function()
        if not self.Core:IsEnabled(featureKey) then
            return false
        end

        self:RunCycle(shopKey)

        return self.Config.Timing.BuyLoop
    end)
end

function AutoBuy:Stop(shopKey)
    self.Core:SetEnabled(self:FeatureKey(shopKey), false)
    self.Core:StopWorker("AutoBuy:" .. shopKey)
end

return AutoBuy
