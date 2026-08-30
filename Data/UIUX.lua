-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.UI = dodo.UI or {}

-- ==============================
-- 캐싱
-- ==============================
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local Settings = Settings
local SettingsPanel = SettingsPanel
local string_format = string.format
local tonumber = tonumber
local tostring = tostring
local type = type
local UIParent = UIParent

-- ==============================
-- 정적 로컬 핸들러 (가비지 프리)
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
            function() return get_func() == item.value end,
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
-- UI 요소
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
            if userInput then self:SetText(self.old_text or "") end
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

-- ==============================
-- Settings
-- ==============================
dodo._optionRegistry = {}

---@param path string "카테고리" 또는 "카테고리.섹션헤더"
---@param buildFn fun(category: table)
---@param order number
function dodo.RegisterOption(path, buildFn, order)
    table.insert(dodo._optionRegistry, { path = path, build = buildFn, order = order })
end


local Formatters = {
    ["Percent"]  = function(v) return string_format("%d%%", math_floor((v or 0) * 100 + 0.5)) end,
    ["Integer"]  = function(v) return tostring(math_floor((v or 0) + 0.5)) end,
    ["Decimal1"] = function(v) return string_format("%.1f", v or 0) end,
    ["Decimal2"] = function(v) return string_format("%.2f", v or 0) end,
}

function dodo.UI:SettingsSectionHeader(category, text)
    local layout = SettingsPanel:GetLayout(category)
    local init = CreateSettingsListSectionHeaderInitializer(text)
    if layout then layout:AddInitializer(init) end
    return init
end

function dodo.UI:SettingsAddPreview(category, mixin_ref)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end
    local initializer = Settings.CreatePanelInitializer("dodoPreviewTemplate", {})
    initializer.GetExtent = function(self)
        if mixin_ref and type(mixin_ref.GetExtent) == "function" then
            return mixin_ref.GetExtent()
        end
        return 66
    end
    initializer.InitFrame = function(self, frame)
        frame:SetHeight(self:GetExtent())
        if not frame._dodo_init then
            frame._dodo_init = true
            if type(mixin_ref) == "table" then
                Mixin(frame, mixin_ref)
                if frame.OnLoad then frame:OnLoad() end
            end
        end
        if frame.Update then frame:Update() end
    end
    layout:AddInitializer(initializer)
end

---@param tabs string[] 탭 레이블 배열 (예: {"기본", "공격대 및 전장"})
---@param mixin_ref table OnLoad / Update / GetExtent / OnTabSelected(tabIndex) 구현
function dodo.UI:SettingsTabbedPreview(category, tabs, mixin_ref)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end
    local initializer = Settings.CreatePanelInitializer("dodoTabbedPreviewTemplate", {})
    initializer.GetExtent = function(self)
        if mixin_ref and type(mixin_ref.GetExtent) == "function" then
            return mixin_ref.GetExtent()
        end
        return 100
    end
    initializer.InitFrame = function(self, frame)
        frame:SetHeight(self:GetExtent())
        -- 다른 모듈의 미리보기가 이 프레임을 이미 썼으면 재초기화
        if frame._dodo_mixin ~= mixin_ref then
            frame._dodo_mixin = mixin_ref
            frame._dodo_init  = false
            -- 이전 mixin의 자식 프레임 숨김 (NineSlice 제외)
            for _, child in ipairs({ frame:GetChildren() }) do
                if child ~= frame.NineSlice then
                    child:Hide()
                end
            end
            frame._tabs      = nil
            frame._tab_group = nil
        end
        if not frame._dodo_init then
            frame._dodo_init = true
            -- 탭 동적 생성: 미리보기 레이블 오른쪽부터 좌→우 순서
            frame._tabs = {}
            local prev = frame.PreviewLabel
            for i, label in ipairs(tabs) do
                local tab = CreateFrame("Button", nil, frame, "MinimalTabTemplate")
                tab:SetHeight(30)
                tab:SetPoint("LEFT", prev, "RIGHT", i == 1 and 10 or 0, 0)
                if tab.Text then
                    tab.Text:SetText(label)
                    tab:SetWidth(tab.Text:GetStringWidth() + 20)
                else
                    tab:SetText(label)
                end
                frame._tabs[i] = tab
                prev = tab
            end
            if type(mixin_ref) == "table" then
                Mixin(frame, mixin_ref)
                if frame.OnLoad then frame:OnLoad() end
            end
            if #frame._tabs > 0 then
                local tab_group = CreateRadioButtonGroup()
                tab_group:AddButtons(frame._tabs)
                tab_group:SelectAtIndex(1)
                tab_group:RegisterCallback(ButtonGroupBaseMixin.Event.Selected, function(_, tab, tabIndex)
                    if frame.OnTabSelected then frame:OnTabSelected(tabIndex) end
                    if frame.Update then frame:Update() end
                end, frame)
                EventRegistry:RegisterCallback("Settings.CategoryChanged", function()
                    if frame.OnTabSelected then frame:OnTabSelected(1) end
                    tab_group:SelectAtIndex(1)
                end)
                frame._tab_group = tab_group
            end
        end
        if frame.Update then frame:Update() end
    end
    layout:AddInitializer(initializer)
    return initializer
end

---@return table initializer, table setting
function dodo.UI:SettingsCheckbox(category, varName, label, tooltip, default, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.Boolean, label, default)
    local initializer = Settings.CreateControlInitializer("dodoCheckboxTemplate", setting, nil, tooltip)
    setting:SetValueChangedCallback(function(_, value)
        if type(func) == "function" then func(value) end
    end)
    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end
    return initializer, setting
