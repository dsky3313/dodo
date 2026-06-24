-- ==============================
-- 편집 모드 세부 설정 (EditModeSystemSettingsDialog 훅 + 날개 패널)
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local EditMode = dodo.EditMode

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame    = CreateFrame
local hooksecurefunc = hooksecurefunc
local ipairs         = ipairs
local math_abs       = math.abs
local pairs          = pairs
local table_insert   = table.insert
local type           = type
local UIParent       = UIParent

-- ==============================
-- 로컬 상태
-- ==============================
local system_settings      = {}
local system_wing_panel    = nil
local original_dialog_height = nil

-- ==============================
-- 동적 설정 등록 API (SystemSettings.lua가 로드되면 오버라이드됨)
-- ==============================
---@param systemID number 블리자드 순정 EditModeSystem Enum ID
---@param settingItems table 설정 컴포넌트 데이터 목록
function dodo.RegisterEditModeSystemSetting(systemID, settingItems)
    if not system_settings[systemID] then
        system_settings[systemID] = {}
    end
    table_insert(system_settings[systemID], settingItems)
end

-- ==============================
-- 날개 패널 비활성 상태 갱신
-- ==============================
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

-- ==============================
-- 다이얼로그-날개 패널 레이아웃 동기화
-- ==============================
local function update_dialog_layout()
    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    if not EditModeSystemSettingsDialog or not EditModeSystemSettingsDialog:IsShown() then return end
    if not system_wing_panel or not system_wing_panel:IsShown() then return end

    if type(system_wing_panel.systemID) == "number" then
        system_wing_panel:ClearAllPoints()
        system_wing_panel:SetPoint("TOPRIGHT", EditModeSystemSettingsDialog, "TOPLEFT", -10, 0)
    end
end

-- ==============================
-- 날개 패널 생성
-- ==============================
local function create_system_wing_panel(systemID)
    if system_wing_panel then
        system_wing_panel:Hide()
        system_wing_panel = nil
    end

    local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
    local isPureSystem = (type(systemID) == "number")

    local f = CreateFrame("Frame", "dodoEditModeSystemPanel", UIParent, "BackdropTemplate")

    if EditModeSystemSettingsDialog then
        f:SetFrameStrata(EditModeSystemSettingsDialog:GetFrameStrata())
        f:SetFrameLevel(EditModeSystemSettingsDialog:GetFrameLevel() + 5)
    else
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(210)
    end

    local NineSliceUtil = NineSliceUtil or _G.NineSliceUtil
    if NineSliceUtil then
        NineSliceUtil.ApplyLayoutByName(f, "Dialog")
    end

    f.Bg = f:CreateTexture(nil, "BACKGROUND")
    f.Bg:SetPoint("TOPLEFT", 8, -8)
    f.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
    f.Bg:SetAtlas("UI-DialogBox-Background-Dark")
    f.Bg:SetAlpha(0.85)

    f:SetWidth(260)

    local update_queue = {}
    f.update_queue = update_queue

    local groups = system_settings[systemID]
    local flat_items = {}
    if groups then
        for g = 1, #groups do
            local group_items = groups[g]
            for i = 1, #group_items do
                table_insert(flat_items, group_items[i])
            end
        end
    end

    local menu_items = {}
    local idx = 1
    while idx <= #flat_items do
        local item = flat_items[idx]
        local next_item = flat_items[idx + 1]
        if next_item and (next_item.type == "dropdown" or next_item.type == "slider") and (not item.type) and (not next_item.preventJoin) then
            item.isJoined = true
            next_item.isJoined = true

            local original_disabled = next_item.disabled
            next_item.disabled = function()
                if original_disabled and original_disabled() then return true end
                if item.get and not item.get() then return true end
                if item.disabled and item.disabled() then return true end
                return false
            end

            table_insert(menu_items, item)
            table_insert(menu_items, next_item)
            idx = idx + 2
        else
            item.isJoined = false
            table_insert(menu_items, item)
            idx = idx + 1
        end
    end

    local current_y = -15
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -12)

    if type(systemID) == "string" then
        title:SetText(systemID .. " 세부 설정")
        current_y = -32
    else
        title:SetText("")
        current_y = -15
    end

    for _, item in ipairs(menu_items) do
        if item.type == "dropdown" then
            if item.isJoined then
                local dd = dodo.UI:CreateDropdown(f, item.get, item.set, item.values, nil)
                dd:SetPoint("TOPLEFT", f, "TOPLEFT", 30, current_y - 2)
                if item.disabled then
                    table_insert(update_queue, { comp = dd, type = "dropdown", check = item.disabled })
                end
                current_y = current_y - 28
            else
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
            end
        elseif item.type == "slider" then
            if item.isJoined then
                local slider = dodo.UI:CreateSlider(f, item.get, item.set, item.minVal or 0, item.maxVal or 100, item.step or 1, nil)
                slider:SetPoint("TOPLEFT", f, "TOPLEFT", 30, current_y - 4)
                if item.disabled then
                    table_insert(update_queue, { comp = slider, type = "slider", check = item.disabled })
                end
                current_y = current_y - 28
            else
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
            end
        else
            local cb = dodo.UI:CreateCheckbox(f, item.name, item.get, item.set)
            cb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, current_y)
            if item.disabled then
                table_insert(update_queue, { comp = cb, type = "checkbox", check = item.disabled })
            end
            current_y = current_y - 26
        end
    end

    f:SetHeight(math_abs(current_y) + 15)
    f.systemID = systemID
    f.UpdateDisabledStates = update_system_disabled_states
    system_wing_panel = f
    update_system_disabled_states()

    return f
