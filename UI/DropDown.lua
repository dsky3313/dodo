------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

------------------------------
-- 드롭다운
------------------------------
function DropDown(category, varName, label, tooltip, options, default, func)
    local varID = "dodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.String, label, default or options[1].value)
    end

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options) do
            container:Add(option.value, option.label)
        end
        return container:GetData()
    end

    local initializer = Settings.CreateControlInitializer("dodoDropdownTemplate", setting, GetOptions, tooltip)
    setting:SetValueChangedCallback(function()
        if type(func) == "function" then
            func()
        end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return setting, initializer
end