end

---@return table setting, table initializer
function dodo.UI:SettingsDropDown(category, varName, label, tooltip, options, default, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.String, label, default or options[1].value)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(options) do container:Add(option.value, option.text or option.label) end
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

---@return table initializer, table setting
function dodo.UI:SettingsSlider(category, varName, label, tooltip, min, max, step, default, formatType, func)
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
    return initializer, setting
end

---@return table cbSetting, table ddSetting, table initializer
function dodo.UI:SettingsCheckboxDropDown(category, varNameCB, varNameDD, label, tooltip, options, defaultCB, defaultDD, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_DD = "dodo_" .. varNameDD
    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local fallbackValue = (options and options[1]) and options[1].value or ""
    local ddSetting = Settings.GetSetting(varID_DD) or Settings.RegisterAddOnSetting(category, varID_DD, varNameDD, dodoDB, Settings.VarType.String, label, defaultDD or fallbackValue)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        if options then
            for _, option in ipairs(options) do container:Add(option.value, option.text or option.label) end
        end
        return container:GetData()
    end
    local data = { name = label, tooltip = tooltip, cbSetting = cbSetting, dropdownSetting = ddSetting, dropdownOptions = GetOptions, cbLabel = label, cbTooltip = tooltip, dropDownLabel = label, dropDownTooltip = tooltip }
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

---@return table cbSetting, table sliderSetting, table initializer
function dodo.UI:SettingsCheckboxSlider(category, varNameCB, varNameSlider, label, tooltip, min, max, step, defaultCB, defaultSlider, formatType, func)
    local varID_CB = "dodo_" .. varNameCB
    local varID_Slider = "dodo_" .. varNameSlider
    local cbSetting = Settings.GetSetting(varID_CB) or Settings.RegisterAddOnSetting(category, varID_CB, varNameCB, dodoDB, Settings.VarType.Boolean, label, defaultCB or false)
    local sliderSetting = Settings.GetSetting(varID_Slider) or Settings.RegisterAddOnSetting(category, varID_Slider, varNameSlider, dodoDB, Settings.VarType.Number, label, tonumber(defaultSlider) or min)
    local sliderOptions = Settings.CreateSliderOptions(min, max, step)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Formatters[formatType] or Formatters["Percent"])
    local data = { name = label, tooltip = tooltip, cbSetting = cbSetting, sliderSetting = sliderSetting, sliderOptions = sliderOptions }
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

---@return table setting, table initializer
function dodo.UI:SettingsColorRow(category, varName, label, tooltip, default, func)
    local varID = "dodo_" .. varName
    local setting = Settings.GetSetting(varID) or Settings.RegisterAddOnSetting(category, varID, varName, dodoDB, Settings.VarType.String, label, default or "ffffffff")
    local initializer = Settings.CreateControlInitializer("dodoColorRowTemplate", setting, nil, tooltip)
    setting:SetValueChangedCallback(function(_, value)
        if type(func) == "function" then func(value) end
    end)
    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(initializer) end
    return setting, initializer
end

-- ==============================
-- [섹션 5] 멀티드롭다운
-- ==============================
dodoMultiDropDownMixin = {}

local function multi_dd_sel_text(selections)
    if #selections == 0 then return "없음" end
    return nil
end

local function multi_dd_cb_init(frame)
    frame.leftTexture1:SetPoint("LEFT", frame, "LEFT", 4, 0)
end

function dodoMultiDropDownMixin:Init(initializer)
    local data = initializer.data
    if not self.Dropdown then
        local lbl = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lbl:SetPoint("LEFT",  self, "LEFT",   37, 0)
        lbl:SetPoint("RIGHT", self, "CENTER", -85, 0)
        lbl:SetJustifyH("LEFT")
        self.Label = lbl
        local dd = CreateFrame("DropdownButton", nil, self, "WowStyle2DropdownTemplate")
        dd:SetSize(220, 25)
        dd:SetPoint("LEFT", self, "CENTER", -48, 0)
        dd:SetSelectionText(multi_dd_sel_text)
        self.Dropdown = dd
    end
    self.Label:SetText(data.label)
    local items = data.items
    local func  = data.func
    local mode  = data.mode
    self.Dropdown:SetupMenu(function(dropdown, rootDescription)
        for _, item in ipairs(items) do
            if mode == "action" then
                local cb = rootDescription:CreateCheckbox(
                    item.text,
                    function() return false end,
                    function()
                        if type(item.onClick) == "function" then item.onClick() end
                    end
                )
                cb:AddInitializer(multi_dd_cb_init)
            else
                local key = item.key
                local cb = rootDescription:CreateCheckbox(
                    item.text,
                    function() return dodoDB and dodoDB[key] ~= false end,
                    function()
                        local new_val = not (dodoDB and dodoDB[key] ~= false)
                        if dodoDB then dodoDB[key] = new_val end
                        if type(func) == "function" then func(key, new_val) end
                    end
                )
                cb:AddInitializer(multi_dd_cb_init)
            end
        end
    end)
end

function dodo.UI:SettingsMultiDropDown(category, label, items, func)
    local data = { label = label, items = items, func = func }
    local init = Settings.CreatePanelInitializer("dodoMultiDropDownTemplate", data)
    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(init) end
    return init
end

function dodo.UI:SettingsActionDropDown(category, label, items)
    local data = { label = label, items = items, mode = "action" }
    local init = Settings.CreatePanelInitializer("dodoMultiDropDownTemplate", data)
    local layout = SettingsPanel:GetLayout(category)
    if layout then layout:AddInitializer(init) end
    return init
end