end

-- on_exit_edit_mode에서 호출 가능하도록 노출
function EditMode.HideSystemWingPanel()
    if system_wing_panel then system_wing_panel:Hide() end
end

-- ==============================
-- 초기화
-- ==============================
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

        hooksecurefunc(EditModeSystemSettingsDialog, "AttachToSystemFrame", function(self, systemFrame)
            if not systemFrame._isDodoSystem then
                self.OnSettingValueChanged = nil
                self._dodo_callbacks = nil
                for _, sys in pairs(EditMode.systems or {}) do
                    sys:HighlightSystem()
                end
            else
                if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
                    for _, sf in ipairs(EditModeManagerFrame.registeredSystemFrames) do
                        if sf.isSelected and sf.Selection then
                            sf.Selection:ShowHighlighted()
                            sf.isSelected = false
                        end
                    end
                end
            end
        end)

        hooksecurefunc(EditModeSystemSettingsDialog, "UpdateSettings", function(self, systemFrame)
            if not systemFrame or not systemFrame._isDodoSystem then return end

            local sname = systemFrame.system
            local groups = EditMode.systemSettings and EditMode.systemSettings[sname]
            if not groups then return end

            local callbacks = {}
            self._dodo_callbacks = callbacks
            self.OnSettingValueChanged = function(dlg, setting, value)
                if callbacks[setting] then callbacks[setting](value) end
            end

            local flat = {}
            for g = 1, #groups do
                local grp = groups[g]
                for i = 1, #grp do table_insert(flat, grp[i]) end
            end

            local slider_pool = self.pools:GetPool("EditModeSettingSliderTemplate")
            local idx = 1
            for _, item in ipairs(flat) do
                if item.type == "slider" then
                    local frame = slider_pool:Acquire()
                    local key = idx
                    idx = idx + 1
                    frame.layoutIndex = key
                    callbacks[key] = item.set
                    frame:SetupSetting({
                        displayInfo = {
                            setting  = key,
                            minValue = item.minVal or 0,
                            maxValue = item.maxVal or 100,
                            stepSize = item.step or 1,
                        },
                        currentValue = item.get(),
                        settingName  = item.name or "",
                    })
                    frame:SetPoint("TOPLEFT")
                    frame:Show()
                end
            end

            self.Buttons:ClearAllPoints()
            self.Buttons:SetPoint("TOPLEFT", self.Settings, "BOTTOMLEFT", 0, -12)
            self.Settings:Show()
            self.Settings:Layout()
        end)

        hooksecurefunc(EditModeSystemSettingsDialog, "UpdateButtons", function(self)
            if not self.attachedToSystem then return end
            if not self.attachedToSystem._isDodoSystem then return end
            local sys = self.attachedToSystem
            self.Buttons.RevertChangesButton:SetShown(true)
            self.Buttons.RevertChangesButton:SetOnClickHandler(function()
                if not sys._original_point then return end
                local op = sys._original_point
                local ref = _G[op.relativeTo] or UIParent
                sys:ClearAllPoints()
                sys:SetPoint(op.point or "CENTER", ref, op.relativePoint or "CENTER", op.xOfs or 0, op.yOfs or 0)
                dodoDB.editMode = dodoDB.editMode or {}
                dodoDB.editMode[sys.systemName] = op
                sys._has_active_changes = false
                if sys.onPositionChanged then sys.onPositionChanged(op) end
                self:UpdateDialog(sys)
            end)
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
            if not EditMode.showSystems then
                if system_wing_panel then system_wing_panel:Hide() end
                return
            end

            local systemID = systemFrame.system
            if type(systemID) == "table" and systemID.parentFrame then
                return
            end

            for _, sys in pairs(EditMode.systems or {}) do
                sys:HighlightSystem()
            end

            if system_settings[systemID] then
                local panel = create_system_wing_panel(systemID)
                panel:Show()
                update_dialog_layout()
            else
                if system_wing_panel then system_wing_panel:Hide() end
            end
        end)
    end
    self:UnregisterAllEvents()
end)
