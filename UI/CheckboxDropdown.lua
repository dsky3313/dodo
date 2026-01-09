------------------------------
-- 체크박스 드롭다운
------------------------------
function CreateSettingsCheckboxDropdownInitializer(cbSetting, cbLabel, cbTooltip, dropdownSetting, dropdownOptions, dropdownLabel, dropdownTooltip, newTagID)
    local data = {
        name = cbLabel,
        tooltip = cbTooltip,
        cbSetting = cbSetting,
        cbLabel = cbLabel,
        cbTooltip = cbTooltip,
        dropdownSetting = dropdownSetting,
        dropdownOptions = dropdownOptions,
        dropdownLabel = dropdownLabel,
        dropdownTooltip = dropdownTooltip,
        newTagID = newTagID,
    }
    local initializer = Settings.CreateSettingInitializer("SettingsCheckboxDropdownControlTemplate", data)
    initializer:AddSearchTags(cbLabel, dropdownLabel)
    return initializer
end

function CheckBoxDropDown(category, varNameCB, varNameDD, label, tooltip, options, defaultCB, defaultDD)
    local varID_CB = "hodo_" .. varNameCB
    local varID_DD = "hodo_" .. varNameDD

    local cbSetting = Settings.GetSetting(varID_CB)
    if not cbSetting then
        cbSetting = Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, hodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    end

    local ddSetting = Settings.GetSetting(varID_DD)
    if not ddSetting then
        ddSetting = Settings.RegisterAddOnSetting(category, varID_DD, varNameDD, hodoDB, Settings.VarType.String, label, defaultDD or options[1].CheckboxDropdownTextValue)
    end

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options) do
            container:Add(option.value, option.label)
        end
        return container:GetData()
    end

    local initializer = CreateSettingsCheckboxDropdownInitializer(
        cbSetting, label, tooltip,
        ddSetting, GetOptions, label, tooltip
    )

    local function OnValueChanged()
        if NewLFG then NewLFG() end
        if setDifficulty then setDifficulty(true) end
    end

    cbSetting:SetValueChangedCallback(OnValueChanged)
    ddSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return cbSetting, ddSetting, initializer
end