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
local EditMode = dodo.EditMode
if not EditMode then return end

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local EditModeManagerFrame = EditModeManagerFrame
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math_abs = math.abs
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort
local type = type
local UIParent = UIParent
local _G = _G

-- ==============================
-- 기능 2 - 편집 모드 세부 설정
-- ==============================
local system_wing_panel = nil
local original_dialog_height = nil

---@param systemID number 블리자드 순정 EditModeSystem Enum ID
---@param settingItems table 설정 컴포넌트 데이터 목록
function dodo.RegisterEditModeSystemSetting(systemID, settingItems)
    -- 로딩 순서 무관 절대 방어 가드 (Lazy Initialization)
    dodo.EditMode = dodo.EditMode or {}
    EditMode = dodo.EditMode
    EditMode.systemSettings = EditMode.systemSettings or {}

    if not EditMode.systemSettings[systemID] then
        EditMode.systemSettings[systemID] = {}
    end
    table_insert(EditMode.systemSettings[systemID], settingItems)
end

local function sort_setting_sets(a, b)
    if a.hasSetting ~= b.hasSetting then
        return not a.hasSetting
    end
    return a.name < b.name
end

local function update_system_disabled_states()
    if not system_wing_panel or not system_wing_panel.update_queue then return end
    for _, q in ipairs(system_wing_panel.update_queue) do
        local disabled = q.check()
        local enabled = not disabled
        if q.type == "slider" then
            dodo.UI:SetSliderEnabled(q.comp, enabled)
        elseif q.type == "dropdown" then
            dodo.UI:SetDropdownEnabled(q.comp, enabled)
        else
            dodo.UI:SetComponentEnabled(q.comp, enabled)
        end
    end
end

local function update_dialog_layout()
    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    if not EditModeSystemSettingsDialog or not EditModeSystemSettingsDialog:IsShown() then return end
    if not system_wing_panel or not system_wing_panel:IsShown() then return end

    if type(system_wing_panel.systemID) == "number" or (type(system_wing_panel.systemID) == "string" and system_wing_panel.systemID:match("^%d+_%d+$")) then
        -- 앵커 대상 결정: EditModePos 패널(dodoEditModePosFrame)이 켜져 있으면 그 하단에 부착, 없으면 Buttons 하단에 부착
        local anchorFrame = EditModeSystemSettingsDialog.Buttons
        local EditModePosFrame = _G.dodoEditModePosFrame
        if EditModePosFrame and EditModePosFrame:IsShown() then
            anchorFrame = EditModePosFrame
        end

        system_wing_panel:ClearAllPoints()
        system_wing_panel:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
        
        -- 동적 높이 연계 조정
        if EditModeSystemSettingsDialog:GetTop() and system_wing_panel:GetBottom() then
            local new_height = EditModeSystemSettingsDialog:GetTop() - system_wing_panel:GetBottom() + 20
            EditModeSystemSettingsDialog:SetHeight(new_height)
        end
    end
end

