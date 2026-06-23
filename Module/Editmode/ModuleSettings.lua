-- ==============================
-- Inspired
-- ==============================
-- LegionRemixHelper (https://www.curseforge.com/wow/addons/legion-remix-helper)
-- LibEditMode (https://www.curseforge.com/wow/addons/libeditmode)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

---@class EditModeSystemFrame : Frame @편집모드 전용 시스템 앵커 프레임
---@field systemName string 시스템 고유 이름
---@field systemLabel string 편집 모드 상자 위에 뜰 이름표 텍스트
---@field systemTooltip string 마우스 오버 시 보일 툴팁 내용
---@field onPositionChanged fun(new_point_data: table)|nil 위치 변경 콜백 함수

---@class dodoEditMode
---@field systems table<string, EditModeSystemFrame> 등록된 편집모드 가상 앵커 프레임 모음
---@field systemToggle CheckButton 모듈 편집 활성화 체크박스
---@field showSystems boolean 모듈 편집 활성화 여부
---@field panel Frame 메인 모듈 설정 패널 프레임

-- dodo.EditMode 전역 등록
---@type dodoEditMode
dodo.EditMode = {
    systems = {},
    systemToggle = nil,
    showSystems = true,
    panel = nil,
}
local EditMode = dodo.EditMode

local Config = {
    positionX = -3,
    positionY = -6,
}

-- ==============================
-- 캐싱
-- ==============================
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local EditModeManagerFrame = EditModeManagerFrame
local EventRegistry = EventRegistry
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue
local math_abs = math.abs
local MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin
local pairs = pairs
local string_format = string.format
local table_insert = table.insert
local table_sort = table.sort
local type = type
local UIParent = UIParent

-- ==============================
-- 동적 설정 등록 API
-- ==============================
local registered_settings = {}

---@param categoryName string 설정 대분류 카테고리 명
---@param settingItems table 설정 컴포넌트 데이터 목록
function dodo.RegisterEditModeModuleSetting(categoryName, settingItems)
    if not registered_settings[categoryName] then
        registered_settings[categoryName] = {}
    end
    table_insert(registered_settings[categoryName], settingItems)
end

-- ==============================
-- 파일 레벨 로컬 (정적) 함수 전방 선언 (순서 꼬임 방지)
-- ==============================
local on_enter_edit_mode
local on_exit_edit_mode
local create_system_toggle
local on_checkbox_click
local update_systems_visibility

-- ==============================
-- 파일 레벨 로컬 (정적) 함수 - 가비지 프리
-- ==============================
local function sort_setting_sets(a, b)
    if a.hasSetting ~= b.hasSetting then
        return not a.hasSetting
    end

    return a.name < b.name
end

local function update_systems_visibility()
    if not EditMode.showSystems then return end
    for _, system in pairs(EditMode.systems) do
        local isActive = true
        if system.checkActiveFunc then
            isActive = system.checkActiveFunc()
        end

        if isActive then
            system:HighlightSystem()
            system:Show()
        else
            system:ClearHighlight()
            system:Hide()
        end
    end
end

local function update_disabled_states_action()
    local panel = EditMode.panel
    if not panel or not panel.update_queue then return end

    for _, q in ipairs(panel.update_queue) do
        local disabled = q.check()
        local enabled = not disabled
        if q.type == "slider" then
            dodo.UI:SetSliderEnabled(q.comp, enabled)
        elseif q.type == "dropdown" then
            dodo.UI:SetDropdownEnabled(q.comp, enabled)
        elseif q.type == "button" then
            if enabled then
                q.comp:SetAlpha(1.0)
                if q.comp.Button then q.comp.Button:Enable() end
                if q.comp.Title then q.comp.Title:SetTextColor(dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b) end
            else
                q.comp:SetAlpha(0.35)
                if q.comp.Button then q.comp.Button:Disable() end
                if q.comp.Title then q.comp.Title:SetTextColor(dodo.Colors.Gray.r, dodo.Colors.Gray.g, dodo.Colors.Gray.b) end
            end
        else
            dodo.UI:SetComponentEnabled(q.comp, enabled)
        end
    end
end

local function panel_on_minimized()
    local panel = EditMode.panel
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Config.positionX, Config.positionY)
    panel:SetWidth(200)
    panel:SetHeight(64)
    if panel.scroll_frame then
        panel.scroll_frame:Hide()
    end
    dodoDB.editModeMinimized = true
end

local function panel_on_maximized()
    local panel = EditMode.panel
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Config.positionX, Config.positionY)
    panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Config.positionX, -Config.positionY)
    panel:SetWidth(360)
    if panel.scroll_frame then
        panel.scroll_frame:Show()
    end
    dodoDB.editModeMinimized = false
