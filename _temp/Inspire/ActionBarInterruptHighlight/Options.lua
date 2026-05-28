--[[----------------------------------------------------------------------------

    ActionBarInterruptHighlight
    Copyright 2026 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local addonName, addon = ...

local defaults = {
    global = {
    },
    profile = {
        enableActionBars = true,
        enableCooldownManager = true,
    },
    char = {
    },
}

local options = {
    type = "group",
    args = {
        enableActionBars = {
            type = "toggle",
            name = "Highlight buttons on action bars.",
            width = "full",
            order = 10,
            get =
                function ()
                    return addon.db.profile.enableActionBars
                end,
            set =
                function (_, v)
                    addon.db.profile.enableActionBars = v
                    addon.db.callbacks:Fire('OnOptionsChanged')
                end,
        },
        enableCooldownManager = {
            type = "toggle",
            name = "Highlight buttons on cooldown manager bars.",
            width = "full",
            order = 20,
            get =
                function ()
                    return addon.db.profile.enableCooldownManager
                end,
            set =
                function (_, v)
                    addon.db.profile.enableCooldownManager = v
                    addon.db.callbacks:Fire('OnOptionsChanged')
                end,
        },
    },
}

function addon.InitializeOptions()
    addon.db = LibStub("AceDB-3.0"):New("ActionBarInterruptHighlight", defaults, true)

    -- A convenience so other things just listen for OnOptionsChanged
    local function refire() addon.db.callbacks:Fire('OnOptionsChanged') end
    addon.db.RegisterCallback(addon, 'OnProfileChanged', refire)
    addon.db.RegisterCallback(addon, 'OnProfileReset', refire)
    addon.db.RegisterCallback(addon, 'OnProfileCopied', refire)

    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    local title = C_AddOns.GetAddOnTitle(addonName)
    AceConfig:RegisterOptionsTable(title, options)
    AceConfigDialog:AddToBlizOptions(title)
end
