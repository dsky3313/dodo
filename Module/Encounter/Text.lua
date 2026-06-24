---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterTimeline = C_EncounterTimeline
local C_Timer             = C_Timer
local CreateFrame         = CreateFrame
local GetInstanceInfo     = GetInstanceInfo
local GetTime             = GetTime
local IsInInstance        = IsInInstance
local UIParent            = UIParent
local ipairs              = ipairs
local math_max            = math.max
local select              = select
local table_insert        = table.insert
local table_remove        = table.remove

-- ==============================
-- UI
-- ==============================
-- [아이콘 + cooldown] [스펠명]  ← 복수 행으로 쌓임

local ROW_W             = 300
local ROW_GAP           = 4
local DEFAULT_ICON_SIZE = 30
local DEFAULT_FONT_SIZE = 15

local active_alerts  = {}
local frame_pool     = {}
local icon_count     = 0
local is_preview     = false

local name_font_path  = "Fonts\\FRIZQT__.TTF"
local name_font_flags = "OUTLINE"

-- 전방 선언
local hide_alert
local hide_all_alerts

local function get_icon_size()
    return (dodoDB and dodoDB.encounterTextIconSize) or DEFAULT_ICON_SIZE
end

local function get_font_size()
    return (dodoDB and dodoDB.encounterTextFontSize) or DEFAULT_FONT_SIZE
end

local function get_row_h()
    return math_max(get_icon_size(), get_font_size() + 8)
end

local function get_anchor()
    return dodo.EditMode and dodo.EditMode:GetSystem("EncounterText")
end

local function resize_row(row)
    local icon_size = get_icon_size()
    row.frame:SetSize(ROW_W, get_row_h())
    if row.icon_frame then row.icon_frame:SetSize(icon_size, icon_size) end
    row.name_fs:SetFont(name_font_path, get_font_size(), name_font_flags)
end

local function create_row()
    if #frame_pool > 0 then
        local row = table_remove(frame_pool)
        resize_row(row)
        return row
    end

    icon_count = icon_count + 1
    local row      = {}
    local icon_size = get_icon_size()

    row.frame = CreateFrame("Frame", nil, UIParent)
    row.frame:SetSize(ROW_W, get_row_h())
    row.frame:SetFrameStrata("LOW")
    row.frame:EnableMouse(false)
    row.frame:Hide()

    local icon_frame = dodo.LibIcon:Create(
        "dodoEncounterTextIcon" .. icon_count, row.frame, { iconsize = {icon_size, icon_size} }
    )
    icon_frame:SetPoint("LEFT", row.frame, "LEFT", 5, 0)
    icon_frame:EnableMouse(false)
    row.icon_frame = icon_frame
    row.icon_tex   = icon_frame.icon
    row.icon_cd    = icon_frame.cooldown

    row.name_fs = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.name_fs:SetPoint("LEFT", icon_frame, "RIGHT", 8, 0)
    row.name_fs:SetPoint("RIGHT", row.frame, "RIGHT", -5, 0)
    row.name_fs:SetJustifyH("LEFT")
    row.name_fs:SetJustifyV("MIDDLE")
    row.name_fs:SetTextColor(1, 1, 1, 1)
    row.name_fs:SetFont(name_font_path, get_font_size(), name_font_flags)

    return row
end

local function reposition_rows()
    local an    = get_anchor()
    local row_h = get_row_h()
    for i, entry in ipairs(active_alerts) do
        entry.frame:ClearAllPoints()
        if an then
            entry.frame:SetPoint("CENTER", an, "CENTER", 0, (i - 1) * (row_h + ROW_GAP))
        else
            entry.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150 + (i - 1) * (row_h + ROW_GAP))
        end
    end
end

local function recycle_row(row)
    row.icon_cd:Clear()
    row.frame:Hide()
    row.eventID = nil
    table_insert(frame_pool, row)
end

local function refresh_rows()
    for _, row in ipairs(active_alerts) do resize_row(row) end
    for _, row in ipairs(frame_pool)    do resize_row(row) end
    reposition_rows()
end

hide_alert = function(eventID)
    for i, entry in ipairs(active_alerts) do
        if entry.eventID == eventID then
            recycle_row(entry)
            table_remove(active_alerts, i)
            reposition_rows()
            return
        end
    end
end

hide_all_alerts = function()
    for _, entry in ipairs(active_alerts) do
        recycle_row(entry)
    end
    active_alerts = {}
end

local function on_hide_alert(eventID)
    hide_alert(eventID)
end

local function show_alert(eventID, info, role)
    local ec = dodo.Colors and dodo.Colors.EncounterColor
    local c  = ec and role and ec[role]
    for _, entry in ipairs(active_alerts) do
        if entry.eventID == eventID then
            entry.icon_tex:SetTexture(info.iconFileID)
            entry.name_fs:SetText(info.spellName)  -- secret → setter
            if c then entry.name_fs:SetTextColor(c.r, c.g, c.b, 1) end
            local r = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID)
            if r and r > 0 then entry.icon_cd:SetCooldown(GetTime(), r) end
            return
        end
    end

    is_preview = false
    local row  = create_row()
    row.eventID = eventID
    row.frame:SetFrameStrata("HIGH")
    row.icon_tex:SetTexture(info.iconFileID)  -- secret → setter
    row.name_fs:SetText(info.spellName)        -- secret → setter
    if c then row.name_fs:SetTextColor(c.r, c.g, c.b, 1) end
    local r = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID)
    if r and r > 0 then row.icon_cd:SetCooldown(GetTime(), r) else row.icon_cd:Clear() end

    table_insert(active_alerts, row)
    reposition_rows()
    row.frame:Show()

    local timer_dur = (r and r > 0) and (r + 1) or 6
    C_Timer.After(timer_dur, on_hide_alert, eventID)
