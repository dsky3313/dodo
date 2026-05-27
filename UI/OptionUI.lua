-- ==============================
-- 테이블
-- ==============================
local addonName, dodo = ...

local ipairs = ipairs
local math_floor = math.floor
local string_format = string.format
local tonumber = tonumber
local tostring = tostring
local type = type
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local Settings = Settings
local SettingsPanel = SettingsPanel

local Formatters = {
    ["Percent"] = function(v) return string_format("%d%%", math_floor((v or 0) * 100 + 0.5)) end,
    ["Integer"] = function(v) return tostring(math_floor((v or 0) + 0.5)) end,
    ["Decimal1"] = function(v) return string_format("%.1f", v or 0) end,
    ["Decimal2"] = function(v) return string_format("%.2f", v or 0) end,
}

-- ==============================
-- 체크박스
-- ==============================
function Checkbox(category, varName, label, tooltip, default, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Boolean, label, default)
    local initializer = Settings.CreateControlInitializer("dodoCheckboxTemplate", setting, nil, tooltip)

    setting:SetValueChangedCallback(function(_, value)
        if type(func) == "function" then func(value) end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end

    return setting, initializer
end

-- ==============================
-- 드롭다운
-- ==============================
function DropDown(category, varName, label, tooltip, options, default, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.String, label, default or options[1].value)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options) do container:Add(option.value, option.label) end
        return container:GetData()
    end

    local initializer = Settings.CreateControlInitializer("dodoDropdownTemplate", setting, GetOptions, tooltip)
    setting:SetValueChangedCallback(function(_, value)
        if type(func) == "function" then func(value) end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end

    return setting, initializer
end

-- ==============================
-- 슬라이더
-- ==============================
function Slider(category, varName, label, tooltip, min, max, step, default, formatType, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Number, label, default or min or 0)
    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Formatters[formatType] or Formatters["Decimal1"])
    local initializer = Settings.CreateControlInitializer("dodoSliderTemplate", setting, sliderOptions, tooltip)

    setting:SetValueChangedCallback(function(_, value)
        if type(func) == "function" then func(value) end
    end)

    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end

    return setting, initializer
end

-- ==============================
-- 체크박스 드롭다운
-- ==============================
function CheckBoxDropDown(category, varNameCB, varNameDD, label, tooltip, options, defaultCB, defaultDD, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_DD = "dodo_" .. varNameDD
    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local fallbackValue = (options and options[1]) and options[1].value or ""
    local ddSetting = Settings.GetSetting(varID_DD) or Settings.RegisterAddOnSetting(category, varID_DD, varNameDD, dodoDB, Settings.VarType.String, label, defaultDD or fallbackValue)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        if options then
            for _, option in ipairs(options) do container:Add(option.value, option.label) end
        end
        return container:GetData()
    end

    local data = { name = label, tooltip = tooltip, cbSetting = cbSetting, dropdownSetting = ddSetting, dropdownOptions = GetOptions, cbLabel = label, cbTooltip = tooltip, dropDownLabel = label, dropDownTooltip = tooltip, }
    local initializer = Settings.CreateSettingInitializer("dodoCheckboxDropdownTemplate", data)

    local function OnValueChanged()
        if type(func) == "function" then func(cbSetting:GetValue()) end
    end

    cbSetting:SetValueChangedCallback(OnValueChanged)
    ddSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end

    return cbSetting, ddSetting, initializer
end

-- ==============================
-- 체크박스 슬라이더
-- ==============================
function CheckboxSlider(category, varNameCB, varNameSlider, label, tooltip, min, max, step, defaultCB, defaultSlider, formatType, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_Slider = "dodo_" .. varNameSlider
    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local sliderSetting = Settings.GetSetting(varID_Slider) or Settings.RegisterAddOnSetting(category, varID_Slider, varNameSlider, dodoDB, Settings.VarType.Number, label, tonumber(defaultSlider) or min)
    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Formatters[formatType] or Formatters["Percent"])
    local data = { name = label, tooltip = tooltip, cbSetting = cbSetting, sliderSetting = sliderSetting, sliderOptions = sliderOptions, }
    local initializer = Settings.CreateSettingInitializer("dodoCheckboxSliderTemplate", data)

    local function OnValueChanged()
        if type(func) == "function" then func(cbSetting:GetValue()) end
    end

    cbSetting:SetValueChangedCallback(OnValueChanged)
    sliderSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end

    return cbSetting, sliderSetting, initializer
end
