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
local math_abs            = math.abs
local math_max            = math.max
local select              = select
local table_insert        = table.insert
local table_remove        = table.remove
local table_sort          = table.sort
local wipe                = wipe

local SOUND_DEFAULT_TEXT = {
    Adds    = "쫄 등장",
    AOE     = "광역딜",
    Dispel  = "해제",
    Frontal = "전방",
    Interrupt = "차단",
    Phase   = "사이페",
    Pool = "바닥 유도" ,
    Soak = "바닥 밟기",
    Tank    = "탱커",
    Target = "대상",
}

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

local function get_font()
    return STANDARD_TEXT_FONT or "", "OUTLINE"
end

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
    local fp, ff    = get_font()
    row.frame:SetSize(ROW_W, get_row_h())
    if row.icon_frame then row.icon_frame:SetSize(icon_size, icon_size) end
    row.name_fs:SetFont(fp, get_font_size(), ff)
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
    row.frame:SetFrameStrata("MEDIUM")
    row.frame:SetFrameLevel(555)
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
    local fp, ff = get_font()
    row.name_fs:SetFont(fp, get_font_size(), ff)

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

-- custom_text: Data.lua entry.text (non-secret) 있으면 사용, 없으면 info.spellName(secret→setter)
local function show_alert(eventID, info, role, custom_text)
    local ec = dodo.Colors and dodo.Colors.EncounterColor
    local c  = ec and role and role ~= "Other" and ec[role]
    for _, entry in ipairs(active_alerts) do
        if entry.eventID == eventID then
            entry.icon_tex:SetTexture(info.iconFileID)
            if custom_text then
                entry.name_fs:SetText(custom_text)
            else
                entry.name_fs:SetText(info.spellName)  -- secret → setter
            end
            if c then
                entry.name_fs:SetTextColor(c.r, c.g, c.b, 1)
            else
                entry.name_fs:SetTextColor(1, 1, 1, 1)
            end
            local r = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID)
            if r and r > 0 then entry.icon_cd:SetCooldown(GetTime(), r) end
            return
        end
    end

    is_preview = false
    local row  = create_row()
    row.eventID = eventID
    row.icon_tex:SetTexture(info.iconFileID)  -- secret → setter
    if custom_text then
        row.name_fs:SetText(custom_text)
    else
        row.name_fs:SetText(info.spellName)   -- secret → setter
    end
    if c then
        row.name_fs:SetTextColor(c.r, c.g, c.b, 1)
    else
        row.name_fs:SetTextColor(1, 1, 1, 1)
    end
    local r = C_EncounterTimeline.GetEventTimeRemaining and C_EncounterTimeline.GetEventTimeRemaining(eventID)
    if r and r > 0 then row.icon_cd:SetCooldown(GetTime(), r) else row.icon_cd:Clear() end

    table_insert(active_alerts, row)
    reposition_rows()
    row.frame:Show()

    local timer_dur = (r and r > 0) and (r + 1) or 6
    C_Timer.After(timer_dur, function() hide_alert(eventID) end)
end

-- ==============================
-- tempID → entry 매핑 (EXBoss AI driver 방식)
-- ==============================
local MATCH_TOL    = 0.75  -- duration 매칭 허용 오차 (초)
local BATCH_WINDOW = 0.6   -- pending flush 대기 시간 (초)



local current_encounter  = nil  -- ENCOUNTER_START에서 받은 encounterID
local pending_adds       = {}   -- {tempID, dur, receivedAt}
local temp_to_entry      = {}   -- tempID → EncounterEvents entry
local flush_scheduled    = false
local global_rule_used   = {}   -- rule_index → true (seq 없는 규칙 슬롯 관리)
local temp_to_rule_idx   = {}   -- tempID → rule_index (해제용 역참조)
local seq_counter        = {}   -- dur_key → 발동 횟수 (seq 규칙 round-robin용)

