-- ==============================
-- Inspired
-- ==============================
-- Edit Mode More (https://www.curseforge.com/wow/addons/edit-mode-more)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_Widget = C_Widget
local CreateFrame = CreateFrame
local GetPhysicalScreenSize = GetPhysicalScreenSize
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local UIParent = UIParent
local _G = _G
local math = math
local tonumber = tonumber
local tostring = tostring

-- ==============================
-- 로컬 상태 및 설정
-- ==============================
local selected_frame = nil
local pos_point = nil
local pos_attach_frame = nil
local pos_attach_point = nil
local pos_x_offset = 0
local pos_y_offset = 0
local pos_scale = 1
local pos_frame = nil
local is_pos_active = false
local init_frame = CreateFrame("Frame")
local last_pure_height = 300
local is_updating_height = false

-- ==============================
-- 기능 1: 좌표 및 스케일 변환
-- ==============================
local function to_actual_pixel(value)
    return math.abs(value / pos_scale + 0.5) * (value < 0 and -1 or 1)
end

local function to_rounded_number(text)
    local num = tonumber(text)
    if num == nil then
        return nil
    else
        return math.abs(num + 0.5) * (num < 0 and -1 or 1)
    end
end

local function update_scale()
    local _, height = GetPhysicalScreenSize()
    local uiScale = UIParent:GetScale()
    pos_scale = 768 / uiScale / height
end

-- ==============================
-- 기능 2: 상태 업데이트 및 동기화
-- ==============================
local function update_pos_settings()
    if not selected_frame then return end
    local point, attachFrame, attachPoint, xOffset, yOffset = selected_frame:GetPoint()

    pos_point = point
    pos_attach_frame = attachFrame
    pos_attach_point = attachPoint
    pos_x_offset = xOffset
    pos_y_offset = yOffset

    if pos_frame then
        pos_frame.xOffsetContainer.editBox:SetText(tostring(math.floor(to_actual_pixel(xOffset) + 0.5)))
        pos_frame.yOffsetContainer.editBox:SetText(tostring(math.floor(to_actual_pixel(yOffset) + 0.5)))
        pos_frame.pointContainer.dropdown:GenerateMenu()
        pos_frame.attachFrameContainer.editBox:SetText(attachFrame and attachFrame:GetName() or "")
        pos_frame.attachPointContainer.dropdown:GenerateMenu()
        pos_frame.frameNameContainer.editBox:SetText(selected_frame:GetName() or "")
    end
end

local function disable_pos_settings()
    if not pos_frame then return end
    dodo.UI:SetEditBoxEnabled(pos_frame.xOffsetContainer.editBox, false)
    pos_frame.xOffsetContainer.leftButton:Disable()
    pos_frame.xOffsetContainer.rightButton:Disable()
    dodo.UI:SetEditBoxEnabled(pos_frame.yOffsetContainer.editBox, false)
    pos_frame.yOffsetContainer.downButton:Disable()
    pos_frame.yOffsetContainer.upButton:Disable()
    pos_frame.pointContainer.dropdown:Disable()
    dodo.UI:SetEditBoxEnabled(pos_frame.attachFrameContainer.editBox, false)
    pos_frame.attachPointContainer.dropdown:Disable()
    pos_frame.disabledMessage:Show()
end

local function enable_pos_settings()
    if not pos_frame then return end
    dodo.UI:SetEditBoxEnabled(pos_frame.xOffsetContainer.editBox, true)
    pos_frame.xOffsetContainer.leftButton:Enable()
    pos_frame.xOffsetContainer.rightButton:Enable()
    dodo.UI:SetEditBoxEnabled(pos_frame.yOffsetContainer.editBox, true)
    pos_frame.yOffsetContainer.downButton:Enable()
    pos_frame.yOffsetContainer.upButton:Enable()
    pos_frame.pointContainer.dropdown:Enable()
    dodo.UI:SetEditBoxEnabled(pos_frame.attachFrameContainer.editBox, true)
    pos_frame.attachPointContainer.dropdown:Enable()
    pos_frame.disabledMessage:Hide()
end

local function apply_pos_settings()
    if not selected_frame or not selected_frame:CanBeMoved() then return end

    if selected_frame.isManagedFrame and selected_frame:IsInDefaultPosition() then
        selected_frame:BreakFromFrameManager()
    end

    if selected_frame == PlayerCastingBarFrame then
        EditModeManagerFrame:OnSystemSettingChange(selected_frame, Enum.EditModeCastBarSetting.LockToPlayerFrame, 0);
    end

    selected_frame:ClearFrameSnap()
    selected_frame:StopMovingOrSizing();

    selected_frame:ClearAllPoints()
    selected_frame:SetPoint(pos_point, pos_attach_frame, pos_attach_point, pos_x_offset, pos_y_offset)

    if selected_frame.OnSystemPositionChange then
        selected_frame:OnSystemPositionChange()
    elseif EditModeManagerFrame.OnSystemPositionChange then
        EditModeManagerFrame:OnSystemPositionChange(selected_frame)
    end
end

-- ==============================
-- 기능 3: UI 헬퍼 및 셋업
-- ==============================
local function setup_pos_label(label)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
end



local function setup_pos_point_dropdown(dropdown)
    local function isSelected(index)
        if pos_point == "CENTER" then return index == 0
        elseif pos_point == "TOP" then return index == 1
        elseif pos_point == "BOTTOM" then return index == 2
        elseif pos_point == "LEFT" then return index == 3
        elseif pos_point == "RIGHT" then return index == 4
        elseif pos_point == "TOPLEFT" then return index == 5
        elseif pos_point == "TOPRIGHT" then return index == 6
        elseif pos_point == "BOTTOMLEFT" then return index == 7
        elseif pos_point == "BOTTOMRIGHT" then return index == 8
        end
    end

    local function SetSelected(index)
        if index == 0 then pos_point = "CENTER"
        elseif index == 1 then pos_point = "TOP"
        elseif index == 2 then pos_point = "BOTTOM"
        elseif index == 3 then pos_point = "LEFT"
        elseif index == 4 then pos_point = "RIGHT"
        elseif index == 5 then pos_point = "TOPLEFT"
        elseif index == 6 then pos_point = "TOPRIGHT"
        elseif index == 7 then pos_point = "BOTTOMLEFT"
        elseif index == 8 then pos_point = "BOTTOMRIGHT"
        end
        apply_pos_settings()
    end

    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio("CENTER", isSelected, SetSelected, 0);
        rootDescription:CreateRadio("TOP", isSelected, SetSelected, 1);
        rootDescription:CreateRadio("BOTTOM", isSelected, SetSelected, 2);
        rootDescription:CreateRadio("LEFT", isSelected, SetSelected, 3);
        rootDescription:CreateRadio("RIGHT", isSelected, SetSelected, 4);
        rootDescription:CreateRadio("TOPLEFT", isSelected, SetSelected, 5);
        rootDescription:CreateRadio("TOPRIGHT", isSelected, SetSelected, 6);
        rootDescription:CreateRadio("BOTTOMLEFT", isSelected, SetSelected, 7);
        rootDescription:CreateRadio("BOTTOMRIGHT", isSelected, SetSelected, 8);
    end)
