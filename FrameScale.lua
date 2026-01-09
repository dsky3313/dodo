------------------------------
-- 동작
------------------------------
function FrameScale()
    local db = hodoDB or {}
    local GMF = GameMenuFrame
    local MMBBB = MainMenuBarBackpackButton
    local THF = TalkingHeadFrame

    if db.FrameScale_GM and GMF then -- 게임 메뉴 (ESC)
        GMF:SetScale(db.FrameScale_GM)
    end

    if db.FrameScale_TH and THF then -- 말머리 (TalkingHead)
        THF:SetScale(db.FrameScale_TH)
    end

    if db.FrameScale_MMBBB and MMBBB then -- 가방 버튼
        MMBBB:SetScale(db.FrameScale_MMBBB)
    end
end

------------------------------
-- 이벤트
------------------------------
local initFrameScale = CreateFrame("Frame")
initFrameScale:RegisterEvent("PLAYER_LOGIN")
initFrameScale:SetScript("OnEvent", function(self, event)
    hodoDB = hodoDB or {}
    if FrameScale then FrameScale() end
    if hodoCreateOptions then hodoCreateOptions() end
    self:UnregisterAllEvents()
end)