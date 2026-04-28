-- ==============================
-- Inspired
-- ==============================
--

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local FrameScaleOption = {
    gameMenuFrame = 0.9,
    bagButton = 0.7,
    talkingHeadFrame = 0.8,
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame

-- 변수
local gmf = GameMenuFrame
local mmbbb = MainMenuBarBackpackButton
local thf = TalkingHeadFrame

-- ==============================
-- 동작
-- ==============================
local function FrameScale()
    local db = dodoDB or {}

    local gmfScale = db.frameScale_gmf or FrameScaleOption.gameMenuFrame
    local mmbbbScale = db.frameScale_mmbbb or FrameScaleOption.bagButton
    local thfScale = db.frameScale_th or FrameScaleOption.talkingHeadFrame

    if gmf then gmf:SetScale(gmfScale) end
    if mmbbb then mmbbb:SetScale(mmbbbScale) end
    if thf then thf:SetScale(thfScale) end
end


-- ==============================
-- 이벤트
-- ==============================
local initFrameScale = CreateFrame("Frame")
initFrameScale:RegisterEvent("ADDON_LOADED")
initFrameScale:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        if FrameScale then FrameScale() end
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.FrameScale = FrameScale