end

local function setup_pos_relative_point_dropdown(dropdown)
    local function isSelected(index)
        if pos_attach_point == "CENTER" then return index == 0
        elseif pos_attach_point == "TOP" then return index == 1
        elseif pos_attach_point == "BOTTOM" then return index == 2
        elseif pos_attach_point == "LEFT" then return index == 3
        elseif pos_attach_point == "RIGHT" then return index == 4
        elseif pos_attach_point == "TOPLEFT" then return index == 5
        elseif pos_attach_point == "TOPRIGHT" then return index == 6
        elseif pos_attach_point == "BOTTOMLEFT" then return index == 7
        elseif pos_attach_point == "BOTTOMRIGHT" then return index == 8
        end
    end

    local function SetSelected(index)
        if index == 0 then pos_attach_point = "CENTER"
        elseif index == 1 then pos_attach_point = "TOP"
        elseif index == 2 then pos_attach_point = "BOTTOM"
        elseif index == 3 then pos_attach_point = "LEFT"
        elseif index == 4 then pos_attach_point = "RIGHT"
        elseif index == 5 then pos_attach_point = "TOPLEFT"
        elseif index == 6 then pos_attach_point = "TOPRIGHT"
        elseif index == 7 then pos_attach_point = "BOTTOMLEFT"
        elseif index == 8 then pos_attach_point = "BOTTOMRIGHT"
        end
        apply_pos_settings()
    end

    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:CreateRadio("CENTER", isSelected, SetSelected, 0);
        rootDescription:CreateRadio("TOP", isSelected, SetSelected, 1);
        rootDescription:CreateRadio("BOTTOM", isSelected, SetSelected, 2);
        rootDescription:CreateRadio("LEFT", isSelected, SetSelected, 3);
        rootDescription:CreateRadio("RIGHT", isSelected, SetSelected, 4);
        rootDescription:CreateRadio("TOPLEFT", isSelected, SetSelected, 5);
        rootDescription:CreateRadio("TOPRIGHT", isSelected, SetSelected, 6);
        rootDescription:CreateRadio("BOTTOMLEFT", isSelected, SetSelected, 7);
        rootDescription:CreateRadio("BOTTOMRIGHT", isSelected, SetSelected, 8);
    end)
