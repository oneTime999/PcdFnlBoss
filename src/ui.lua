local UI = {}

function UI:Init(App)
    self.App = App
    self.Core = App.Core
    self.AutoBuy = App.AutoBuy
    self.Bosses = App.Bosses
    self.Config = App.Config

    self:CreateWindow()
end

function UI:CreateWindow()

    -- carregar Starlight

    -- Window
    -- título: Pcd Fnl Boss
    -- autor: onetime.999

    ------------------------------------------------

    -- TAB MAIN

    -- Auto Buy Capybaras
    -- Auto Buy Gears
    -- Auto Buy Merchant

    -- Boss Dropdown

    -- Auto Summon Boss

    -- Summon Selected Boss

    ------------------------------------------------

    -- TAB EVENT

    -- Auto Challenge Dr. Carrot

    ------------------------------------------------

end

return UI
