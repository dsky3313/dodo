------------------------------
-- 테이블
------------------------------
local Formatters = {
    ["Percent"] = function(v) 
        return ("%d%%"):format(math.floor((v or 0) * 100 + 0.5)) 
    end,

    ["Integer"] = function(v) 
        return tostring(math.floor((v or 0) + 0.5)) 
    end,

    ["Decimal"] = function(v)
        return ("%.1f"):format(v or 0)
    end
}

------------------------------
-- 체크박스 슬라이더
------------------------------
function CreateSettingsCheckboxSliderInitializer(cbSetting, cbLabel, cbTooltip, sliderSetting, sliderOptions, sliderLabel, sliderTooltip, newTagID)
    local data = {
        name = cbLabel,
        tooltip = cbTooltip,
        cbSetting = cbSetting,
        cbLabel = cbLabel,
        cbTooltip = cbTooltip,
        sliderSetting = sliderSetting,
        sliderOptions = sliderOptions,
        sliderLabel = sliderLabel,
        sliderTooltip = sliderTooltip,
        newTagID = newTagID,
    }
    local initializer = Settings.CreateSettingInitializer("SettingsCheckboxSliderControlTemplate", data)
    initializer:AddSearchTags(cbLabel, sliderLabel)
    return initializer
end

function CheckboxSlider(category, varNameCB, varNameSlider, label, tooltip, min, max, step, defaultCB, defaultSlider, formatType)
    local varID_CB = "hodo_" .. varNameCB
    local varID_Slider = "hodo_" .. varNameSlider

    local cbSetting = Settings.GetSetting(varID_CB)
    if not cbSetting then
        cbSetting = Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, hodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    end

    local sliderSetting = Settings.GetSetting(varID_Slider)
    if not sliderSetting then
    local safeDefault = tonumber(defaultSlider) or min
    sliderSetting = Settings.RegisterAddOnSetting(category, varID_Slider, varNameSlider, hodoDB, Settings.VarType.Number, label, safeDefault)
    end

    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    local selectedFormatter = Formatters[formatType] or Formatters["Integer"]
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, selectedFormatter)

    local initializer = CreateSettingsCheckboxSliderInitializer(
        cbSetting, label, tooltip,
        sliderSetting, sliderOptions, label, tooltip
    )

    local function OnValueChanged()
        if CameraTilt then CameraTilt() end
        if setDifficulty then setDifficulty(true) end
    end

    cbSetting:SetValueChangedCallback(OnValueChanged)
    sliderSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end

    return cbSetting, sliderSetting, initializer
end