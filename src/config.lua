local Config = {}

Config.Version = "2.0.1"

Config.UI = {
    Title = "Pcd Fnl Boss",
    Author = "onetime.999",
    Theme = "Default",
    ToggleKey = "K",
    RayfieldURL = "https://sirius.menu/rayfield",
}

Config.Timing = {
    WorkerErrorDelay = 1.0,

    BuyLoop = 1.5,
    BuyRemote = 0.15,
    SameStockCooldown = 2.5,

    BossLoop = 2.5,
    BossRemote = 1.25,

    DynamicOptionsRefresh = 3.0,
}

Config.Shops = {
    Capybaras = {
        Label = "Capybaras",
        DropdownLabel = "Select Capybaras",
        ToggleLabel = "Auto Buy Capybaras",

        UIName = "EggShop",
        Remote = "BuyItem",

        DynamicOptions = true,
    },

    Gears = {
        Label = "Gears",
        DropdownLabel = "Select Gears",
        ToggleLabel = "Auto Buy Gears",

        UIName = "GearShop",
        Remote = "BuyItem",

        DynamicOptions = true,
    },

    Merchant = {
        Label = "Merchant",
        DropdownLabel = "Select Merchant Items",
        ToggleLabel = "Auto Buy Merchant",

        UIName = "MerchantShop",
        Remote = "BuyMerchantItem",

        DynamicOptions = false,

        Options = {
            "Gilded Hatch Hammer",
            "Gold Scroll",
            "Totem Of Status",
            "Raygun",
            "Alien Tesla",
            "Totem Of Stars",
            "Totem Of Might",
            "Totem Of Marrow",
            "Rainbow Scroll",
            "Moonlit Scroll",
            "Chilly Scroll",
            "Toasty Scroll",
            "Tranquil Scroll",
            "Shocked Scroll",
            "Glitched Scroll",
        },
    },
}

Config.ShopOrder = {
    "Capybaras",
    "Gears",
    "Merchant",
}

Config.BossGroups = {
    Normal = {
        Section = "Bosses",
        DropdownLabel = "Select Bosses",
        ToggleLabel = "Auto Summon Bosses",
        ButtonLabel = "Summon Selected Bosses",

        Options = {
            "Scarlet Carrot",
            "Red Potato",
            "Dark Tomato",
            "Skull Flower",
            "Holy Grailic",
            "Carnivorous Jester",
            "Pumpkin Tyrant",
            "Golem King",
            "Conqueror Carrot",
        },
    },

    Event = {
        Section = "Dr Carrot Challenge",
        DropdownLabel = "Select Event Bosses",
        ToggleLabel = "Auto Summon Event Bosses",
        ButtonLabel = "Summon Selected Event Bosses",

        Options = {
            "Dr Carrot",
            "Dr Carrot MkI",
            "Dr Carrot MkII",
            "Dr Carrot MkIII",
        },
    },
}

return Config
