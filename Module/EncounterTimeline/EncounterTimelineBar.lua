---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 캐싱
local CreateFrame = CreateFrame

-- ==============================
-- 적용
-- ==============================
local function apply_settings()
    local tv = EncounterTimeline and EncounterTimeline.TimerView
    if not tv or not tv.SetTimerLayoutDirection then return end

    local dir = dodoDB.useEncounterTimelineBarGrowDown
        and EncounterTimelineTimerLayoutDirection.TopToBottom
        or EncounterTimelineTimerLayoutDirection.BottomToTop
    tv:SetTimerLayoutDirection(dir)

    local offsetY = dodoDB.encounterTimelineBarOffsetY or 0
    tv:ClearAllPoints()
    tv:SetPoint("TOPLEFT", EncounterTimeline, "TOPLEFT", 0, -offsetY)
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