end

-- ==============================
-- 기능 4: EMM 스타일 하단 부착 및 고정 계산 공식 적용
-- ==============================
local function update_pos_dialog()
    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    if not EditModeSystemSettingsDialog or not EditModeSystemSettingsDialog:IsShown() then return end
    if not pos_frame or not is_pos_active then return end

    if not selected_frame then
        pos_frame:Hide()
        return
    end

    update_pos_settings()

    if selected_frame.isManagedFrame and selected_frame:IsInDefaultPosition() and pos_attach_frame and pos_attach_frame:GetName() == "UIParentBottomManagedFrameContainer" then
        disable_pos_settings()
    else
        enable_pos_settings()
    end

    -- 순정 Buttons 하단에 꼬리 일체형으로 부착!
    pos_frame:ClearAllPoints()
    pos_frame:SetPoint("TOPLEFT", EditModeSystemSettingsDialog.Buttons, "BOTTOMLEFT", 0, -2)
    pos_frame:Show()

    local emp_height = 16 + 32 * 6
    if pos_frame.disabledMessage:IsShown() then
        emp_height = emp_height + 32
    end
    pos_frame:SetSize(360, emp_height)

    -- 안전 가드 기반 높이 연산 (세부설정 패널이 보이면 그것의 최하단 끝점을 기준으로 동적 높이 연산)
    local lowestFrame = pos_frame
    local systemPanel = _G.dodoEditModeSystemPanel
    if systemPanel and systemPanel:IsShown() then
        lowestFrame = systemPanel
    end

    if EditModeSystemSettingsDialog:GetTop() and lowestFrame:GetBottom() then
        local new_height = EditModeSystemSettingsDialog:GetTop() - lowestFrame:GetBottom() + 20
        if not is_updating_height then
            is_updating_height = true
            EditModeSystemSettingsDialog:SetHeight(new_height)
            is_updating_height = false
        end
    end

    -- 세부설정 패널의 레이아웃도 연쇄적으로 업데이트 유도 (자식 앵커 밀림 및 겹침 방지)
    if systemPanel and systemPanel.UpdateLayout then
        systemPanel:UpdateLayout()
    end
end

