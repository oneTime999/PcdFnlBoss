local AutoBuy = {}

function AutoBuy:Init(App)
    self.App = App
    self.Core = App.Core
    self.Config = App.Config
end

function AutoBuy:BuyItem(itemName)
    local remote = self.Core.Remotes:FindFirstChild("BuyItem")

    if not remote then
        return
    end

    pcall(function()
        remote:InvokeServer(itemName)
    end)
end

function AutoBuy:BuyMerchantItem(itemName)
    local remote = self.Core.Remotes:FindFirstChild("BuyMerchantItem")

    if not remote then
        return
    end

    pcall(function()
        remote:InvokeServer(itemName)
    end)
end

function AutoBuy:StartCapybaras()
    -- detectar itens do EggShop
    -- comprar todos que estiverem disponíveis
end

function AutoBuy:StartGears()
    -- detectar itens do GearShop
    -- comprar todos que estiverem disponíveis
end

function AutoBuy:StartMerchant()
    -- detectar Merchant
    -- comparar com MerchantItems
    -- comprar disponíveis
end

return AutoBuy
