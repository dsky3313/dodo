local addonName, dodo = ...
_G[addonName] = dodo

dodo.Core = dodo.Core or {}
dodo.Config = dodo.Config or {}
dodo.Modules = dodo.Modules or {}
dodo.ModuleRegistry = dodo.ModuleRegistry or {}
dodo.UI = dodo.UI or {}

local engine = CreateFrame("Frame")
engine:RegisterEvent("ADDON_LOADED")
engine:RegisterEvent("PLAYER_LOGIN")

engine:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodoDB
        if dodo.OnInitialize then dodo:OnInitialize() end
    elseif event == "PLAYER_LOGIN" then
        if dodo.OnEnable then dodo:OnEnable() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