local function create_pos_ui()
    if pos_frame then return end

    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    if not EditModeSystemSettingsDialog then return end

    -- 설정창 아래에 일체형으로 붙일 프레임 생성 (부모를 UIParent로 설정하여 물리적 격리, 테두리 확장 버그 방지)
    local frame = CreateFrame("Frame", "dodoEditModePosFrame", UIParent)
    frame:SetFrameStrata(EditModeSystemSettingsDialog:GetFrameStrata())
    frame:SetFrameLevel(EditModeSystemSettingsDialog:GetFrameLevel() + 2)
    pos_frame = frame

    -- divider (구분선)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    divider:SetSize(330, 16)
    frame.divider = divider

    -- x offset (가로 2열 콤팩트 배치 복원)
    local xOffsetContainer = CreateFrame("Frame", nil, frame)
    xOffsetContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -16)
    xOffsetContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -16)
    xOffsetContainer:SetHeight(32)
    frame.xOffsetContainer = xOffsetContainer

    local xOffsetLabel = xOffsetContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(xOffsetLabel)
    xOffsetLabel:SetText("가로 위치 (X)")
    xOffsetLabel:SetPoint("TOPLEFT", xOffsetContainer, "TOPLEFT", 0, 0)
    xOffsetLabel:SetSize(100, 32)
    frame.xOffsetContainer.label = xOffsetLabel

    local xOffsetEditBox
    xOffsetEditBox = dodo.UI:CreateEditBox(
        xOffsetContainer,
        function() return tostring(math.floor(to_actual_pixel(pos_x_offset) + 0.5)) end,
        function(val)
            local offset = to_rounded_number(val)
            if offset == nil then
                xOffsetEditBox:SetText(xOffsetEditBox.old_text or "")
            else
                pos_x_offset = offset * pos_scale
                apply_pos_settings()
            end
        end
    )
    xOffsetEditBox:SetPoint("LEFT", xOffsetLabel, "RIGHT", 10, 0)
    xOffsetEditBox:SetSize(110, 32)
    xOffsetEditBox.Label = xOffsetLabel
    frame.xOffsetContainer.editBox = xOffsetEditBox

    local xOffsetLeftButton = CreateFrame("Button", nil, xOffsetContainer, "UIPanelSquareButton")
    SquareButton_SetIcon(xOffsetLeftButton, "LEFT")
    xOffsetLeftButton:SetPoint("LEFT", xOffsetEditBox, "RIGHT", 10, 0)
    xOffsetLeftButton:SetSize(28, 28)
    xOffsetLeftButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            pos_x_offset = pos_x_offset - 10 * pos_scale
        else
            pos_x_offset = pos_x_offset - pos_scale
        end
        apply_pos_settings()
    end)
    frame.xOffsetContainer.leftButton = xOffsetLeftButton

    local xOffsetRightButton = CreateFrame("Button", nil, xOffsetContainer, "UIPanelSquareButton")
    SquareButton_SetIcon(xOffsetRightButton, "RIGHT")
    xOffsetRightButton:SetPoint("LEFT", xOffsetLeftButton, "RIGHT", 4, 0)
    xOffsetRightButton:SetSize(28, 28)
    xOffsetRightButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            pos_x_offset = pos_x_offset + 10 * pos_scale
        else
            pos_x_offset = pos_x_offset + pos_scale
        end
        apply_pos_settings()
    end)
    frame.xOffsetContainer.rightButton = xOffsetRightButton

    -- y offset
    local yOffsetContainer = CreateFrame("Frame", nil, frame)
    yOffsetContainer:SetPoint("TOPLEFT", xOffsetContainer, "BOTTOMLEFT", 0, 0)
    yOffsetContainer:SetPoint("TOPRIGHT", xOffsetContainer, "BOTTOMRIGHT", 0, 0)
    yOffsetContainer:SetHeight(32)
    frame.yOffsetContainer = yOffsetContainer

    local yOffsetLabel = yOffsetContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(yOffsetLabel)
    yOffsetLabel:SetText("세로 위치 (Y)")
    yOffsetLabel:SetPoint("TOPLEFT", yOffsetContainer, "TOPLEFT", 0, 0)
    yOffsetLabel:SetSize(100, 32)
    frame.yOffsetContainer.label = yOffsetLabel

    local yOffsetEditBox
    yOffsetEditBox = dodo.UI:CreateEditBox(
        yOffsetContainer,
        function() return tostring(math.floor(to_actual_pixel(pos_y_offset) + 0.5)) end,
        function(val)
            local offset = to_rounded_number(val)
            if offset == nil then
                yOffsetEditBox:SetText(yOffsetEditBox.old_text or "")
            else
                pos_y_offset = offset * pos_scale
                apply_pos_settings()
            end
        end
    )
    yOffsetEditBox:SetPoint("LEFT", yOffsetLabel, "RIGHT", 10, 0)
    yOffsetEditBox:SetSize(110, 32)
    yOffsetEditBox.Label = yOffsetLabel
    frame.yOffsetContainer.editBox = yOffsetEditBox

    local yOffsetDownButton = CreateFrame("Button", nil, yOffsetContainer, "UIPanelSquareButton")
    SquareButton_SetIcon(yOffsetDownButton, "DOWN")
    yOffsetDownButton:SetPoint("LEFT", yOffsetEditBox, "RIGHT", 10, 0)
    yOffsetDownButton:SetSize(28, 28)
    yOffsetDownButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            pos_y_offset = pos_y_offset - 10 * pos_scale
        else
            pos_y_offset = pos_y_offset - pos_scale
        end
        apply_pos_settings()
    end)
    frame.yOffsetContainer.downButton = yOffsetDownButton

    local yOffsetUpButton = CreateFrame("Button", nil, yOffsetContainer, "UIPanelSquareButton")
    SquareButton_SetIcon(yOffsetUpButton, "UP")
    yOffsetUpButton:SetPoint("LEFT", yOffsetDownButton, "RIGHT", 4, 0)
    yOffsetUpButton:SetSize(28, 28)
    yOffsetUpButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            pos_y_offset = pos_y_offset + 10 * pos_scale
        else
            pos_y_offset = pos_y_offset + pos_scale
        end
        apply_pos_settings()
    end)
    frame.yOffsetContainer.upButton = yOffsetUpButton

    -- point
    local pointContainer = CreateFrame("Frame", nil, frame)
    pointContainer:SetPoint("TOPLEFT", yOffsetContainer, "BOTTOMLEFT", 0, 0)
    pointContainer:SetPoint("TOPRIGHT", yOffsetContainer, "BOTTOMRIGHT", 0, 0)
    pointContainer:SetHeight(32)
    frame.pointContainer = pointContainer

    local pointLabel = pointContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(pointLabel)
    pointLabel:SetText("기준점")
    pointLabel:SetPoint("TOPLEFT", pointContainer, "TOPLEFT", 0, 0)
    pointLabel:SetSize(100, 32)
    frame.pointContainer.label = pointLabel

    local pointDropdown = CreateFrame("DropdownButton", nil, pointContainer, "WowStyle1DropdownTemplate")
    setup_pos_point_dropdown(pointDropdown)
    pointDropdown:SetPoint("LEFT", pointLabel, "RIGHT", 5, 0)
    pointDropdown:SetSize(225, 26)
    frame.pointContainer.dropdown = pointDropdown

    -- attach frame
    local attachFrameContainer = CreateFrame("Frame", nil, frame)
    attachFrameContainer:SetPoint("TOPLEFT", pointContainer, "BOTTOMLEFT", 0, 0)
    attachFrameContainer:SetPoint("TOPRIGHT", pointContainer, "BOTTOMRIGHT", 0, 0)
    attachFrameContainer:SetHeight(32)
    frame.attachFrameContainer = attachFrameContainer

    local attachFrameLabel = attachFrameContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(attachFrameLabel)
    attachFrameLabel:SetText("부착 대상")
    attachFrameLabel:SetPoint("TOPLEFT", attachFrameContainer, "TOPLEFT", 0, 0)
    attachFrameLabel:SetSize(100, 32)
    frame.attachFrameContainer.label = attachFrameLabel

    local attachFrameEditBox
    attachFrameEditBox = dodo.UI:CreateEditBox(
        attachFrameContainer,
        function() return pos_attach_frame and pos_attach_frame:GetName() or "" end,
        function(val)
            if _G[val] ~= nil and C_Widget.IsFrameWidget(_G[val]) then
                pos_attach_frame = _G[val]
                apply_pos_settings()
            else
                attachFrameEditBox:SetText(attachFrameEditBox.old_text or "")
            end
        end
    )
    attachFrameEditBox:SetPoint("LEFT", attachFrameLabel, "RIGHT", 10, 0)
    attachFrameEditBox:SetSize(220, 32)
    attachFrameEditBox.Label = attachFrameLabel
    frame.attachFrameContainer.editBox = attachFrameEditBox

    -- attach point
    local attachPointContainer = CreateFrame("Frame", nil, frame)
    attachPointContainer:SetPoint("TOPLEFT", attachFrameContainer, "BOTTOMLEFT", 0, 0)
    attachPointContainer:SetPoint("TOPRIGHT", attachFrameContainer, "BOTTOMRIGHT", 0, 0)
    attachPointContainer:SetHeight(32)
    frame.attachPointContainer = attachPointContainer

    local attachPointLabel = attachPointContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(attachPointLabel)
    attachPointLabel:SetText("부착 기준점")
    attachPointLabel:SetPoint("TOPLEFT", attachPointContainer, "TOPLEFT", 0, 0)
    attachPointLabel:SetSize(100, 32)
    frame.attachPointContainer.label = attachPointLabel

    local attachPointDropdown = CreateFrame("DropdownButton", nil, attachPointContainer, "WowStyle1DropdownTemplate")
    setup_pos_relative_point_dropdown(attachPointDropdown)
    attachPointDropdown:SetPoint("LEFT", attachPointLabel, "RIGHT", 5, 0)
    attachPointDropdown:SetSize(225, 26)
    frame.attachPointContainer.dropdown = attachPointDropdown

    -- frame name
    local frameNameContainer = CreateFrame("Frame", nil, frame)
    frameNameContainer:SetPoint("TOPLEFT", attachPointContainer, "BOTTOMLEFT", 0, 0)
    frameNameContainer:SetPoint("TOPRIGHT", attachPointContainer, "BOTTOMRIGHT", 0, 0)
    frameNameContainer:SetHeight(32)
    frame.frameNameContainer = frameNameContainer

    local frameNameLabel = frameNameContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    setup_pos_label(frameNameLabel)
    frameNameLabel:SetText("프레임 이름")
    frameNameLabel:SetPoint("TOPLEFT", frameNameContainer, "TOPLEFT", 0, 0)
    frameNameLabel:SetSize(100, 32)
    frame.frameNameContainer.label = frameNameLabel

    local frameNameEditBox
    frameNameEditBox = dodo.UI:CreateEditBox(
        frameNameContainer,
        function() return selected_frame and selected_frame:GetName() or "" end,
        nil,
        nil,
        true
    )
    frameNameEditBox:SetPoint("LEFT", frameNameLabel, "RIGHT", 10, 0)
    frameNameEditBox:SetSize(220, 32)
    frameNameEditBox.Label = frameNameLabel
    frame.frameNameContainer.editBox = frameNameEditBox

    -- disabled message
    local disabledMessage = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    disabledMessage:SetText("** 드래그하여 고정 해제 **")
    disabledMessage:SetTextColor(1, 0, 0)
    disabledMessage:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    disabledMessage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    disabledMessage:SetHeight(32)
    disabledMessage:Hide()
    frame.disabledMessage = disabledMessage

    frame:Hide()
