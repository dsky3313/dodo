-- ==============================
-- Inspired
-- ==============================
-- dodo

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
    talkingHeadFrame = 0.8,
}

-- ==============================
-- 캐싱
-- ==============================
local _G = _G
local CreateFrame = CreateFrame
local GameMenuFrame = GameMenuFrame
local TalkingHeadFrame = TalkingHeadFrame

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function frame_scale()
    local db = dodoDB or {}

    local gmf = GameMenuFrame
    if gmf then gmf:SetScale(0.9) end

    local thf = TalkingHeadFrame or _G["TalkingHeadFrame"]
    if thf then
        if db.useTalkingHeadScale ~= false then
            local thf_scale = db.frameScale_th or Config.talkingHeadFrame
            thf:SetScale(thf_scale)
        else
            thf:SetScale(1.0)
        end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local init_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
            self:RegisterEvent("PLAYER_LOGIN")
        elseif arg1 == "Blizzard_TalkingHeadUI" then
            frame_scale()
        end
    elseif event == "PLAYER_LOGIN" then
        frame_scale()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 외부 노출 및 모듈설정창 이관
-- ==============================
dodo.FrameScale = frame_scale

if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("인터페이스", {
        {
            name = "말머리 크기 조절",
            get = function() return dodoDB and dodoDB.useTalkingHeadScale ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTalkingHeadScale = checked end
                dodo.FrameScale()
            end
        },
        {
            type = "slider",
            name = "말머리 크기",
            minVal = 0.5,
            maxVal = 1.5,
            step = 0.1,
            get = function() return dodoDB and dodoDB.frameScale_th or Config.talkingHeadFrame end,
            set = function(val)
                if dodoDB then dodoDB.frameScale_th = val end
                dodo.FrameScale()
            end,
            disabled = function() return dodoDB and dodoDB.useTalkingHeadScale == false end
        }
    })
end