------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

-- 슬라이더 숫자 포맷 정의
local Formatters = {
    ["Percent"] = function(v) return ("%d%%"):format(math.floor((v or 0) * 100 + 0.5)) end,
    ["Integer"] = function(v) return tostring(math.floor((v or 0) + 0.5)) end,
    ["Decimal"] = function(v) return ("%.1f"):format(v or 0) end
}

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