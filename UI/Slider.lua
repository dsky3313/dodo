------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

local Formatters = {
    ["Percent"] = function(v) return ("%d%%"):format(math.floor((v or 0) * 100 + 0.5)) end, -- 백분율
    ["Integer"] = function(v) return tostring(math.floor((v or 0) + 0.5)) end, -- 정수
    ["Decimal1"] = function(v) return ("%.1f"):format(v or 0) end, -- 소수 1자리
    ["Decimal2"] = function(v) return ("%.2f"):format(v or 0) end, -- 소수 2자리
}

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