end

local function update_pos_visual()
    local isEnabled = (dodoDB and dodoDB.enableEditModePos ~= false)
    is_pos_active = isEnabled

    if isEnabled then
        update_scale()
        create_pos_ui()
        if init_frame then
            init_frame:RegisterEvent("UI_SCALE_CHANGED")
        end
        if pos_frame and _G.EditModeSystemSettingsDialog and _G.EditModeSystemSettingsDialog:IsShown() then
            pos_frame:Show()
            update_pos_dialog()
        end
    else
        if init_frame then
            init_frame:UnregisterEvent("UI_SCALE_CHANGED")
        end
        if pos_frame then
            pos_frame:Hide()
        end
        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog:IsShown() then
            local systemPanel = _G.dodoEditModeSystemPanel
            if systemPanel and systemPanel:IsShown() and systemPanel.UpdateLayout then
                systemPanel:UpdateLayout()
            else
                local base_height = _G.dodo_original_dialog_height
                if base_height then
                    EditModeSystemSettingsDialog:SetHeight(base_height)
                end
            end
        end
    end
end

-- ==============================
-- 기능 5: 순정 훅 지점 정의
-- ==============================
local function on_dialog_hide()
    if not is_pos_active then return end
    if pos_frame then pos_frame:Hide() end
end

