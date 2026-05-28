-- ==============================
-- Inspired
-- ==============================
-- LegionRemixHelper (EditModeUtils.lua)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- dodo.EditMode 전역 등록
dodo.EditMode = {
    systems = {},
    systemToggle = nil,
    showSystems = true,
    panel = nil,
}
local EditMode = dodo.EditMode

local Settings = {
    positionX = -3,
    positionY = -6,
}

-- ==============================
-- 캐싱
-- ==============================
-- abc 가나다 순으로 정렬 완료
local ButtonFrameTemplate_HidePortrait = ButtonFrameTemplate_HidePortrait
local CreateFrame = CreateFrame
local CreateMinimalSliderFormatter = CreateMinimalSliderFormatter
local EditModeManagerFrame = EditModeManagerFrame
local EventRegistry = EventRegistry
local ipairs = ipairs
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
local registeredSettings = {}

function dodo.RegisterEditModeSetting(categoryName, settingItems)
    if not registeredSettings[categoryName] then
        registeredSettings[categoryName] = {}
    end
    table_insert(registeredSettings[categoryName], settingItems)
end

-- ==============================
-- 파일 레벨 로컬 (정적) 함수 전방 선언 (순서 꼬임 방지)
-- ==============================
local on_enter_edit_mode
local on_exit_edit_mode
local create_system_toggle
local on_checkbox_click

-- ==============================
-- 파일 레벨 로컬 (정적) 함수 - 가비지 프리
-- ==============================
local function sort_setting_sets(a, b)
    if a.hasSetting ~= b.hasSetting then
        return not a.hasSetting
    end
    return a.name < b.name
end

local function panel_on_minimized()
    local panel = EditMode.panel
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
    panel:SetWidth(200)
    panel:SetHeight(64)
    if panel.scrollFrame then
        panel.scrollFrame:Hide()
    end
    dodoDB.editModeMinimized = true
end

local function panel_on_maximized()
    local panel = EditMode.panel
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
    panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
    panel:SetWidth(360)
    if panel.scrollFrame then
        panel.scrollFrame:Show()
    end
    dodoDB.editModeMinimized = false
end

local function update_disabled_states_action()
    local panel = EditMode.panel
    if not panel or not panel.updateQueue then return end

    for _, q in ipairs(panel.updateQueue) do
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
                if q.comp.Title then q.comp.Title:SetTextColor(1, 0.82, 0) end
            else
                q.comp:SetAlpha(0.35)
                if q.comp.Button then q.comp.Button:Disable() end
                if q.comp.Title then q.comp.Title:SetTextColor(0.5, 0.5, 0.5) end
            end
        else
            dodo.UI:SetComponentEnabled(q.comp, enabled)
        end
    end
end

local function panel_on_show(self)
    if dodoDB.editModeMinimized then
        self.maxMinFrame:Minimize(true)
    else
        self.maxMinFrame:Maximize(true)
    end
    update_disabled_states_action()
end