end

local function panel_on_show(self)
    if dodoDB.editModeMinimized then
        self.max_min_frame:Minimize(true)
    else
        self.max_min_frame:Maximize(true)
    end
    update_disabled_states_action()
end

-- ==============================
-- 기능 1 - 편집모드 모듈 설정 패널
-- ==============================
local function create_edit_mode_panel()
    if EditMode.panel then return EditMode.panel end

    local frame = dodo.UI:CreatePortraitPanel("dodoEditModePanel", "dodo 모듈")
    if EditModeManagerFrame then
        local parentStrata = EditModeManagerFrame:GetFrameStrata()
        local targetStrata = "HIGH"
        if parentStrata == "DIALOG" then
            targetStrata = "HIGH"
        elseif parentStrata == "HIGH" then
            targetStrata = "MEDIUM"
        elseif parentStrata == "MEDIUM" then
            targetStrata = "LOW"
        else
            targetStrata = parentStrata
        end
        frame:SetFrameStrata(targetStrata)
        frame:SetFrameLevel(EditModeManagerFrame:GetFrameLevel())
    end
    frame:SetWidth(360)
    frame:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Config.positionX, Config.positionY)
    frame:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Config.positionX, -Config.positionY)
    frame:Hide()

    EditMode.panel = frame
    local update_queue = {}
    frame.update_queue = update_queue

    -- 최소화/최대화 버튼 추가
    local max_min_frame = CreateFrame("Frame", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
    max_min_frame:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
    max_min_frame:SetOnMinimizedCallback(panel_on_minimized)
    max_min_frame:SetOnMaximizedCallback(panel_on_maximized)
    frame.max_min_frame = max_min_frame

    local scroll_frame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "ScrollFrameTemplate")
    scroll_frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scroll_frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    scroll_frame.scrollBarHideIfUnscrollable = true
    scroll_frame.scrollBarX = 6
    scroll_frame.scrollBarTopY = -4
    frame.scroll_frame = scroll_frame

    local scroll_child = CreateFrame("Frame", nil, scroll_frame)
    scroll_child:SetSize(310, 1)
    scroll_frame:SetScrollChild(scroll_child)

    local default_menu_items = {
        { isHeader = true, text = "전투" },
        { isHeader = true, text = "인터페이스" },
        { isHeader = true, text = "편의기능" },
        { isHeader = true, text = "일반" },
        { isHeader = true, text = "설정 & 프로필" },
    }

    local menu_items = {}
    for _, header_item in ipairs(default_menu_items) do
        table_insert(menu_items, header_item)
        if header_item.isHeader then
            local category = header_item.text
            local groups = registered_settings[category]
            if groups then
                local flat_items = {}
                for g = 1, #groups do
                    local group_items = groups[g]
                    for i = 1, #group_items do
                        table_insert(flat_items, group_items[i])
                    end
                end

                local sets = {}
                local idx = 1
                while idx <= #flat_items do
                    local item = flat_items[idx]
                    if item.isSpacer then
                        idx = idx + 1
                    else
                        local next_item = flat_items[idx + 1]
                        if next_item and (next_item.type == "dropdown" or next_item.type == "slider") and (not item.type) and (not next_item.preventJoin) then
                            item.isJoined = true
                            next_item.isJoined = true
                            table_insert(sets, {
                                cb = item,
                                setting = next_item,
                                name = item.name or "",
                                hasSetting = true
                            })
                            idx = idx + 2
                        else
                            item.isJoined = false
                            table_insert(sets, {
                                cb = item,
                                name = item.name or "",
                                hasSetting = (item.type == "dropdown" or item.type == "slider" or item.type == "button")
                            })
                            idx = idx + 1
                        end
                    end
                end

                table_sort(sets, sort_setting_sets)

                for _, set in ipairs(sets) do
                    table_insert(menu_items, set.cb)
                    if set.setting then
                        local cb_item = set.cb
                        local original_disabled = set.setting.disabled
                        set.setting.disabled = function()
                            if original_disabled and original_disabled() then
                                return true
                            end
                            if cb_item then
                                if cb_item.get and not cb_item.get() then
                                    return true
                                end
                                if cb_item.disabled and cb_item.disabled() then
                                    return true
                                end
                            end
                            return false
                        end
                        table_insert(menu_items, set.setting)
                    end
                end
            end
        end
    end

    local start_y = -5
    local current_y = start_y
    local has_divider = false
    local col = 0

    for i, item in ipairs(menu_items) do
        if item.isHeader then
            if col == 1 then
                current_y = current_y - 26
                col = 0
            end

            if has_divider then
                local divider = scroll_child:CreateTexture(nil, "BACKGROUND")
                divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
                divider:SetSize(310, 8)
                divider:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 0, current_y + 12)
                divider:SetAlpha(0.35)
                current_y = current_y - 14
            end

            local title_frame = CreateFrame("Frame", nil, scroll_child)
            title_frame:SetSize(310, 24)
            title_frame:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 2, current_y)

            local text = title_frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            text:SetPoint("LEFT", title_frame, "LEFT", 0, 0)
            text:SetText(item.text)

            current_y = current_y - 28
            has_divider = true
        else
            if item.isSpacer then
                if col == 1 then
                    current_y = current_y - 26
                    col = 0
                end
            elseif item.type == "dropdown" then
                if not item.isJoined and col == 1 then
                    current_y = current_y - 26
                    col = 0
                end
                local dd = dodo.UI:CreateDropdown(scroll_child, item.get, item.set, item.values, not item.isJoined and item.name or nil)
                dd:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 165, current_y - 4)

                if item.disabled then
                    table_insert(update_queue, { comp = dd, type = "dropdown", check = item.disabled })
                end

                if not item.isJoined then
                    current_y = current_y - 26
                    col = 0
                else
                    if col == 1 then
                        current_y = current_y - 26
                        col = 0
                    end
                end
            elseif item.type == "slider" then
                if not item.isJoined and col == 1 then
                    current_y = current_y - 26
                    col = 0
                end
                local slider = dodo.UI:CreateSlider(scroll_child, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1, not item.isJoined and item.name or nil)
                slider:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 175, current_y - 8)

                if item.disabled then
                    table_insert(update_queue, { comp = slider, type = "slider", check = item.disabled })
                end

                if not item.isJoined then
                    current_y = current_y - 26
                    col = 0
                else
                    if col == 1 then
                        current_y = current_y - 26
                        col = 0
                    end
                end
            elseif item.type == "button" then
                if col == 1 then
                    current_y = current_y - 26
                    col = 0
                end

                local btn_frame = dodo.UI:CreateButton(scroll_child, item.name, item.text or "실행", item.onClick)
                btn_frame:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", 8, current_y)

                if item.disabled then
                    table_insert(update_queue, { comp = btn_frame, type = "button", check = item.disabled })
                end

                current_y = current_y - 26
            else
                local next_item = menu_items[i + 1]
                if item.isJoined and col == 1 then
                    current_y = current_y - 26
                    col = 0
                end

                local original_set = item.set
                local function custom_set(checked)
                    if original_set then original_set(checked) end
                    update_disabled_states_action()
                    update_systems_visibility()
                end
                local cb = dodo.UI:CreateCheckbox(scroll_child, item.name, item.get, custom_set)
                local pos_x = (col == 0) and 8 or 165
                cb:SetPoint("TOPLEFT", scroll_child, "TOPLEFT", pos_x, current_y)

                if item.disabled then
                    table_insert(update_queue, { comp = cb, type = "checkbox", check = item.disabled })
                end

                if col == 0 then
                    col = 1
                else
                    current_y = current_y - 26
                    col = 0
                end
            end
        end
    end

    if col == 1 then
        current_y = current_y - 26
    end

    scroll_child:SetHeight(math_abs(current_y) + 15)
    frame.UpdateDisabledStates = update_disabled_states_action

    frame:HookScript("OnShow", panel_on_show)

    return frame