local function on_dialog_update()
    if not is_pos_active then return end
    update_pos_dialog()
end

local function on_select_system(sm, systemFrame)
    if not is_pos_active then return end
    selected_frame = systemFrame
    update_pos_dialog()
end

function dodo.EditMode.SelectPosFrame(frame)
    if not is_pos_active then return end
    selected_frame = frame
    update_pos_dialog()
end

local function on_clear_system()
    if not is_pos_active then return end
    selected_frame = nil
    if pos_frame then pos_frame:Hide() end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEditModePos == nil then
            dodoDB.enableEditModePos = true
        end

        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if EditModeSystemSettingsDialog then
            EditModeSystemSettingsDialog:HookScript("OnHide", on_dialog_hide)
            hooksecurefunc(EditModeSystemSettingsDialog, "UpdateDialog", on_dialog_update)
            EditModeSystemSettingsDialog:HookScript("OnShow", on_dialog_update)
        end

        local EditModeManagerFrame = _G.EditModeManagerFrame
        if EditModeManagerFrame then
            hooksecurefunc(EditModeManagerFrame, "SelectSystem", on_select_system)
            hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", on_clear_system)
        end

        hooksecurefunc(UIParent, "SetScale", function()
            if is_pos_active then
                update_scale()
                update_pos_dialog()
            end
        end)

        update_pos_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "UI_SCALE_CHANGED" then
        if is_pos_active then
            update_scale()
            update_pos_dialog()
        end
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
        {
            name = "편집모드 세부조정",
            get = function() return dodoDB and dodoDB.enableEditModePos ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableEditModePos = checked end
                update_pos_visual()
            end
        }
    })
end
