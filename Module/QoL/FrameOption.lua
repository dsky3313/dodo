-- ==============================
-- FrameOption
-- ==============================
-- dodo

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
    talkingHeadFrame = 0.8,
}

-- ==============================
-- 캐싱
-- ==============================
local _G            = _G
local CreateFrame   = CreateFrame
local GameMenuFrame = GameMenuFrame

-- ==============================
-- 기능: 스케일 업데이트
-- ==============================
local function frame_scale()
    local enabled = dodoDB and dodoDB.enableFrameOption ~= false

    local gmf = GameMenuFrame
    if gmf then gmf:SetScale(enabled and 0.9 or 1.0) end

    local thf = _G["TalkingHeadFrame"]
    if thf then
        thf:SetScale(enabled and (dodoDB.frameScale_th or Config.talkingHeadFrame) or 1.0)
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
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableFrameOption == nil then dodoDB.enableFrameOption = true end
        frame_scale()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 외부 노출 및 설정 등록
-- ==============================
dodo.FrameScale = frame_scale

-- 편집모드에서 TalkingHeadFrame 클릭 시 wing 패널
dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.TalkingHeadFrame, {
    {
        name = "말머리 크기 변경",
        get  = function() return dodoDB and dodoDB.enableFrameOption ~= false end,
        set  = function(checked)
            if dodoDB then dodoDB.enableFrameOption = checked end
            frame_scale()
        end,
    },
    {
        type   = "slider",
        minVal = 0.5,
        maxVal = 1.5,
        step   = 0.1,
        get    = function() return dodoDB and dodoDB.frameScale_th or Config.talkingHeadFrame end,
        set    = function(val)
            if dodoDB then dodoDB.frameScale_th = val end
            frame_scale()
        end,
    },
})