end

-- ==============================
-- 이벤트 및 콜백 구현 (전방 선언 대응)
-- ==============================
on_enter_edit_mode = function()
    for _, system in pairs(EditMode.systems) do
        local pt = dodoDB.editMode and dodoDB.editMode[system.systemName]
        system._original_point = pt and {
            point        = pt.point,
            relativeTo   = pt.relativeTo,
            relativePoint = pt.relativePoint,
            xOfs         = pt.xOfs,
            yOfs         = pt.yOfs,
        } or nil
        system._has_active_changes = false
    end

    if EditMode.showSystems then
        update_systems_visibility()
    end
    create_system_toggle()

    local panel = create_edit_mode_panel()
    if panel then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Config.positionX, Config.positionY)
        if dodoDB.editModeMinimized then
            panel:SetWidth(200)
            panel:SetHeight(64)
        else
            panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Config.positionX, -Config.positionY)
            panel:SetWidth(360)
        end
        panel:Show()
    end
end

on_exit_edit_mode = function()
    for _, system in pairs(EditMode.systems) do
        system:ClearHighlight()
        system:Hide()
    end

    if EditMode.panel then
        EditMode.panel:Hide()
    end

    -- dodo 모듈 편집 해제 시 세부설정창도 완벽히 동시 은닉
    if EditMode.HideSystemWingPanel then EditMode.HideSystemWingPanel() end
