------------------------------
-- 동작
------------------------------
function CameraTilt()
    local db = hodoDB or {}
    local base = db.CameraBase or 0.55
    local baseDown = db.CameraDown or 0.55
    local baseFlying = db.CameraFlying or 0.55

    if db.useCameraBase then
        SetCVar("test_cameraDynamicPitch", 1)
        SetCVar("CameraKeepCharacterCentered", 0)
        SetCVar("test_cameraDynamicPitchBaseFovPad", base)
    else
        SetCVar("test_cameraDynamicPitch", 0) -- 껐다켰다 기능이라 else값 넣어줘야함
        SetCVar("CameraKeepCharacterCentered", 1)
    end

    if db.useCameraDown then
        SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", baseDown)
    else
        SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0)
    end

    if db.useCameraFlying then
        SetCVar("test_cameraDynamicPitchBaseFovPadFlying", baseFlying)
    else
        SetCVar("test_cameraDynamicPitchBaseFovPadFlying", 0)
    end
end


------------------------------
-- 이벤트
------------------------------
local initCamera = CreateFrame("Frame")
initCamera:RegisterEvent("PLAYER_LOGIN")
initCamera:SetScript("OnEvent", function(self, event)
    hodoDB = hodoDB or {}
    UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    if CameraTilt then CameraTilt() end
    if hodoCreateOptions then hodoCreateOptions() end
    self:UnregisterAllEvents()
end)