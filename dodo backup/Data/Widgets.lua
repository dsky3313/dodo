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
    if self.set_func then
        self.set_func(self:GetChecked())
    end
    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
        _G.dodoEditModePanel:UpdateDisabledStates()
    end
    if _G.dodoEditModeSystemPanel and _G.dodoEditModeSystemPanel.UpdateDisabledStates then
        _G.dodoEditModeSystemPanel:UpdateDisabledStates()
    end
end

local function dropdown_refresh_text(dropdown)
    local current_val = dropdown.get_func()
    local found_text = "선택"
    for _, item in ipairs(dropdown.menu_values) do
        if item.value == current_val then
            found_text = item.text
            break
        end
    end
    dropdown:SetText(found_text)
end

local function dropdown_menu_setup(owner, root_description)
    local values = owner.menu_values
    local get_func = owner.get_func
    local set_func = owner.set_func

    for _, item in ipairs(values) do
        root_description:CreateRadio(
            item.text,
            function()
                return get_func() == item.value
            end,
            function()
                set_func(item.value)
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
    local slider_container = self:GetParent()
    local main_frame = slider_container:GetParent()
    slider_container:FormatValue(value)
    if main_frame.set_func then
        main_frame.set_func(value)
    end
    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
        _G.dodoEditModePanel:UpdateDisabledStates()
    end
end

local function slider_update_value(main_frame)
    if main_frame.get_func and main_frame.Slider then
        local val = main_frame.get_func()
        main_frame.Slider:SetValue(val)
        main_frame.Slider:FormatValue(val)
    end
end

local function editbox_on_escape_pressed(self)
    self:SetText(self.old_text or "")
    self:ClearFocus()
end

local function editbox_on_enter_pressed(self)
    if self.set_func then
        self.set_func(self:GetText())
    end
    self:ClearFocus()
    if _G.dodoEditModePanel and _G.dodoEditModePanel.UpdateDisabledStates then
        _G.dodoEditModePanel:UpdateDisabledStates()
    end
    if _G.dodoEditModeSystemPanel and _G.dodoEditModeSystemPanel.UpdateDisabledStates then
        _G.dodoEditModeSystemPanel:UpdateDisabledStates()
    end
end

local function editbox_on_focus_gained(self)
    self.old_text = self:GetText()
end

-- ==============================
-- 컴포넌트 활성/비활성 헬퍼 API
-- ==============================
function dodo.UI:SetComponentEnabled(comp, enabled)
    if enabled then
        comp:SetAlpha(1.0)
        comp:Enable()
        if comp.Text then comp.Text:SetTextColor(1, 1, 1) end
    else
        comp:SetAlpha(0.35)
        comp:Disable()
        if comp.Text then comp.Text:SetTextColor(0.5, 0.5, 0.5) end
    end
end

function dodo.UI:SetSliderEnabled(slider_frame, enabled)
    if enabled then
        slider_frame:SetAlpha(1.0)
        if slider_frame.Slider and slider_frame.Slider.Slider then
            slider_frame.Slider.Slider:Enable()
        end
    else
        slider_frame:SetAlpha(0.35)
        if slider_frame.Slider and slider_frame.Slider.Slider then
            slider_frame.Slider.Slider:Disable()
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

function dodo.UI:SetEditBoxEnabled(eb, enabled)
    if enabled then
        eb:SetAlpha(1.0)
        eb:Enable()
        if eb.Label then eb.Label:SetTextColor(1, 1, 1) end
    else
        eb:SetAlpha(0.35)
        eb:Disable()
        if eb.Label then eb.Label:SetTextColor(0.5, 0.5, 0.5) end
    end
end

-- ==============================
-- 1. 체크박스 생성 (순정 스타일)
-- ==============================
function dodo.UI:CreateCheckbox(parent, label, get_func, set_func)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(32, 32)

    cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.Text:SetText(label)

    cb.set_func = set_func
    cb:SetChecked(get_func())
    cb:SetScript("OnClick", checkbox_on_click)

    return cb
end

-- ==============================
-- 2. 드롭다운 생성 (순정 WowStyle1DropdownTemplate 적용)
-- ==============================
function dodo.UI:CreateDropdown(parent, get_func, set_func, values, label_text)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(120, 25)

    dropdown.get_func = get_func
    dropdown.set_func = set_func
    dropdown.menu_values = values

    dropdown.RefreshText = dropdown_refresh_text
    dropdown:SetupMenu(dropdown_menu_setup)

    dropdown:RefreshText()

    if label_text and label_text ~= "" then
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetText(label_text)
        label:SetPoint("LEFT", dropdown, "LEFT", -157, 0)
        dropdown.Label = label
    end

    return dropdown
end

-- ==============================
-- 3. 슬라이더 생성 (블리자드 순정 EditModeSettingSliderTemplate 차용)
-- ==============================
function dodo.UI:CreateSlider(parent, get_func, set_func, min_val, max_val, step, label_text)
    local frame = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
    frame:SetSize(150, 32)
    frame:Show()

    frame.get_func = get_func
    frame.set_func = set_func

    if frame.Label then
        if label_text and label_text ~= "" then
            frame.Label:SetText(label_text)
            frame.Label:SetFontObject("GameFontHighlight")
            frame.Label:ClearAllPoints()
            frame.Label:SetPoint("LEFT", frame, "LEFT", -157, 2)
            frame.Label:Show()
        else
            frame.Label:Hide()
        end
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

        local steps = (max_val - min_val) / step
        frame.Slider:Init(get_func(), min_val, max_val, steps, formatters)
        frame.Slider.Slider:SetScript("OnValueChanged", slider_on_value_changed)

        local function update_value()
            slider_update_value(frame)
        end

        update_value()
        frame.UpdateValue = update_value
    end

    return frame
end

-- ==============================
-- 4. 버튼 생성
-- ==============================
function dodo.UI:CreateButton(parent, label, text, on_click_func)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(150, 26)

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("LEFT", frame, "LEFT", 10, 0)
    title:SetText(label)

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonNoTooltipTemplate")
    btn:SetSize(60, 22)
    btn:SetPoint("LEFT", title, "RIGHT", 10, 0)
    btn:SetText(text)
    btn:SetScript("OnClick", on_click_func)

    frame.Button = btn
    frame.Title = title

    return frame
end

-- ==============================
-- 5. 포트레이트 패널 생성 (순정 스타일)
-- ==============================
function dodo.UI:CreatePortraitPanel(name, title_text, hide_close_button)
    local frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate")
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end

    if hide_close_button and frame.CloseButton then
        frame.CloseButton:Hide()
    end

    frame:SetFrameStrata("MEDIUM")

    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(title_text or "")
    end

    if frame.Bg then
        frame.Bg:SetVertexColor(0.08, 0.08, 0.08, 0.8)
    end

    return frame
end

-- ==============================
-- 6. 에딧박스 생성 (순정 InputBoxTemplate 적용)
-- ==============================
function dodo.UI:CreateEditBox(parent, get_func, set_func, label_text, is_read_only)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(130, 22)
    eb:SetAutoFocus(false)

    eb.get_func = get_func
    eb.set_func = set_func
    eb.is_read_only = is_read_only

    eb:SetText(get_func() or "")

    eb:SetScript("OnEscapePressed", editbox_on_escape_pressed)
    eb:SetScript("OnEnterPressed", editbox_on_enter_pressed)
    eb:SetScript("OnEditFocusGained", editbox_on_focus_gained)

    if is_read_only then
        eb:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(self.old_text or "")
            end
        end)
    end

    if label_text and label_text ~= "" then
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetText(label_text)
        label:SetPoint("LEFT", eb, "LEFT", -157, 0)
        eb.Label = label
    end

    return eb
end
