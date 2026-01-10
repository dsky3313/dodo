------------------------------
-- 동작
------------------------------
local addonName, ns = ...

------------------------------
-- 동작
------------------------------
local function CameraTilt()
    local db = hodoDB or {}
    local base       = db.cameraBase or 0.55
    local baseDown   = db.cameraDown or 0.55
    local baseFlying = db.cameraFlying or 0.55

    SetCVar("test_cameraDynamicPitch", 1)
    SetCVar("CameraKeepCharacterCentered", 0)
    SetCVar("test_cameraDynamicPitchBaseFovPad", base)
    SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", baseDown)
    SetCVar("test_cameraDynamicPitchBaseFovPadFlying", baseFlying)
end

ns.CameraTilt = CameraTilt

------------------------------
-- 초기화 이벤트
------------------------------
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("PLAYER_LOGIN")
initCamera:SetScript("OnEvent", function(self, event)
    hodoDB = hodoDB or {}
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    if CameraTilt then CameraTilt()
    end
    self:UnregisterAllEvents()
end)