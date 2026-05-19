-- ==============================
-- Inspired
-- ==============================
--

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("FrameOption", module)

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
    local db = dodo.DB or {}

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
function module:OnEnable()
    if FrameScale then FrameScale() end
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    dodo.UI.Header(dodo.subCategoryInterface, "프레임 크기")
    dodo.UI.Slider(dodo.subCategoryInterface, "frameScale_gmf", "게임 메뉴", "게임 메뉴 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.9", 0.5, 1.5, 0.1, 1, "Percent", FrameScale)
    dodo.UI.Slider(dodo.subCategoryInterface, "frameScale_mmbbb", "가방버튼", "가방버튼 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.7", 0.5, 1.5, 0.1, 1, "Percent", FrameScale)
    dodo.UI.Slider(dodo.subCategoryInterface, "frameScale_th", "말머리", "말머리 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.8", 0.5, 1.5, 0.1, 1, "Percent", FrameScale)
end