end

on_checkbox_click = function(checked)
    EditMode.showSystems = checked
    if checked then
        on_enter_edit_mode()
    else
        on_exit_edit_mode()
    end
end

create_system_toggle = function()
    if EditMode.systemToggle then return end
    if not EditModeManagerFrame then return end

    local get_show_systems = function() return EditMode.showSystems end
    local checkBox = dodo.UI:CreateCheckbox(EditModeManagerFrame, "dodo 모듈 편집", get_show_systems, on_checkbox_click)
    checkBox:SetPoint("TOP", EditModeManagerFrame, "TOP", 15, -50)

    if checkBox.Text then
        checkBox.Text:SetFontObject("GameFontHighlightMedium")
        checkBox.Text:SetTextColor(dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b)
    end

    EditMode.systemToggle = checkBox
end

local function system_on_drag_start(self)
    self:SetMovable(true)
    self:StartMoving()
end

-- selection이 마우스를 가로채므로 드래그는 selection → system 위임 (LibEditMode 방식: self.parent)
local function selection_on_drag_start(self)
    self.parent:SetMovable(true)
    self.parent:StartMoving()
end

local function selection_on_drag_stop(self)
    system_on_drag_stop(self.parent)
end

local function system_on_drag_stop(self)
    self:StopMovingOrSizing()
    local new_point = { self:GetPoint() }
    if not new_point[1] then return end

    local system_name = self.systemName
    local new_point_data = {
        point = new_point[1],
        relativeTo = self:GetParent():GetName() or "UIParent",
        relativePoint = new_point[3],
        xOfs = new_point[4],
        yOfs = new_point[5],
    }

    dodoDB.editMode = dodoDB.editMode or {}
    dodoDB.editMode[system_name] = new_point_data
    self._has_active_changes = true

    if self.onPositionChanged then
        self.onPositionChanged(new_point_data)
    end
