local hodoCamera = CreateFrame("Frame")

-- 1. 설정값 정의
local hodoCameraSetting = {
    test_cameraDynamicPitch = 1,                       -- 1: 켬
    test_cameraDynamicPitchBaseFovPad = 0.55,           -- 기본 FOV 패딩값
    test_cameraDynamicPitchBaseFovPadDownScale = 0.55,  -- 탑다운뷰 보정
    test_cameraDynamicPitchBaseFovPadFlying = 0.55      -- 비행 시 패딩값
}

-- 2. 동작 정의 (실행될 내용)
hodoCamera:SetScript("OnEvent", function(self, event, ...)
    -- 다이나믹 피치 활성화
    SetCVar("test_cameraDynamicPitch", hodoCameraSetting.test_cameraDynamicPitch)
    
    -- 캐릭터 중앙 고정 해제
    if hodoCameraSetting.test_cameraDynamicPitch == 1 then
        SetCVar("CameraKeepCharacterCentered", 0)
    end

    -- 세부 수치 적용
    SetCVar("test_cameraDynamicPitchBaseFovPad", hodoCameraSetting.test_cameraDynamicPitchBaseFovPad)
    SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", hodoCameraSetting.test_cameraDynamicPitchBaseFovPadDownScale)
    SetCVar("test_cameraDynamicPitchBaseFovPadFlying", hodoCameraSetting.test_cameraDynamicPitchBaseFovPadFlying)
    
    print("|cff00ff00[DynamicCameraFix]|r 수치 0.55 설정이 적용되었습니다.")
end)

-- 3. 이벤트 등록 (이제부터 작동 시작)
hodoCamera:RegisterEvent("PLAYER_ENTERING_WORLD")