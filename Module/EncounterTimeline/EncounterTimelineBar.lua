---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame

-- ==============================
-- 방향 적용
-- ==============================
-- SetTimerLayoutDirection → OnTimerLayoutDirectionChanged → ReinitializeAllEventFrames
-- → ReleaseEventFrame → EncounterTimeline:OnEventFrameReleased → MarkDirty (C_Timer taint)
-- 이 경로를 완전히 우회: timerLayoutDirection 필드 직접 설정 + 활성 프레임 재앵커링
-- TimerView:MarkDirty는 비트플래그만 설정, C_Timer 없음 → 안전
local function apply_direction(tv)
    local dir = dodoDB.useEncounterTimelineBarGrowDown
        and EncounterTimelineTimerLayoutDirection.TopToBottom
        or EncounterTimelineTimerLayoutDirection.BottomToTop
    if tv.timerLayoutDirection == dir then return end
    tv.timerLayoutDirection = dir
    -- MarkDirty 호출 제거: addon context에서 tv.dirtyFlags를 taint시키면
    -- 이후 OnUpdate에서 tainted execution → AnimateShow chain → EncounterTimeline:MarkDirty(tainted C_Timer) → secret value 에러
    -- 방향은 전투 진입 시 InitializeEventFrameSettings → IsFlippedVertically → GetTimerLayoutDirection에서 자동 반영됨
end

local function apply_settings()
    local tv = EncounterTimeline and EncounterTimeline.TimerView
    if not tv then return end
    apply_direction(tv)
    -- tv:SetPoint 제거: TimerView 위치 변경이 EncounterTimeline 콜백 → MarkDirty chain 유발 가능성
    -- Y 오프셋은 추후 안전한 방법으로 재구현
end

-- ==============================
-- 이벤트
-- ==============================
local bar_frame = CreateFrame("Frame")
bar_frame:RegisterEvent("PLAYER_LOGIN")
bar_frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        dodoDB = dodoDB or {}
        apply_settings()
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.EncounterEvents, {
        {
            name = "위에서 아래로 쌓기",
            get = function() return dodoDB.useEncounterTimelineBarGrowDown == true end,
            set = function(val)
                dodoDB.useEncounterTimelineBarGrowDown = val
                apply_settings()
            end,
        },
        {
            type = "slider",
            name = "시작 Y 오프셋",
            minVal = 0, maxVal = 200, step = 1,
            get = function() return dodoDB.encounterTimelineBarOffsetY or 0 end,
            set = function(val)
                dodoDB.encounterTimelineBarOffsetY = val
                apply_settings()
            end,
        },
    })
end
