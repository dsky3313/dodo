-- ========================================================================
-- dodo UI Widgets Factory
-- Description: Provides reusable Blizzard-style UI widgets (Checkbox, Slider, Dropdown, Button).
-- ========================================================================

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodo.UI = dodo.UI or {}

-- ==============================
-- 캐싱
-- ==============================
-- abc 가나다 순으로 정렬 완료
local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local ipairs = ipairs
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local string_format = string.format

-- ==============================
-- 컴포넌트 활성/비활성 헬퍼 API
-- ==============================
function dodo.UI:SetComponentEnabled(comp, enabled)
    if enabled then
        comp:SetAlpha(1.0)
        comp:Enable()
        if comp.Text then comp.Text:SetTextColor(1, 0.82, 0) end
    else
        comp:SetAlpha(0.35)
        comp:Disable()
        if comp.Text then comp.Text:SetTextColor(0.5, 0.5, 0.5) end
    end
end

function dodo.UI:SetSliderEnabled(sliderFrame, enabled)
    if enabled then
        sliderFrame:SetAlpha(1.0)
        if sliderFrame.Slider and sliderFrame.Slider.Slider then
            sliderFrame.Slider.Slider:Enable()
        end
    else
        sliderFrame:SetAlpha(0.35)
        if sliderFrame.Slider and sliderFrame.Slider.Slider then
            sliderFrame.Slider.Slider:Disable()
        end
    end
end

function dodo.UI:SetDropdownEnabled(dd, enabled)
    if enabled then
        dd:SetAlpha(1.0)
        dd:Enable()
    else
        dd:SetAlpha(0.35)
        dd:Disable()
    end
end

-- ==============================
-- 1. 체크박스 생성 (순정 스타일)
-- ==============================
function dodo.UI:CreateCheckbox(parent, label, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)

    cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.Text:SetText(label)

    cb:SetChecked(getFunc())
    cb:SetScript("OnClick", function(self)
        setFunc(self:GetChecked())
        if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
            _G.dodoEditModePanel:UpdateDisabledStates()
        end
    end)

    return cb
end

-- ==============================
-- 2. 드롭다운 생성 (순정 WowStyle1DropdownTemplate 적용)
-- ==============================
function dodo.UI:CreateDropdown(parent, getFunc, setFunc, values)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(130, 22)

    local function RefreshText()
        local currentVal = getFunc()
        local foundText = "선택"
        for _, item in ipairs(values) do
            if item.value == currentVal then
                foundText = item.text
                break
            end
        end
        dropdown:SetText(foundText)
    end

    dropdown:SetupMenu(function(owner, rootDescription)
        for _, item in ipairs(values) do
            rootDescription:CreateRadio(
                item.text,
                function()
                    return getFunc() == item.value
                end,
                function()
                    setFunc(item.value)
                    RefreshText()
                    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                        _G.dodoEditModePanel:UpdateDisabledStates()
                    end
                end
            )
        end
    end)

    RefreshText()
    dropdown.RefreshText = RefreshText
    return dropdown
end

-- ==============================
-- 3. 슬라이더 생성 (블리자드 순정 EditModeSettingSliderTemplate 차용)
-- ==============================
function dodo.UI:CreateSlider(parent, getFunc, setFunc, minVal, maxVal, step)
    local frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
    frame:SetSize(150, 32)
    frame:Show()

    if frame.Label then
        frame.Label:Hide()
    end

    if frame.Slider then
        frame.Slider:ClearAllPoints()
        frame.Slider:SetPoint("LEFT", frame, "LEFT", -15, 7)
        frame.Slider:SetSize(115, 32)
        frame.Slider:Show()

        local formatters = {}
        formatters[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
            MinimalSliderWithSteppersMixin.Label.Right, function(value)
                return string_format("%.2f", value)
            end
        )

        local steps = (maxVal - minVal) / step
        frame.Slider:Init(getFunc(), minVal, maxVal, steps, formatters)

        frame.Slider.Slider:SetScript("OnValueChanged", function(slider, value)
            frame.Slider:FormatValue(value)
            setFunc(value)
            if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                _G.dodoEditModePanel:UpdateDisabledStates()
            end
        end)

        local function UpdateValue()
            local val = getFunc()
            frame.Slider:SetValue(val)
            frame.Slider:FormatValue(val)
        end

        UpdateValue()
        frame.UpdateValue = UpdateValue
    end

    return frame
end

-- ==============================
-- 4. 버튼 생성
-- ==============================
function dodo.UI:CreateButton(parent, label, text, onClickFunc)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(150, 26)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("LEFT", frame, "LEFT", 10, 0)
    title:SetText(label)

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonNoTooltipTemplate")
    btn:SetSize(60, 22)
    btn:SetPoint("LEFT", title, "RIGHT", 10, 0)
    btn:SetText(text)
    btn:SetScript("OnClick", onClickFunc)

    frame.Button = btn
    frame.Title = title

    return frame
end

-- ==============================
-- 5. 포트레이트 패널 생성 (순정 스타일)
-- ==============================
function dodo.UI:CreatePortraitPanel(name, titleText)
    local frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end

    frame:SetFrameStrata("HIGH")

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(titleText or "")
    end

    if frame.Bg then
        frame.Bg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end

    return frame
end

