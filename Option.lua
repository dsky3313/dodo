------------------------------
-- 테이블 /run hodoDB = nil; ReloadUI()
------------------------------
local addonName, ns = ...

hodoDB = hodoDB or {}

local OptionCategory = Settings.RegisterVerticalLayoutCategory("hodo")
Settings.RegisterAddOnCategory(OptionCategory)


------------------------------
-- 동작
------------------------------
function hodoCreateOptions()
    if hodoOptionsCreated then return OptionCategory end

    local hodoOptionLayout = SettingsPanel:GetLayout(OptionCategory)
    if not hodoOptionLayout then return end

    -- 설정값 등록
    --[[
    Checkbox(OptionCategory, "DB저장명", "이름", "툴팁", true)
    Slider(OptionCategory, "DB저장명", "이름", "툴팁", 최소값, 최대값, 틱, 기본값, 포매터)
    DropDown(OptionCategory, "DB저장명", "이름", "툴팁", 테이블, 테이블[1].value)
    CheckBoxDropDown(OptionCategory, "체크박스DB저장명", "드롭다운DB저장명", "이름", "툴팁", 테이블, true, 테이블[1].value)
    ]]

    -- 글꼴
    local ChatBubbleFrame = CreateSettingsListSectionHeaderInitializer("글꼴")
    hodoOptionLayout:AddInitializer(ChatBubbleFrame)
    DropDown(OptionCategory, "chatbubbleFontPath", "말풍선 글꼴", "말풍선에 적용할 폰트를 선택하세요.", fontOption, fontOption[1].value)
    Slider(OptionCategory, "chatbubbleFontSize", "말풍선 글꼴 크기", "말풍선 글꼴 크기를 변경합니다.", 8, 14, 1, 10, "Integer")

    -- 카메라
    local CameraFrame = CreateSettingsListSectionHeaderInitializer("카메라 시점")
    hodoOptionLayout:AddInitializer(CameraFrame)
    Slider(OptionCategory, "cameraBase", "기본 시점", "기본시점 각도를 조절합니다.", 0.3, 1.0, 0.05, 0.55, "Decimal2")
    Slider(OptionCategory, "cameraDown", "탑다운 뷰", "수직으로 내렸을 때 각도를 조절합니다.", 0.3, 1.0, 0.05, 0.55, "Decimal2")
    Slider(OptionCategory, "cameraFlying", "하늘비행 탈것 시점", "하늘비행 탈것 탑승 시 각도를 조절합니다.", 0.3, 1.0, 0.05, 0.55, "Decimal2")

    -- 파티
    local CameraFrame = CreateSettingsListSectionHeaderInitializer("파티")
    hodoOptionLayout:AddInitializer(CameraFrame)
    CheckBoxDropDown(OptionCategory, "useNewLFG", "soundID", "파티신청 알림", "새로운 파티신청 시 알림", NewLFG_AlertSoundTable, true, NewLFG_AlertSoundTable[2].value)

    -- 편의기능
    local QoLHeader = CreateSettingsListSectionHeaderInitializer("편의기능")
    hodoOptionLayout:AddInitializer(QoLHeader)
    Checkbox(OptionCategory, "useAuctionFilter", "경매장 필터", "경매장에서 '현행 확장팩 전용'을 자동 활성화합니다.", true)
    Checkbox(OptionCategory, "useCraftFilter", "주문제작 필터", "주문제작에서 '현행 확장팩 전용'을 자동 활성화합니다.", true)
    local settingParentDeleteNow, initParentDeleteNow = Checkbox(OptionCategory, "deleteNowAutoFill", "\"지금파괴\" 자동기입", "아이템 파괴 확인 메시지를 자동으로 입력합니다.", true)
    local settingChildDeleteNow, initChildDeleteNow = Checkbox(OptionCategory, "deleteNowHideEditbox", "아이템 파괴 간소화", "확인 메시지를 없애고 확인버튼만 남깁니다.", true)
    if settingParentDeleteNow and settingChildDeleteNow then
        settingParentDeleteNow:SetValueChangedCallback(function(_, value)
            if value == false then
                settingChildDeleteNow:SetValue(false) -- 부모가 꺼지면 자식도 끔
            end
        end)
        initChildDeleteNow:SetParentInitializer(initParentDeleteNow, function()
            return settingParentDeleteNow:GetValue()
        end)
    end

    local FrameScaleHeader = CreateSettingsListSectionHeaderInitializer("프레임 크기조절")
    hodoOptionLayout:AddInitializer(FrameScaleHeader)
    Slider(OptionCategory, "frameScale_gmf", "게임 메뉴", "게임 메뉴 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.9, "Percent")
    Slider(OptionCategory, "frameScale_mmbbb", "가방버튼", "가방버튼 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.7, "Percent")
    Slider(OptionCategory, "frameScale_th", "말머리", "말머리 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.8, "Percent")
    ---

    hodoOptionsCreated = true
    return OptionCategory
end

------------------------------
-- 이벤트
------------------------------
-- 애드온 로딩이 완료된 시점에 설정창을 미리 만들어둡니다.
local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("PLAYER_LOGIN")
initOptionFrame:SetScript("OnEvent", function()
    hodoCreateOptions()
end)

------------------------------
-- 명령어
------------------------------
SLASH_hodo1 = "/hh"
SLASH_hodo2 = "/ㅗㅗ"
SlashCmdList["hodo"] = function()
    if InCombatLockdown() then
        print("|cffff0000hodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    Settings.OpenToCategory(OptionCategory:GetID())
end