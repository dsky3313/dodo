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
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local ipairs = ipairs
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local string_format = string.format
local UIParent = UIParent

-- ==============================
-- 파일 레벨 로컬 (정적) 함수 - 가비지 프리
-- ==============================
local function checkbox_on_click(self)
    if self.setFunc then
        self.setFunc(self:GetChecked())
    end
    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
        _G.dodoEditModePanel:UpdateDisabledStates()
    end
end

local function dropdown_refresh_text(dropdown)
    local currentVal = dropdown.getFunc()
    local foundText = "선택"
    for _, item in ipairs(dropdown.menuValues) do
        if item.value == currentVal then
            foundText = item.text
            break
        end
    end
    dropdown:SetText(foundText)
end

local function dropdown_menu_setup(owner, rootDescription)
    local values = owner.menuValues
    local getFunc = owner.getFunc
    local setFunc = owner.setFunc

    for _, item in ipairs(values) do
        rootDescription:CreateRadio(
            item.text,
            function()
                return getFunc() == item.value
            end,
            function()
                setFunc(item.value)
                owner:RefreshText()
                if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
                    _G.dodoEditModePanel:UpdateDisabledStates()
                end
            end
        )
    end
end

local function slider_formatter(value)
    return string_format("%.2f", value)
end

local function slider_on_value_changed(self, value)
    local sliderContainer = self:GetParent()
    local mainFrame = sliderContainer:GetParent()
    sliderContainer:FormatValue(value)
    if mainFrame.setFunc then
        mainFrame.setFunc(value)
    end
    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
        _G.dodoEditModePanel:UpdateDisabledStates()
    end
end

local function slider_update_value(mainFrame)
    if mainFrame.getFunc and mainFrame.Slider then
        local val = mainFrame.getFunc()
        mainFrame.Slider:SetValue(val)
        mainFrame.Slider:FormatValue(val)
    end
end

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

    cb.setFunc = setFunc
    cb:SetChecked(getFunc())
    cb:SetScript("OnClick", checkbox_on_click)

    return cb
end

-- ==============================
-- 2. 드롭다운 생성 (순정 WowStyle1DropdownTemplate 적용)
-- ==============================
function dodo.UI:CreateDropdown(parent, getFunc, setFunc, values)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(130, 22)

    dropdown.getFunc = getFunc
    dropdown.setFunc = setFunc
    dropdown.menuValues = values

    dropdown.RefreshText = dropdown_refresh_text
    dropdown:SetupMenu(dropdown_menu_setup)

    dropdown:RefreshText()
    return dropdown
end

-- ==============================
-- 3. 슬라이더 생성 (블리자드 순정 EditModeSettingSliderTemplate 차용)
-- ==============================
function dodo.UI:CreateSlider(parent, getFunc, setFunc, minVal, maxVal, step)
    local frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
    frame:SetSize(150, 32)
    frame:Show()

    frame.getFunc = getFunc
    frame.setFunc = setFunc

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
            MinimalSliderWithSteppersMixin.Label.Right, slider_formatter
        )

        local steps = (maxVal - minVal) / step
        frame.Slider:Init(getFunc(), minVal, maxVal, steps, formatters)
        frame.Slider.Slider:SetScript("OnValueChanged", slider_on_value_changed)

        local function UpdateValue()
            slider_update_value(frame)
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
function dodo.UI:CreatePortraitPanel(name, titleText, hideCloseButton)
    local frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end

    if hideCloseButton and frame.CloseButton then
        frame.CloseButton:Hide()
    end

    frame:SetFrameStrata("MEDIUM")

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(titleText or "")
    end

    if frame.Bg then
        frame.Bg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end

    return frame
end