end

local function selection_get_label_text(self)
    return self:GetParent().systemLabel or ""
end

local function system_get_system_name(self)
    return self.parentFrame.systemTooltip or ""
end

local function on_edit_mode_enter()
    on_enter_edit_mode()
end

-- ==============================
-- 외부 제공 API
-- ==============================
---@param system_name string 시스템 고유 이름
---@param system_label string 편집 모드 상자 위에 뜰 이름표 텍스트
---@param system_tooltip string 마우스 오버 시 보일 툴팁 내용
---@param parent_frame Frame 부모 프레임 (대체로 UIParent)
---@param width number|nil 가로 크기 (기본값: 150)
---@param height number|nil 세로 크기 (기본값: 50)
---@param default_point table|nil 초기 위치 좌표 { point, relativeTo, relativePoint, xOfs, yOfs }
---@param on_position_changed nil|fun(new_point_data: table) 위치 변경 시 호출될 콜백 함수
function EditMode:CreateSystem(system_name, system_label, system_tooltip, parent_frame, width, height, default_point, on_position_changed, check_active_func)
    if self.systems[system_name] then
        return
    end

    -- EditModeSystemTemplate 제거: 자체 RegisterForDrag가 StartMoving 후 드래그 소유권 충돌 → 멈춤 불가
    local system = CreateFrame("Frame", "dodoEditMode" .. system_name, parent_frame)
    local selection = CreateFrame("Frame", nil, system, "EditModeSystemSelectionTemplate")
    selection:SetAllPoints()
    selection:SetFrameStrata("LOW")
    selection:EnableMouse(false)  -- 시각 전용: 마우스 이벤트는 system이 직접 받음
    
    system:SetSize(width or 150, height or 50)
    system.systemName = system_name
    system.systemLabel = system_label
    system.systemTooltip = system_tooltip
    system.onPositionChanged = on_position_changed
    system.checkActiveFunc = check_active_func
    system.defaultPoint    = default_point
    system._isDodoSystem   = true

    -- EditModeSystemMixin 없으므로 필요한 메서드만 수동 위임
    system.GetSystemName  = function(s) return s.systemLabel or "" end
    system.GetSettings    = function(s) return {} end
    system.HasSettings    = function(s) return false end
    system.HighlightSystem = function(s) selection:ShowHighlighted() end
    system.ClearHighlight  = function(s) selection:Hide() end

    -- 저장된 좌표 로드 (빈 테이블 예외 차단 후 default_point 보장)
    local saved_point = dodoDB.editMode and dodoDB.editMode[system_name]
    local point = (saved_point and saved_point.point) and saved_point or default_point or {}
    system:ClearAllPoints()
    system:SetPoint(point.point or "CENTER", point.relativeTo or parent_frame, point.relativePoint or "CENTER", point.xOfs or 0, point.yOfs or 0)

    selection.GetLabelText = selection_get_label_text

    -- EditModeSystemSelectionTemplate 내부 툴팁 대응용 프록시 객체
    selection.system = {
        parentFrame = system,
        GetSystemName = system_get_system_name
    }

    -- system이 직접 드래그/클릭 처리 (selection은 EnableMouse(false)이므로 통과)
    system:EnableMouse(true)
    system:RegisterForDrag("LeftButton")
    system:SetScript("OnDragStart", system_on_drag_start)
    system:SetScript("OnDragStop", system_on_drag_stop)
    system:SetScript("OnMouseDown", function(self, button)
        for _, sys in pairs(EditMode.systems) do
            if sys ~= system then
                sys:HighlightSystem()
            end
        end
        selection:ShowSelected()

        local dlg = _G.EditModeSystemSettingsDialog
        if dlg then
            EditMode.customPanelActive = true
            if dlg:IsShown() then dlg:Hide() end
            dlg:AttachToSystemFrame(system)
            if EditMode.SelectPosFrame then EditMode.SelectPosFrame(system) end
            C_Timer.After(0, function()
                EditMode.customPanelActive = false
            end)
        end
    end)

    -- EditModeSystemSettingsDialog 호환 stub (AttachToSystemFrame 요건)
    if EditModeSettingDisplayInfoManager then
        EditModeSettingDisplayInfoManager.systemSettingDisplayInfo[system_name] =
            EditModeSettingDisplayInfoManager.systemSettingDisplayInfo[system_name] or {}
    end
    system.system = system_name
    system.settingDisplayInfoMap = {}
    system.settingsDialogAnchor = AnchorUtil.CreateAnchor("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -250, 200)
    system.ShouldResetSettingsDialogAnchors = function(s, old) return old ~= s end
    system.GetSettingsDialogAnchor = function(s) return s.settingsDialogAnchor end
    system.HasActiveChanges = function(s) return s._has_active_changes or false end
    system.AddExtraButtons = function(s, pool)
        if not s.defaultPoint then return false end
        local btn = pool:Acquire()
        btn.layoutIndex = 3
        btn:SetText(HUD_EDIT_MODE_RESET_POSITION)
        btn:SetEnabled(true)
        btn:SetOnClickHandler(function()
            local dp = s.defaultPoint
            local ref = (type(dp.relativeTo) == "string") and (_G[dp.relativeTo] or UIParent) or (dp.relativeTo or UIParent)
            s:ClearAllPoints()
            s:SetPoint(dp.point or "CENTER", ref, dp.relativePoint or "CENTER", dp.xOfs or 0, dp.yOfs or 0)
            local save = {
                point        = dp.point or "CENTER",
                relativeTo   = (type(dp.relativeTo) == "string") and dp.relativeTo or (dp.relativeTo and dp.relativeTo:GetName()) or "UIParent",
                relativePoint = dp.relativePoint or "CENTER",
                xOfs         = dp.xOfs or 0,
                yOfs         = dp.yOfs or 0,
            }
            dodoDB.editMode = dodoDB.editMode or {}
            dodoDB.editMode[s.systemName] = save
            -- 원본이 있으면 되돌리기 버튼 활성화 (기본값 ≠ 세션 원본일 수 있음)
            s._has_active_changes = s._original_point ~= nil
            if s.onPositionChanged then s.onPositionChanged(save) end
            local dlg = _G.EditModeSystemSettingsDialog
            if dlg and dlg.attachedToSystem == s then dlg:UpdateDialog(s) end
        end)
        btn:Show()
        return true
    end
    system.OnKeyDown = function(s, key) end
    system.OnKeyUp = function(s, key) end
    system.ClearDownKeys = function(s) end

    system:Hide()
    self.systems[system_name] = system
    
    -- 최초 등록 후 모듈 위치를 DB 좌표에 맞게 1회 강제 동기화
    if on_position_changed and (dodoDB.editMode and dodoDB.editMode[system_name] or default_point) then
        on_position_changed(point)
    end
end

---@param system_name string
---@return EditModeSystemFrame|nil
function EditMode:GetSystem(system_name)
    return self.systems[system_name]
end

-- ==============================
-- 초기화 및 이벤트 등록
-- ==============================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodoDB.editMode = dodoDB.editMode or {}
    elseif event == "PLAYER_LOGIN" then
        EventRegistry:RegisterCallback("EditMode.Enter", on_edit_mode_enter)
        EventRegistry:RegisterCallback("EditMode.Exit", on_exit_edit_mode)
    end
end)
