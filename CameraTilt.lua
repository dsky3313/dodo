------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}

------------------------------
-- 동작
------------------------------
local function CameraTilt()
    local base = dodoDB.cameraBase or 0.55
    local baseDown = dodoDB.cameraDown or 0.55
    local baseFlying = dodoDB.cameraFlying or 0.55

    SetCVar("test_cameraDynamicPitch", 1)
    SetCVar("CameraKeepCharacterCentered", 0)
    SetCVar("test_cameraDynamicPitchBaseFovPad", base)
    SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", baseDown)
    SetCVar("test_cameraDynamicPitchBaseFovPadFlying", baseFlying)
end

------------------------------
-- 이벤트
------------------------------
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("PLAYER_LOGIN")
initCamera:SetScript("OnEvent", function(self, event)
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    if CameraTilt then
        CameraTilt()
    end
    self:UnregisterAllEvents()
end)

dodo.CameraTilt = CameraTilt