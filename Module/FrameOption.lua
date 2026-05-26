-- ==============================
-- Inspired
-- ==============================
-- dodo UI Frame Customizer

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

local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- ==============================
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local GameMenuFrame = GameMenuFrame
local MainMenuBarBackpackButton = MainMenuBarBackpackButton
local TalkingHeadFrame = TalkingHeadFrame

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local eventFrame = CreateFrame("Frame")

-- ==============================
-- 기능 1: 프레임 크기 조절
-- ==============================
local function update_feature()
    local db = dodo.DB or {}

    local mmbbbScale = db.frameScale_mmbbb or FrameScaleOption.bagButton
    local thfScale = db.frameScale_th or FrameScaleOption.talkingHeadFrame

    mmbbbScale = math.floor(mmbbbScale * 100 + 0.5) / 100
    thfScale = math.floor(thfScale * 100 + 0.5) / 100

    -- 게임메뉴 크기는 항상 0.9로 고정
    if GameMenuFrame then
        GameMenuFrame:SetScale(0.9)
    end
    
    if MainMenuBarBackpackButton then
        MainMenuBarBackpackButton:SetScale(mmbbbScale)
    end

    -- TalkingHeadFrame 지연 로딩 인게임 성능 최적화 처리
    if TalkingHeadFrame then
        TalkingHeadFrame:SetScale(thfScale)
    else
        if C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_TalkingHeadUI") then
            local th = _G["TalkingHeadFrame"]
            if th then
                th:SetScale(thfScale)
            end
        else
            -- 지연 로딩 시점에 안정적 반영을 위해 이벤트 대기 등록
            eventFrame:RegisterEvent("ADDON_LOADED")
        end
    end
end

-- 지연 로드 이벤트 핸들러
local function OnEvent(self, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_TalkingHeadUI" then
        local th = _G["TalkingHeadFrame"]
        if th and dodo.DB then
            local thfScale = dodo.DB.frameScale_th or FrameScaleOption.talkingHeadFrame
            th:SetScale(thfScale)
        end
        self:UnregisterEvent("ADDON_LOADED") -- 로드 완료 시 즉시 이벤트 해제로 CPU 소모 방지
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    -- DB 설정 초기값 세팅 (가방 버튼 및 말머리 대화 상자만 유지)
    if dodo.DB then
        if dodo.DB.frameScale_mmbbb == nil then
            dodo.DB.frameScale_mmbbb = FrameScaleOption.bagButton
        end
        if dodo.DB.frameScale_th == nil then
            dodo.DB.frameScale_th = FrameScaleOption.talkingHeadFrame
        end
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_feature()

    -- LibEditMode:AddSystemSettings를 통해 가방버튼과 말머리 크기를 설정 가능하도록 연동
    if LibEditMode then
        local settingType = LibEditMode.SettingType

        -- 1. Bags (가방버튼 크기)
        if Enum.EditModeSystem.Bags then
            LibEditMode:AddSystemSettings(Enum.EditModeSystem.Bags, {
                {
                    kind = settingType.Slider,
                    name = "가방버튼 크기",
                    desc = "가방버튼 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.7",
                    default = FrameScaleOption.bagButton,
                    minValue = 0.5,
                    maxValue = 1.5,
                    valueStep = 0.05,
                    formatter = function(val)
                        return string.format("%.2f", val)
                    end,
                    get = function()
                        local val = dodo.DB and dodo.DB.frameScale_mmbbb or FrameScaleOption.bagButton
                        return math.floor(val * 100 + 0.5) / 100
                    end,
                    set = function(_, newValue)
                        local cleanedValue = math.floor(newValue * 100 + 0.5) / 100
                        if dodo.DB then dodo.DB.frameScale_mmbbb = cleanedValue end
                        update_feature()
                    end,
                }
            })
        end

        -- 2. TalkingHeadFrame (말머리 크기)
        if Enum.EditModeSystem.TalkingHeadFrame then
            LibEditMode:AddSystemSettings(Enum.EditModeSystem.TalkingHeadFrame, {
                {
                    kind = settingType.Slider,
                    name = "말머리 크기",
                    desc = "말머리 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.8",
                    default = FrameScaleOption.talkingHeadFrame,
                    minValue = 0.5,
                    maxValue = 1.5,
                    valueStep = 0.05,
                    formatter = function(val)
                        return string.format("%.2f", val)
                    end,
                    get = function()
                        local val = dodo.DB and dodo.DB.frameScale_th or FrameScaleOption.talkingHeadFrame
                        return math.floor(val * 100 + 0.5) / 100
                    end,
                    set = function(_, newValue)
                        local cleanedValue = math.floor(newValue * 100 + 0.5) / 100
                        if dodo.DB then dodo.DB.frameScale_th = cleanedValue end
                        update_feature()
                    end,
                }
            })
        end
    end
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    -- 기존 옵션창에 등록된 크기 설정 기능은 삭제
end