local function create_system_wing_panel(systemID)
    if system_wing_panel then
        system_wing_panel:Hide()
        system_wing_panel = nil
    end

    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    local isPureSystem = (type(systemID) == "number" or (type(systemID) == "string" and systemID:match("^%d+_%d+$")))
    
    -- 물리적 격리: 부모를 항상 UIParent로 지정하여 자식 프레임 팽창으로 인한 다이얼로그 테두리 버그 차단
    local f = CreateFrame("Frame", "dodoEditModeSystemPanel", UIParent, "BackdropTemplate")
    
    if isPureSystem and EditModeSystemSettingsDialog then
        f:SetFrameStrata(EditModeSystemSettingsDialog:GetFrameStrata())
        f:SetFrameLevel(EditModeSystemSettingsDialog:GetFrameLevel() + 5)
    else
        local EditModeManagerFrame = _G.EditModeManagerFrame
        if EditModeManagerFrame then
            local mainPanel = _G.dodoEditModePanel
            if mainPanel then
                f:SetFrameStrata(mainPanel:GetFrameStrata())
                f:SetFrameLevel(mainPanel:GetFrameLevel() + 5)
            else
                f:SetFrameStrata("HIGH")
                f:SetFrameLevel(EditModeManagerFrame:GetFrameLevel() + 5)
            end
        end
    end

    if isPureSystem and EditModeSystemSettingsDialog then
        f:SetFrameStrata(EditModeSystemSettingsDialog:GetFrameStrata())
        f:SetFrameLevel(EditModeSystemSettingsDialog:GetFrameLevel() + 5)
        
        -- 하단 일체형 구분선 추가
        f.divider = f:CreateTexture(nil, "ARTWORK")
        f.divider:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-OnlineDivider")
        f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.divider:SetSize(330, 16)
    else
        -- 커스텀 시스템(날개형으로 뜨는 경우)은 기존 날개형 스킨 보존
        local NineSliceUtil = NineSliceUtil or _G.NineSliceUtil
        if NineSliceUtil then
            NineSliceUtil.ApplyLayoutByName(f, "Dialog")
        end

        f.Bg = f:CreateTexture(nil, "BACKGROUND")
        f.Bg:SetPoint("TOPLEFT", 8, -8)
        f.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
        f.Bg:SetAtlas("UI-DialogBox-Background-Dark")
        f.Bg:SetAlpha(0.85)
    end

    f:SetWidth(isPureSystem and 360 or 260)
    
    local update_queue = {}
    f.update_queue = update_queue

    local groups = EditMode.systemSettings[systemID]
    local flat_items = {}
    if groups then
        for g = 1, #groups do
            local group_items = groups[g]
            for i = 1, #group_items do
                table_insert(flat_items, group_items[i])
            end
        end
    end

    -- 윙 패널 결합(isJoined) 식별 및 글자순 정렬 전처리
    local sets = {}
    local idx = 1
    while idx <= #flat_items do
        local item = flat_items[idx]
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

    -- 글자순 정렬 실행 (table.sort)
    table_sort(sets, sort_setting_sets)

    -- 정렬된 순서대로 최종 menu_items에 조립 주입
    local menu_items = {}
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

    -- 상단 텍스트 및 시작 Y 좌표 설정
    local current_y = isPureSystem and -16 or -15
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -12)

    if type(systemID) == "string" and not isPureSystem then
        title:SetText(systemID .. " 세부 설정")
        current_y = -32
    else
        title:SetText("")
        current_y = isPureSystem and -16 or -15
    end

    local col = 0

    -- 세로 2열 컴포넌트 배치 (결합된 슬라이더/드롭다운은 이전 체크박스 우측 2열에 배치)
    for i, item in ipairs(menu_items) do
        if item.type == "dropdown" then
            if item.isJoined then
                -- 결합 드롭다운: 이전 체크박스 바로 옆(X=165)에 2열에 나란히 배치
                local dd = dodo.UI:CreateDropdown(f, item.get, item.set, item.values, nil)
                dd:SetPoint("TOPLEFT", f, "TOPLEFT", 165, current_y - 2)
                if item.disabled then
                    table_insert(update_queue, { comp = dd, type = "dropdown", check = item.disabled })
                end
                current_y = current_y - 28
                col = 0
            else
                -- 단독 드롭다운: 만약 2열째에 걸쳐 있으면 강제 줄바꿈
                if col == 1 then
                    current_y = current_y - 26
                    col = 0
                end
                local dd = dodo.UI:CreateDropdown(f, item.get, item.set, item.values, item.name)
                if dd.Label then
                    dd.Label:ClearAllPoints()
                    dd.Label:SetPoint("TOPLEFT", f, "TOPLEFT", 12, current_y)
                    current_y = current_y - 14
                end
                dd:SetPoint("TOPLEFT", f, "TOPLEFT", 12, current_y - 6)
                if item.disabled then
                    table_insert(update_queue, { comp = dd, type = "dropdown", check = item.disabled })
                end
                current_y = current_y - 28
                col = 0
            end
        elseif item.type == "slider" then
            if item.isJoined then
                -- 결합 슬라이더: 이전 체크박스 바로 옆(X=175)에 2열에 배치
                local slider = dodo.UI:CreateSlider(f, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1, nil)
                slider:SetPoint("TOPLEFT", f, "TOPLEFT", 175, current_y - 4)
                if item.disabled then
                    table_insert(update_queue, { comp = slider, type = "slider", check = item.disabled })
                end
                current_y = current_y - 28
                col = 0
            else
                -- 단독 슬라이더: 만약 2열째에 걸쳐 있으면 강제 줄바꿈
                if col == 1 then
                    current_y = current_y - 26
                    col = 0
                end
                local slider = dodo.UI:CreateSlider(f, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1, item.name)
                if slider.Label then
                    slider.Label:ClearAllPoints()
                    slider.Label:SetPoint("TOPLEFT", f, "TOPLEFT", 12, current_y)
                    current_y = current_y - 14
                end
                slider:SetPoint("TOPLEFT", f, "TOPLEFT", 12, current_y - 6)
                if item.disabled then
                    table_insert(update_queue, { comp = slider, type = "slider", check = item.disabled })
                end
                current_y = current_y - 28
                col = 0
            end
        else -- checkbox
            if item.isJoined and col == 1 then
                current_y = current_y - 26
                col = 0
            end

            local cb = dodo.UI:CreateCheckbox(f, item.name, item.get, item.set)
            local pos_x = (col == 0) and 0 or 165
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", pos_x, current_y)
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

    if col == 1 then
        current_y = current_y - 26
    end

    f:SetHeight(math_abs(current_y) + 15)
    f.systemID = systemID
    f.UpdateDisabledStates = update_system_disabled_states
    f.UpdateLayout = update_dialog_layout
    system_wing_panel = f
    update_system_disabled_states()

    return f