-- ==============================
-- 기능 1 - 편집 모드 모듈 설정 패널 구성
-- ==============================
local function CreateEditModePanel()
    if EditMode.panel then return EditMode.panel end

    local frame = dodo.UI:CreatePortraitPanel("dodoEditModePanel", "dodo 모듈")
    if EditModeManagerFrame then
        frame:SetFrameStrata(EditModeManagerFrame:GetFrameStrata())
        frame:SetFrameLevel(EditModeManagerFrame:GetFrameLevel())
    end
    frame:SetWidth(360)
    frame:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
    frame:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
    frame:Hide()

    EditMode.panel = frame

    local updateQueue = {}
    frame.updateQueue = updateQueue

    -- 와우 순정 편집모드 스타일의 ScrollFrameTemplate 적용
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    scrollFrame.scrollBarHideIfUnscrollable = true
    scrollFrame.scrollBarX = 6
    scrollFrame.scrollBarTopY = -4
    frame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(310, 1)
    scrollFrame:SetScrollChild(scrollChild)

    -- 최소화/최대화 버튼 추가
    local maxMinFrame = CreateFrame("Frame", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
    maxMinFrame:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
    maxMinFrame:SetOnMinimizedCallback(panel_on_minimized)
    maxMinFrame:SetOnMaximizedCallback(panel_on_maximized)
    frame.maxMinFrame = maxMinFrame

    local defaultMenuItems = {
        { isHeader = true, text = "전투" },
        { isHeader = true, text = "인터페이스" },
        { isHeader = true, text = "음성" },
        { isHeader = true, text = "편의기능" },
        { isHeader = true, text = "일반" },
        { isHeader = true, text = "설정 & 프로필" },
    }

    local menuItems = {}
    for _, headerItem in ipairs(defaultMenuItems) do
        table_insert(menuItems, headerItem)
        if headerItem.isHeader then
            local category = headerItem.text
            local groups = registeredSettings[category]
            if groups then
                local flatItems = {}
                for g = 1, #groups do
                    local groupItems = groups[g]
                    for i = 1, #groupItems do
                        table_insert(flatItems, groupItems[i])
                    end
                end

                local sets = {}
                local idx = 1
                while idx <= #flatItems do
                    local item = flatItems[idx]
                    if item.isSpacer then
                        idx = idx + 1
                    else
                        local nextItem = flatItems[idx + 1]
                        if nextItem and (nextItem.type == "dropdown" or nextItem.type == "slider") and (not item.type) then
                            table_insert(sets, {
                                cb = item,
                                setting = nextItem,
                                name = item.name or "",
                                hasSetting = true
                            })
                            idx = idx + 2
                        else
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
                    table_insert(menuItems, set.cb)
                    if set.setting then
                        local cbItem = set.cb
                        local originalDisabled = set.setting.disabled
                        set.setting.disabled = function()
                            if originalDisabled and originalDisabled() then
                                return true
                            end
                            if cbItem then
                                if cbItem.get and not cbItem.get() then
                                    return true
                                end
                                if cbItem.disabled and cbItem.disabled() then
                                    return true
                                end
                            end
                            return false
                        end
                        table_insert(menuItems, set.setting)
                    end
                end
            end
        end
    end

    local startY = -5
    local currentY = startY
    local hasDivider = false
    local col = 0

    for i, item in ipairs(menuItems) do
        if item.isHeader then
            if col == 1 then
                currentY = currentY - 26
                col = 0
            end

            if hasDivider then
                local divider = scrollChild:CreateTexture(nil, "BACKGROUND")
                divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
                divider:SetSize(310, 8)
                divider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, currentY + 12)
                divider:SetAlpha(0.35)
                currentY = currentY - 14
            end

            local titleFrame = CreateFrame("Frame", nil, scrollChild)
            titleFrame:SetSize(310, 24)
            titleFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, currentY)

            local text = titleFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            text:SetPoint("LEFT", titleFrame, "LEFT", 0, 0)
            text:SetText(item.text)

            currentY = currentY - 28
            hasDivider = true
        else
            if item.isSpacer then
                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            elseif item.type == "dropdown" then
                local dd = dodo.UI:CreateDropdown(scrollChild, item.get, item.set, item.values)
                dd:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 165, currentY + 2)

                if item.disabled then
                    table_insert(updateQueue, { comp = dd, type = "dropdown", check = item.disabled })
                end

                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            elseif item.type == "slider" then
                local slider = dodo.UI:CreateSlider(scrollChild, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1)
                slider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 165, currentY - 4)

                if item.disabled then
                    table_insert(updateQueue, { comp = slider, type = "slider", check = item.disabled })
                end

                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end
            elseif item.type == "button" then
                if col == 1 then
                    currentY = currentY - 26
                    col = 0
                end

                local btnFrame = dodo.UI:CreateButton(scrollChild, item.name, item.text or "실행", item.onClick)
                btnFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, currentY)

                if item.disabled then
                    table_insert(updateQueue, { comp = btnFrame, type = "button", check = item.disabled })
                end

                currentY = currentY - 26
            else
                local nextItem = menuItems[i + 1]
                if nextItem and (nextItem.type == "dropdown" or nextItem.type == "slider") then
                    if col == 1 then
                        currentY = currentY - 26
                        col = 0
                    end
                end

                local cb = dodo.UI:CreateCheckbox(scrollChild, item.name, item.get, item.set)
                local posX = (col == 0) and 8 or 165
                cb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", posX, currentY)

                if item.disabled then
                    table_insert(updateQueue, { comp = cb, type = "checkbox", check = item.disabled })
                end

                if col == 0 then
                    col = 1
                else
                    currentY = currentY - 26
                    col = 0
                end
            end
        end
    end

    if col == 1 then
        currentY = currentY - 26
    end

    scrollChild:SetHeight(math_abs(currentY) + 15)
    frame.UpdateDisabledStates = update_disabled_states_action

    frame:HookScript("OnShow", panel_on_show)

    return frame
end

