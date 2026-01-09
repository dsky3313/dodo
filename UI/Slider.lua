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
-- 슬라이더
------------------------------
function Slider(category, varName, label, tooltip, min, max, step, default, formatType)
    local varID = "hodo_" .. varName

    local setting = Settings.GetSetting(varID)
        if not setting then
            setting = Settings.RegisterAddOnSetting(category, varID, varName, hodoDB, Settings.VarType.Number, label, default or 0)
        end

    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    local selectedFormatter = Formatters[formatType] or Formatters["Percent"]
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, selectedFormatter)

    local initializer = Settings.CreateControlInitializer("SettingsSliderControlTemplate", setting, sliderOptions, tooltip)
        setting:SetValueChangedCallback(function()
            if FrameScale then FrameScale() end
        end)

    setting:SetValueChangedCallback(function()
        if ChatBubble then ChatBubble() end
        if FrameScale then FrameScale() end
    end)

    local layout = SettingsPanel:GetLayout(category)
        if layout then
            layout:AddInitializer(initializer)
        end
end