end

-- 외부 바인딩 노출
EditMode.CreateSystemWingPanel = create_system_wing_panel

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    if EditModeSystemSettingsDialog then
        EditModeSystemSettingsDialog:HookScript("OnHide", function()
            original_dialog_height = nil
            _G.dodo_original_dialog_height = nil
            if EditMode.customPanelActive then return end
            if system_wing_panel then system_wing_panel:Hide() end
        end)
        
        hooksecurefunc(EditModeSystemSettingsDialog, "UpdateDialog", update_dialog_layout)
        EditModeSystemSettingsDialog:HookScript("OnShow", function()
            local h = EditModeSystemSettingsDialog:GetHeight()
            original_dialog_height = h
            _G.dodo_original_dialog_height = h
            update_dialog_layout()
        end)
    end

    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(sm, systemFrame)
            -- 모듈 편집 모드가 완전히 꺼져 있다면 작동 차단 및 세부설정창 가림
            if not EditMode.showSystems then
                if system_wing_panel then system_wing_panel:Hide() end
                return
            end

            local systemID = systemFrame.system
            local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
            local Enum_EditModeUnitFrameSystem_Raid = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
            local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

            if systemFrame == _G.CompactRaidFrameContainer then
                systemID = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)
            elseif systemFrame == _G.PartyFrame then
                systemID = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)
            elseif systemID == Enum_EditModeSystem_UnitFrame and systemFrame.systemIndex then
                systemID = string.format("%d_%d", systemID, systemFrame.systemIndex)
            end
            -- dodo 커스텀 프레임은 OnMouseDown에서 직접 처리하므로 여기서 무시
            if type(systemID) == "table" and systemID.parentFrame then
                return
            end

            if EditMode.systemSettings[systemID] then
                local panel = create_system_wing_panel(systemID)
                panel:Show()
                update_dialog_layout()
            else
                if system_wing_panel then system_wing_panel:Hide() end
            end
        end)

        -- dodo 모듈 편집 해제 시 세부설정창도 완벽히 동시 은닉
        EventRegistry:RegisterCallback("EditMode.Exit", function()
            if system_wing_panel then system_wing_panel:Hide() end
        end)
    end
    self:UnregisterAllEvents()
end)
