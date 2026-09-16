-- ==============================
-- LibEditMode 연동 — CreateSystem / GetSystem
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local EditMode = dodo.EditMode

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- LibEditMode
-- ==============================
local LEM

---@param system_name string 시스템 고유 이름
---@param system_label string 편집 모드 상자 위에 뜰 이름표 텍스트
---@param system_tooltip string 마우스 오버 시 보일 툴팁 내용
---@param parent_frame Frame 부모 프레임 (대체로 UIParent)
---@param width number|nil 가로 크기 (기본값: 150)
---@param height number|nil 세로 크기 (기본값: 50)
---@param default_point table|nil 초기 위치 좌표 { point, relativeTo, relativePoint, xOfs, yOfs }
---@param on_position_changed nil|fun(new_point_data: table) 위치 변경 시 호출될 콜백 함수
function EditMode:CreateSystem(system_name, system_label, system_tooltip, parent_frame, width, height, default_point, on_position_changed, check_active_func)
    if self.systems[system_name] then return end

    local system = CreateFrame("Frame", "dodoEditMode" .. system_name, parent_frame)
    ---@cast system EditModeSystemFrame
    system:SetSize(width or 150, height or 50)
    system.systemName        = system_name
    system.systemLabel       = system_label
    system.systemTooltip     = system_tooltip
    system.onPositionChanged = on_position_changed
    system.checkActiveFunc   = check_active_func
    system.defaultPoint      = default_point
    system._isDodoSystem     = true

    -- 저장된 좌표 로드
    local saved_point = dodoDB.editMode and dodoDB.editMode[system_name]
    local point = (saved_point and saved_point.point) and saved_point or default_point or {}
    system:ClearAllPoints()
    system:SetPoint(
        point.point or "CENTER",
        point.relativeTo or parent_frame,
        point.relativePoint or point.point or "CENTER",
        point.xOfs or 0,
        point.yOfs or 0
    )

    -- LibEditMode 등록 (selection/드래그/다이얼로그 자동 처리)
    LEM:AddFrame(system, function(frame, layoutName, pt, x, y)
        local save = {
            point         = pt,
            relativeTo    = "UIParent",
            relativePoint = pt,
            xOfs          = x,
            yOfs          = y,
        }
        dodoDB.editMode = dodoDB.editMode or {}
        dodoDB.editMode[system_name] = save
        if on_position_changed then on_position_changed(save) end
    end, {
        point = (default_point and default_point.point) or "CENTER",
        x     = (default_point and default_point.xOfs) or 0,
        y     = (default_point and default_point.yOfs) or 0,
    }, system_name)

    local lem_selection = LEM.frameSelections and LEM.frameSelections[system]
    system.HighlightSystem = function(s)
        if lem_selection then lem_selection:ShowHighlighted() end
    end
    system.ClearHighlight = function(s)
        if lem_selection then lem_selection:Hide() end
    end
    system.GetSystemName = function(s) return s.systemLabel or "" end
    system.GetSettings   = function(s) return {} end
    system.HasSettings   = function(s) return false end

    -- Position 모듈 연동: 위치 변경 시 dodoDB 직접 저장
    system.SavePosition = function(s)
        local pt, attachFrame, attachPoint, x, y = s:GetPoint()
        local relName = attachFrame and (attachFrame:GetName() or "UIParent") or "UIParent"
        local save = {
            point         = pt,
            relativeTo    = relName,
            relativePoint = attachPoint or pt,
            xOfs          = x or 0,
            yOfs          = y or 0,
        }
        dodoDB.editMode = dodoDB.editMode or {}
        dodoDB.editMode[system_name] = save
        if on_position_changed then on_position_changed(save) end
    end

    -- Position 모듈 연동: LEM 프레임 선택 시 pos 패널 갱신
    if lem_selection then
        lem_selection:HookScript("OnMouseDown", function()
            if dodo.EditMode.SelectPosFrame then
                dodo.EditMode.SelectPosFrame(system)
            end
        end)
    end

    -- Position 모듈 연동: LEM dialog 참조 & OnHide 훅 (최초 1회)
    if LEM.internal and LEM.internal.dialog and not EditMode._lemDialogHookedPos then
        EditMode._lemDialog = LEM.internal.dialog
        EditMode._lemDialogHookedPos = true
        LEM.internal.dialog:HookScript("OnHide", function()
            if dodo.EditMode.ClearPosFrame then
                dodo.EditMode.ClearPosFrame()
            end
        end)
    end

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
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        LEM = LibStub("LibEditMode")
        LEM:RegisterCallback("enter", dodo.EditMode._on_enter)
        LEM:RegisterCallback("exit",  dodo.EditMode._on_exit)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