local function flush_pending_adds()
    flush_scheduled = false
    if not current_encounter or #pending_adds == 0 then
        wipe(pending_adds)
        return
    end
    local data    = dodo.EncounterData and dodo.EncounterData[current_encounter]
    local rules   = data and data.rules
    local entries = data and data.events
    if not rules or not entries then
        wipe(pending_adds)
        return
    end

    -- eventID 또는 spellID → entry 역참조 (신규 형식은 spellID를 키로 사용)
    local by_eid = {}
    for _, e in ipairs(entries) do
        by_eid[e.eventID or e.spellID] = e
    end

    -- 도착 순서 보장
    if #pending_adds > 1 then
        table_sort(pending_adds, function(a, b) return a.receivedAt < b.receivedAt end)
    end

    -- dead slot 정리: 타임라인에서 실제 사라진 이벤트의 슬롯만 해제
    -- (pending에 없어도 타임라인에 살아있으면 유지 → 같은 사이클 내 다른 이벤트 슬롯 보호)
    local pending_id_set = {}
    for _, pev in ipairs(pending_adds) do pending_id_set[pev.tempID] = true end
    if C_EncounterTimeline.GetEventInfo then
        for tempID, ruleIdx in pairs(temp_to_rule_idx) do
            if not pending_id_set[tempID] then
                local still_alive = C_EncounterTimeline.GetEventInfo(tempID)
                if not still_alive then
                    global_rule_used[ruleIdx] = nil
                    temp_to_rule_idx[tempID]  = nil
                    temp_to_entry[tempID]     = nil
                    if dodo.EncounterDebug then
                        print(string.format("[dodo] 슬롯해제 id=%d 규칙#%d", tempID, ruleIdx))
                    end
                else
                    if dodo.EncounterDebug then
                        local rule = rules[ruleIdx]
                        print(string.format("[dodo] 슬롯유지 id=%d 규칙#%d 지속=%.2f", tempID, ruleIdx, rule and rule.dur or 0))
                    end
                end
            end
        end
    end

    -- seq 규칙 그룹 사전 계산 (round-robin counter용)
    local seq_groups = {}  -- dur_key → [{idx, seq}] sorted by seq
    for i, rule in ipairs(rules) do
        if rule.seq then
            local k = string.format("%.2f", rule.dur)
            if not seq_groups[k] then seq_groups[k] = {} end
            local g = seq_groups[k]
            g[#g + 1] = { idx = i, seq = rule.seq }
        end
    end
    for _, g in pairs(seq_groups) do
        table_sort(g, function(a, b) return a.seq < b.seq end)
    end

    -- 매칭: seq 규칙 → round-robin counter, 나머지 → 그리디
    for _, pev in ipairs(pending_adds) do
        local best_i = nil

        -- seq 그룹 탐색
        local grp_key, grp = nil, nil
        for k, g in pairs(seq_groups) do
            if math_abs(pev.dur - tonumber(k)) <= MATCH_TOL then
                grp_key, grp = k, g
                break
            end
        end

        if grp then
            local cnt  = seq_counter[grp_key] or 0
            local pick = grp[(cnt % #grp) + 1]
            best_i = pick.idx
            seq_counter[grp_key] = cnt + 1
            if dodo.EncounterDebug then
                local rule = rules[best_i]
                local e    = by_eid[rule.eID]
                print(string.format("[dodo] 카운터매칭 id=%d 지속=%.2f → 규칙#%d eID=%s 순서=%d 사운드=%s (cnt=%d)",
                    pev.tempID, pev.dur, best_i, tostring(rule.eID), rule.seq,
                    e and tostring(e.sound) or "없음", cnt))
            end
        else
            -- seq 없는 규칙: 그리디
            local best_d = math_abs(MATCH_TOL) + 1
            for i, rule in ipairs(rules) do
                if not rule.seq and not global_rule_used[i] then
                    local d = math_abs(pev.dur - rule.dur)
                    if d <= MATCH_TOL and d < best_d then
                        best_d = d
                        best_i = i
                    end
                end
            end
            if dodo.EncounterDebug then
                if best_i then
                    local rule = rules[best_i]
                    local e    = by_eid[rule.eID]
                    print(string.format("[dodo] 매칭 id=%d 지속=%.2f → 규칙#%d 지속=%.2f eID=%s 사운드=%s",
                        pev.tempID, pev.dur, best_i, rule.dur, tostring(rule.eID),
                        e and tostring(e.sound) or "없음"))
                else
                    local blocked = ""
                    for i, rule in ipairs(rules) do
                        if global_rule_used[i] and math_abs(pev.dur - rule.dur) <= MATCH_TOL then
                            blocked = blocked .. string.format(" #%d(%.1f점유)", i, rule.dur)
                        end
                    end
                    print(string.format("[dodo] 미매칭 id=%d 지속=%.2f%s",
                        pev.tempID, pev.dur, blocked ~= "" and blocked or " (규칙없음)"))
                end
            end
        end

        if best_i then
            if not rules[best_i].seq then
                global_rule_used[best_i] = true  -- seq 없는 규칙만 슬롯 점유
            end
            temp_to_rule_idx[pev.tempID] = best_i
            local e = by_eid[rules[best_i].eID]
            if e and e.enable ~= false then temp_to_entry[pev.tempID] = e end
        end
    end
    wipe(pending_adds)
end

local function clear_encounter_state()
    current_encounter = nil
    wipe(pending_adds)
    wipe(temp_to_entry)
    flush_scheduled   = false
    wipe(global_rule_used)
    wipe(temp_to_rule_idx)
    wipe(seq_counter)
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
    row.frame:SetFrameStrata("MEDIUM")
    row.frame:SetFrameLevel(555)
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
local function on_timeline_added(eventInfo)
    if not current_encounter then return end
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterText ~= false) then return end

    local tempID = eventInfo and eventInfo.id
    local dur    = eventInfo and tonumber(eventInfo.duration)
    if not tempID or not dur or dur <= 0 then return end
    if eventInfo.source ~= dodo.Encounter.ENCOUNTER_SOURCE then return end

    pending_adds[#pending_adds + 1] = { tempID = tempID, dur = dur, receivedAt = GetTime() }
    if dodo.EncounterDebug then
        print(string.format("[dodo]  추가 id=%d 지속=%.2f 대기=%d", tempID, dur, #pending_adds))
    end

    if not flush_scheduled then
        flush_scheduled = true
        C_Timer.After(BATCH_WINDOW, flush_pending_adds)
    end
end

local function on_timeline_highlight(eventID)
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterText ~= false) then return end
    if not (C_EncounterTimeline and C_EncounterTimeline.GetEventInfo) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    if not (dodo.EncounterData and current_encounter and dodo.EncounterData[current_encounter]) then return end

    local info = C_EncounterTimeline.GetEventInfo(eventID)
    -- info.source = non-secret → 비교 허용
    if not info or info.source ~= dodo.Encounter.ENCOUNTER_SOURCE then return end

    -- HIGHLIGHT가 flush 전에 오면 즉시 flush (dur 짧은 이벤트 대응)
    if flush_scheduled then flush_pending_adds() end

    local entry = temp_to_entry[eventID]
    local event_role  = entry and entry.role
    local event_sound = entry and entry.sound
    local event_text  = (entry and entry.text) or SOUND_DEFAULT_TEXT[event_sound]
    show_alert(eventID, info, event_role, event_text)
end

local function release_rule_slot(eventID)
    local idx = temp_to_rule_idx[eventID]
    if idx then
        global_rule_used[idx] = nil
        temp_to_rule_idx[eventID] = nil
    end
    temp_to_entry[eventID] = nil
end

local function on_state_changed(eventID)
    if not (C_EncounterTimeline and C_EncounterTimeline.GetEventState) then return end
    -- GetEventState: non-secret
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == dodo.Encounter.STATE_FINISHED or state == dodo.Encounter.STATE_CANCELED then
        hide_alert(eventID)
        if dodo.EncounterDebug then
            local idx = temp_to_rule_idx[eventID]
            if idx then print(string.format("[dodo] FINISHED 해제 id=%d 규칙#%d", eventID, idx)) end
        end
        release_rule_slot(eventID)
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
        end  -- RegisterEditModeSystemSetting
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        hide_all_alerts()
        clear_encounter_state()
    elseif event == "ENCOUNTER_START" then
        -- arg1 = encounterID
        current_encounter = arg1
        wipe(pending_adds)
        wipe(temp_to_entry)
        flush_scheduled   = false
        wipe(global_rule_used)
        wipe(temp_to_rule_idx)
        wipe(seq_counter)
    elseif event == "ENCOUNTER_END" then
        hide_all_alerts()
        clear_encounter_state()
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        -- arg1 = eventInfo table {id, duration, source, ...}
        on_timeline_added(arg1)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT" then
        on_timeline_highlight(arg1)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        on_state_changed(arg1)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        hide_alert(arg1)
        release_rule_slot(arg1)
    end
end

text_frame:RegisterEvent("ADDON_LOADED")
text_frame:RegisterEvent("PLAYER_LOGIN")
text_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
text_frame:RegisterEvent("ENCOUNTER_START")
text_frame:RegisterEvent("ENCOUNTER_END")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
text_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
text_frame:SetScript("OnEvent", on_event)