end

-- ==============================
-- EditMode 프리뷰
-- ==============================
local PREVIEW_ID = "preview"

local function show_preview()
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterText ~= false) then return end
    if is_preview then return end
    is_preview = true
    local row   = create_row()
    row.eventID = PREVIEW_ID
    row.frame:SetFrameStrata("LOW")
    row.icon_tex:SetTexture(134400)
    row.name_fs:SetText("보스 기술 이름")
    row.icon_cd:SetCooldown(GetTime(), 5)
    table_insert(active_alerts, row)
    reposition_rows()
    row.frame:Show()
end

local function hide_preview()
    is_preview = false
    hide_alert(PREVIEW_ID)
end

-- ==============================
-- 타임라인 이벤트 핸들러
-- ==============================
local function on_timeline_highlight(eventID)
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterText ~= false) then return end
    if not (C_EncounterTimeline and C_EncounterTimeline.GetEventInfo) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID = select(8, GetInstanceInfo())
    if not (dodo.EncounterEvents and dodo.EncounterEvents[mapID]) then return end

    local info = C_EncounterTimeline.GetEventInfo(eventID)
    -- info.source = NeverSecret → 비교 허용
    if not info or info.source ~= dodo.Encounter.ENCOUNTER_SOURCE then return end

    -- info.id: non-secret 고정 eventID → Data.lua와 직접 매핑
    print("[dodo Text] HIGHLIGHT timelineID=" .. tostring(eventID) .. " info.id=" .. tostring(info.id))
    local event_role
    for _, entry in ipairs(dodo.EncounterEvents[mapID]) do
        if entry.eventID == info.id then
            if entry.enable == false then return end
            event_role = entry.role
            break
        end
    end

    show_alert(eventID, info, event_role)
end

local function on_state_changed(eventID)
    if not (C_EncounterTimeline and C_EncounterTimeline.GetEventState) then return end
    -- GetEventState: non-secret
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == dodo.Encounter.STATE_FINISHED or state == dodo.Encounter.STATE_CANCELED then
        hide_alert(eventID)
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local text_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEncounterText == nil then dodoDB.enableEncounterText = true end
        local gf = _G.GameFontNormalLarge
        if gf then
            local path = gf:GetFont()
            name_font_path = path or name_font_path
        end
        if dodo.EditMode then
            dodo.EditMode:CreateSystem(
                "EncounterText", "보스 알림", "보스 알림",
                UIParent, ROW_W, DEFAULT_ICON_SIZE,
                { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", xOfs = 10, yOfs = -175 },
                nil,
                function() return dodo.Encounter.IsEnabled() and (dodoDB and dodoDB.enableEncounterText ~= false) end
            )
        end
        local em_frame = _G.dodoEditModeEncounterText
        if em_frame then
            em_frame:HookScript("OnShow", show_preview)
            em_frame:HookScript("OnHide", hide_preview)
        end
        if dodo.RegisterEditModeSystemSetting then
            dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.EncounterEvents, {
                {
                    name       = "텍스트 알림",
                    systemName = "EncounterText",
                    get        = function() return dodoDB and dodoDB.enableEncounterText ~= false end,
                    set        = function(checked)
                        if dodoDB then dodoDB.enableEncounterText = checked end
                    end,
                    disabled   = function() return not dodo.Encounter.IsEnabled() end,
                },
            })
        end
        if dodo.RegisterEditModeSystemSetting then
            dodo.RegisterEditModeSystemSetting("EncounterText", {
                {
                    name = "아이콘 크기",
                    type = "slider",
                    get  = function() return get_icon_size() end,
                    set  = function(v)
                        if dodoDB then dodoDB.encounterTextIconSize = v end
                        refresh_rows()
                    end,
                    minVal   = 16,
                    maxVal   = 48,
                    step     = 1,
                    disabled = function() return not dodo.Encounter.IsEnabled() end,
                },
                {
                    name = "텍스트 크기",
                    type = "slider",
                    get  = function() return get_font_size() end,
                    set  = function(v)
                        if dodoDB then dodoDB.encounterTextFontSize = v end
                        refresh_rows()
                    end,
                    minVal   = 10,
                    maxVal   = 24,
                    step     = 1,
                    disabled = function() return not dodo.Encounter.IsEnabled() end,
                },
            })
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        hide_all_alerts()
    elseif event == "ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT" then
        on_timeline_highlight(arg1)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        on_state_changed(arg1)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        hide_alert(arg1)
    end
end

text_frame:RegisterEvent("ADDON_LOADED")
text_frame:RegisterEvent("PLAYER_LOGIN")
text_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
text_frame:SetScript("OnEvent", on_event)

