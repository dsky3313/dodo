------------------------------
-- 드롭다운
------------------------------
function DropDown(category, varName, label, tooltip, options, default)
    local varID = "hodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, hodoDB, Settings.VarType.String, label, default or options[1].value)
    end

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options) do
            container:Add(option.value, option.label)
        end
        return container:GetData()
    end

    local initializer = Settings.CreateControlInitializer("SettingsDropDownControlTemplate", setting, GetOptions, tooltip)
        setting:SetValueChangedCallback(function()
            if ChatBubble then ChatBubble() end
            if CameraTilt then CameraTilt() end
        end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return setting, initializer
end