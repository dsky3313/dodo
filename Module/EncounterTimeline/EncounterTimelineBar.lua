---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame

-- UpdatePosition이 SetPointsOffset(x, y)으로 최종 위치를 결정함.
-- BottomToTop 기준: BOTTOM→BOTTOM + Y=+N (양수 = 위로)
-- TopToBottom 목표: hook에서 TOP→TOP + Y=-N으로 덮어씀 (N이 양수면 아래로)
-- frameOffsetY: SetVerticalOffset이 저장하는 실제 오프셋 값

local hook_registered = false

local function register_hooks(tv)
    if hook_registered then return end
    hook_registered = true

    hooksecurefunc(EncounterTimelineTimerEventMixin, "UpdatePosition", function(self)
        if not dodoDB.useEncounterTimelineBarGrowDown then return end
        local y = math.floor(self.frameOffsetY or 0)
        self:ClearAllPoints()
        self:SetPoint("TOP", tv, "TOP", 0, -y)
    end)
end

local bar_frame = CreateFrame("Frame")
bar_frame:RegisterEvent("PLAYER_LOGIN")
bar_frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        dodoDB = dodoDB or {}
        local tv = EncounterTimeline and EncounterTimeline.TimerView
        if tv then
            register_hooks(tv)
        end
    end
end)

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.EncounterEvents, {
        {
            name = "위에서 아래로 쌓기",
            get = function() return dodoDB.useEncounterTimelineBarGrowDown == true end,
            set = function(val)
                dodoDB.useEncounterTimelineBarGrowDown = val
                local tv = EncounterTimeline and EncounterTimeline.TimerView
                if not tv then return end
                for eventFrame in tv:EnumerateEventFrames() do
                    eventFrame:ClearAllPoints()
                    if val then
                        local y = math.floor(eventFrame.frameOffsetY or 0)
                        eventFrame:SetPoint("TOP", tv, "TOP", 0, -y)
                    else
                        AnchorUtil.SetMirroredPointAlongVerticalAxis(eventFrame, "TOP", tv, "TOP", 0, 0)
                    end
                end
            end,
        },
    })
end
