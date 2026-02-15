------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

local Formatters = {
    ["Percent"] = function(v) return ("%d%%"):format(math.floor((v or 0) * 100 + 0.5)) end,
    ["Integer"] = function(v) return tostring(math.floor((v or 0) + 0.5)) end,
    ["Decimal"] = function(v) return ("%.1f"):format(v or 0) end
}
------------------------------
-- 체크박스
------------------------------
function Checkbox(category, varName, label, tooltip, default, func)
    local varID = "dodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Boolean, label, default)
    end

    local initializer = Settings.CreateControlInitializer("dodoCheckboxTemplate", setting, nil, tooltip)

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

------------------------------
-- 체크박스 드롭다운
------------------------------
function CheckBoxDropDown(category, varNameCB, varNameDD, label, tooltip, options, defaultCB, defaultDD, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_DD = "dodo_" .. varNameDD

    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)

    local fallbackValue = (options and options[1]) and options[1].value or ""
    local ddSetting = Settings.GetSetting(varID_DD) or Settings.RegisterAddOnSetting(category, varID_DD, varNameDD, dodoDB, Settings.VarType.String, label, defaultDD or fallbackValue)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        if options then
            for _, option in ipairs(options) do
                container:Add(option.value, option.label)
            end
        end
        return container:GetData()
    end

    -- 4. 템플릿 데이터 구성
    local data = {name = label,
        tooltip = tooltip,
        cbSetting = cbSetting,           -- 체크박스 설정 객체
        dropdownSetting = ddSetting,     -- ★ 핵심: 'setting'이 아니라 'dropdownSetting'이어야 함
        dropdownOptions = GetOptions,    -- ★ 핵심: 'options'가 아니라 'dropdownOptions'여야 함
        cbLabel = label,
        cbTooltip = tooltip,
        dropDownLabel = label,
        dropDownTooltip = tooltip,
    }

    local initializer = Settings.CreateSettingInitializer("dodoCheckboxDropdownTemplate", data)

    local function OnValueChanged()
        if type(func) == "function" then
            func(true)
        end
    end
    cbSetting:SetValueChangedCallback(OnValueChanged)
    ddSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end
    return cbSetting, ddSetting, initializer
end

------------------------------
-- 체크박스 슬라이더
------------------------------
function CheckboxSlider(category, varNameCB, varNameSlider, label, tooltip, min, max, step, defaultCB, defaultSlider, formatType, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_Slider = "dodo_" .. varNameSlider
    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local sliderSetting = Settings.GetSetting(varID_Slider) or Settings.RegisterAddOnSetting(category, varID_Slider, varNameSlider, dodoDB, Settings.VarType.Number, label, tonumber(defaultSlider) or min)
    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    local selectedFormatter = Formatters[formatType] or Formatters["Percent"]
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, selectedFormatter)

    local data = {
        name = label,
        tooltip = tooltip,
        cbSetting = cbSetting,
        sliderSetting = sliderSetting,
        sliderOptions = sliderOptions, -- 이제 포매터가 포함된 옵션이 전달됩니다.
    }

    local initializer = Settings.CreateSettingInitializer("dodoCheckboxSliderTemplate", data)

    local function OnValueChanged()
        if type(func) == "function" then
            func(true) -- 체크박스/슬라이더 변경 시 실행
        end
    end
    
    cbSetting:SetValueChangedCallback(OnValueChanged)
    sliderSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end
    
    -- 부모-자식 연결을 위해 리턴값 추가 (필요 시)
    return cbSetting, sliderSetting, initializer
end

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

------------------------------
-- 슬라이더
------------------------------
function Slider(category, varName, label, tooltip, min, max, step, default, formatType, func)
    local varID = "dodo_" .. varName

    local setting = Settings.GetSetting(varID)
    if not setting then
        setting = Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Number, label, default or 0)
    end

    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    local selectedFormatter = Formatters[formatType] or Formatters["Percent"]
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, selectedFormatter)
    local initializer = Settings.CreateControlInitializer("dodoSliderTemplate", setting, sliderOptions, tooltip)
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