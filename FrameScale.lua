------------------------------
-- 테이블
------------------------------
local addonName, ns = ...

local gmf = GameMenuFrame
local mmbbb = MainMenuBarBackpackButton
local thf = TalkingHeadFrame

------------------------------
-- 동작
------------------------------
local function FrameScale()
    local db = hodoDB or {}

    local gmfScale = db.frameScale_gmf or 0.9
    local mmbbbScale = db.frameScale_mmbbb or 0.7
    local thfScale = db.frameScale_th or 0.8

    if gmf then gmf:SetScale(gmfScale) end
    if mmbbb then mmbbb:SetScale(mmbbbScale) end
    if thf then thf:SetScale(thfScale) end
end

ns.FrameScale = FrameScale

------------------------------
-- 이벤트
------------------------------
local initFrameScale = CreateFrame("Frame")
initFrameScale:RegisterEvent("PLAYER_LOGIN")
initFrameScale:SetScript("OnEvent", function(self, event)
    hodoDB = hodoDB or {}
    if hodoCreateOptions then hodoCreateOptions() end
    C_Timer.After(0.5, function() FrameScale() end)
    self:UnregisterAllEvents()
end)