-- ==============================
-- 이벤트 및 콜백 구현 (전방 선언 대응)
-- ==============================
on_enter_edit_mode = function()
    if EditMode.showSystems then
        for _, system in pairs(EditMode.systems) do
            system:HighlightSystem()
            system:Show()
        end
    end
    create_system_toggle()

    local panel = CreateEditModePanel()
    if panel then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", EditModeManagerFrame, "TOPRIGHT", Settings.positionX, Settings.positionY)
        if dodoDB.editModeMinimized then
            panel:SetWidth(200)
            panel:SetHeight(64)
        else
            panel:SetPoint("BOTTOMLEFT", EditModeManagerFrame, "BOTTOMRIGHT", Settings.positionX, -Settings.positionY)
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
end

on_checkbox_click = function(checked)
    EditMode.showSystems = checked
    if checked then
        on_enter_edit_mode()
    else
        on_exit_edit_mode()
    end
end

local function on_checkbox_click_script(self)
    local checked = self:GetChecked()
    on_checkbox_click(checked)
end

create_system_toggle = function()
    if EditMode.systemToggle then return end
    if not EditModeManagerFrame then return end

    local checkBox = CreateFrame("CheckButton", nil, EditModeManagerFrame, "UICheckButtonTemplate")
    checkBox:SetPoint("TOP", EditModeManagerFrame, "TOP", 15, -50)
    if checkBox.Text then
        checkBox.Text:SetText("dodo 모듈 편집")
    end
    checkBox:SetChecked(EditMode.showSystems)
    checkBox:SetScript("OnClick", on_checkbox_click_script)

    EditMode.systemToggle = checkBox
end

local function system_on_drag_start(self)
    self:SetMovable(true)
    self:StartMoving()
end

local function system_on_drag_stop(self)
    self:StopMovingOrSizing()
    local newPoint = { self:GetPoint() }
    if not newPoint[1] then return end

    local systemName = self.systemName
    local newPointData = {
        point = newPoint[1],
        relativeTo = self:GetParent():GetName() or "UIParent",
        relativePoint = newPoint[3],
        xOfs = newPoint[4],
        yOfs = newPoint[5],
    }

    dodoDB.editMode = dodoDB.editMode or {}
    dodoDB.editMode[systemName] = newPointData

    if self.onPositionChanged then
        self.onPositionChanged(newPointData)
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
---@param systemName string 시스템 고유 이름
---@param systemLabel string 편집 모드 상자 위에 뜰 이름표 텍스트
---@param systemTooltip string 마우스 오버 시 보일 툴팁 내용
---@param parentFrame Frame 부모 프레임 (대체로 UIParent)
---@param width number|nil 가로 크기 (기본값: 150)
---@param height number|nil 세로 크기 (기본값: 50)
---@param defaultPoint table|nil 초기 위치 좌표 { point, relativeTo, relativePoint, xOfs, yOfs }
---@param onPositionChanged nil|fun(newPointData: table) 위치 변경 시 호출될 콜백 함수
function EditMode:CreateSystem(systemName, systemLabel, systemTooltip, parentFrame, width, height, defaultPoint, onPositionChanged)
    if self.systems[systemName] then
        return
    end

    local system = CreateFrame("Frame", nil, parentFrame, "EditModeSystemTemplate")
    local selection = CreateFrame("Frame", nil, system, "EditModeSystemSelectionTemplate")
    selection:SetAllPoints()
    
    system:SetSize(width or 150, height or 50)
    system.systemName = systemName
    system.systemLabel = systemLabel
    system.systemTooltip = systemTooltip
    system.onPositionChanged = onPositionChanged

    -- 저장된 좌표 로드 (빈 테이블 예외 차단 후 defaultPoint 보장)
    local savedPoint = dodoDB.editMode and dodoDB.editMode[systemName]
    local point = (savedPoint and savedPoint.point) and savedPoint or defaultPoint or {}
    system:ClearAllPoints()
    system:SetPoint(point.point or "CENTER", point.relativeTo or parentFrame, point.relativePoint or "CENTER", point.xOfs or 0, point.yOfs or 0)

    -- 스크립트 및 메서드 매핑 (정적 함수 활용)
    system:SetScript("OnDragStart", system_on_drag_start)
    system:SetScript("OnDragStop", system_on_drag_stop)
    
    selection.GetLabelText = selection_get_label_text
    
    -- EditModeSystemSelectionTemplate의 내부 툴팁 대응용 프록시 객체
    selection.system = {
        parentFrame = system,
        GetSystemName = system_get_system_name
    }

    system:Hide()
    self.systems[systemName] = system
    
    -- 최초 등록 후 모듈 위치를 DB 좌표에 맞게 1회 강제 동기화
    if onPositionChanged and (dodoDB.editMode and dodoDB.editMode[systemName] or defaultPoint) then
        onPositionChanged(point)
    end
end

---@param systemName string
---@return Frame|nil
function EditMode:GetSystem(systemName)
    return self.systems[systemName]
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
