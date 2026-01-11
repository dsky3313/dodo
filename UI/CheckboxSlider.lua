------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

-- 슬라이더 숫자 포맷 정의
local Formatters = {
    ["Percent"] = function(v) return ("%d%%"):format(math.floor((v or 0) * 100 + 0.5)) end,
    ["Integer"] = function(v) return tostring(math.floor((v or 0) + 0.5)) end,
    ["Decimal"] = function(v) return ("%.1f"):format(v or 0) end
}

------------------------------
-- 체크박스 슬라이더
------------------------------

function CheckboxSlider(category, varNameCB, varNameSlider, label, tooltip, min, max, step, defaultCB, defaultSlider, formatType)
    local varID_CB = "hodo_" .. varNameCB
    local varID_Slider = "hodo_" .. varNameSlider

    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, hodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local sliderSetting = Settings.GetSetting(varID_Slider) or Settings.RegisterAddOnSetting(category, varID_Slider, varNameSlider, hodoDB, Settings.VarType.Number, label, tonumber(defaultSlider) or min)

    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    -- 여기에 필요 시 Formatters 적용 가능

    -- 블리자드 표준 데이터 구조
    local data = {
        name = label,
        tooltip = tooltip,
        cbSetting = cbSetting,
        sliderSetting = sliderSetting,
        sliderOptions = sliderOptions,
    }

    -- hodoUI.xml에서 만든 템플릿 사용
    local initializer = Settings.CreateSettingInitializer("hodoCheckboxSliderTemplate", data)

    local function OnValueChanged()
        if ns.CameraTilt then ns.CameraTilt() end
    end
    cbSetting:SetValueChangedCallback(OnValueChanged)
    sliderSetting:SetValueChangedCallback(OnValueChanged)

    local layout = SettingsPanel:GetLayout(category)
    if layout then
        layout:AddInitializer(initializer)
    end
end