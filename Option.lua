------------------------------
-- 테이블 /run dodoDB = nil; ReloadUI()
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}

local OptionCategory = Settings.RegisterVerticalLayoutCategory("dodo")
Settings.RegisterAddOnCategory(OptionCategory)


------------------------------
-- 동작
------------------------------
function dodoCreateOptions()
    if dodoOptionsCreated then return OptionCategory end

    local dodoOptionLayout = SettingsPanel:GetLayout(OptionCategory)
    if not dodoOptionLayout then return end

    -- 설정값 등록
    --[[
    Checkbox(OptionCategory, "DB저장명", "이름", "툴팁", true, dodo.함수명)
    Slider(OptionCategory, "DB저장명", "이름", "툴팁", 최소값, 최대값, 틱, 기본값, 포매터)
    DropDown(OptionCategory, "DB저장명", "이름", "툴팁", 테이블, 테이블[1].value)
    CheckBoxDropDown(OptionCategory, "체크박스DB저장명", "드롭다운DB저장명", "이름", "툴팁", 테이블, true, 테이블[1].value, dodo.함수명)
    ]]

    -- 글꼴
    local ChatBubbleFrame = CreateSettingsListSectionHeaderInitializer("글꼴")
    dodoOptionLayout:AddInitializer(ChatBubbleFrame)
    DropDown(OptionCategory, "chatbubbleFontPath", "말풍선 글꼴", "말풍선에 적용할 글꼴를 선택하세요.", chatbubbleFontTable, chatbubbleFontTable[1].value, dodo.ChatBubble)
    Slider(OptionCategory, "chatbubbleFontSize", "말풍선 글꼴 크기", "말풍선 글꼴 크기를 변경합니다.", 8, 14, 1, 10, "Integer", dodo.ChatBubble)

    -- 카메라
    local CameraFrame = CreateSettingsListSectionHeaderInitializer("카메라 시점")
    dodoOptionLayout:AddInitializer(CameraFrame)
    Slider(OptionCategory, "cameraBase", "기본 시점", "기본시점 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 0.55, "Decimal2", dodo.CameraTilt)
    Slider(OptionCategory, "cameraDown", "탑다운 뷰", "수직으로 내렸을 때 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 0.55, "Decimal2", dodo.CameraTilt)
    Slider(OptionCategory, "cameraFlying", "하늘비행 탈것 시점", "하늘비행 탈것 탑승 시 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 0.55, "Decimal2", dodo.CameraTilt)

    -- 파티
    local PartyQoLFrame = CreateSettingsListSectionHeaderInitializer("파티")
    dodoOptionLayout:AddInitializer(PartyQoLFrame)
    Checkbox(OptionCategory, "useBrowseGroup", "파티 탐색하기 버튼", "파티원일 경우에도 '파티 탐색하기' 버튼을 표시합니다.", true, dodo.browseGroupsButton)
    Checkbox(OptionCategory, "useKeyRoll", "쐐기돌 굴림 알림", "쐐기 완료 후, 파티원의 돌목록과 돌변경 알림을 띄웁니다.", true, dodo.KeyRoll)
    -- Checkbox(OptionCategory, "useMyKey", "쐐기 던전명 복사", "파티 생성창에서 파티원의 쐐기돌 이름을 복사할 수 있습니다.", true, dodo.Mykey)
    -- Checkbox(OptionCategory, "usePartyClass", "클래스 현황", "파티원의 유틸 현황을 확인할 수 있습니다.", true, dodo.PartyClass)
    local settingParentNewLFG, _, initParentNewLFG = CheckBoxDropDown(OptionCategory, "useNewLFG", "soundID", "파티신청 알림", "새로운 파티신청 시 알림", newLFG_AlertSoundTable, true, newLFG_AlertSoundTable[2].value, dodo.NewLFG)
    local settingChildNewLFG, initChildNewLFG = Checkbox(OptionCategory, "useNewLFGLeader", "파티원 기능 활성화", "파티장원일 경우에도 활성화합니다. ", false, dodo.NewLFG)
    if settingParentNewLFG and settingChildNewLFG then
        settingParentNewLFG:SetValueChangedCallback(function(_, value)
            if value == false then
                settingChildNewLFG:SetValue(false) -- 부모가 꺼지면 자식도 끔
            end
        end)
        initChildNewLFG:SetParentInitializer(initParentNewLFG, function()
            return settingParentNewLFG:GetValue()
        end)
    end

    local settingParentInsDifficulty, initParentInsDifficulty = Checkbox(OptionCategory, "useInsDifficulty", "인스 난이도 고정", "솔플 혹은 파티장일 시, 던전 난이도를 자동으로 변경합니다.", true, dodo.InsDifficulty)
    local settingChildInsDifficulty1, _, initChildInsDifficulty1 = CheckBoxDropDown(OptionCategory, "useInsDifficultyDungeon", "InsDifficultyDungeon", "던전 난이도", "던전 난이도를 고정합니다.", difficultyTable.dungeon, true, difficultyTable.dungeon[3].value, dodo.InsDifficulty)
    local settingChildInsDifficulty2, _, initChildInsDifficulty2 = CheckBoxDropDown(OptionCategory, "useInsDifficultyRaid", "InsDifficultyRaid", "공격대 난이도", "공격대 난이도를 고정합니다.", difficultyTable.raid, true, difficultyTable.raid[3].value, dodo.InsDifficulty)
    local settingChildInsDifficulty3, _, initChildInsDifficulty3 = CheckBoxDropDown(OptionCategory, "useInsDifficultyLegacy", "InsDifficultyLegacy", "낭만 난이도", "낭만 난이도를 고정합니다.", difficultyTable.legacy, true, difficultyTable.legacy[2].value, dodo.InsDifficulty)

    if settingParentInsDifficulty then
        settingParentInsDifficulty:SetValueChangedCallback(function(_, value)
            if value == false then
                if settingChildInsDifficulty1 then settingChildInsDifficulty1:SetValue(false) end
                if settingChildInsDifficulty2 then settingChildInsDifficulty2:SetValue(false) end
                if settingChildInsDifficulty3 then settingChildInsDifficulty3:SetValue(false) end
            end
            if type(dodo.InsDifficulty) == "function" then dodo.InsDifficulty() end
        end)

        local function ParentActive() return settingParentInsDifficulty:GetValue() end
        if initChildInsDifficulty1 then initChildInsDifficulty1:SetParentInitializer(initParentInsDifficulty, ParentActive) end
        if initChildInsDifficulty2 then initChildInsDifficulty2:SetParentInitializer(initParentInsDifficulty, ParentActive) end
        if initChildInsDifficulty3 then initChildInsDifficulty3:SetParentInitializer(initParentInsDifficulty, ParentActive) end
    end

    -- 편의기능
    local QoLHeader = CreateSettingsListSectionHeaderInitializer("편의기능")
    dodoOptionLayout:AddInitializer(QoLHeader)
    Checkbox(OptionCategory, "useAuctionFilter", "경매장 필터", "경매장에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
    Checkbox(OptionCategory, "useCraftFilter", "주문제작 필터", "주문제작에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
    Checkbox(OptionCategory, "useQuickBobber", "낚시찌 장난감", "낚시버튼 옆에 낚시찌 장난감 버튼을 배치합니다.", true, dodo.quickBobber)
    local settingParentDeleteNow, initParentDeleteNow = Checkbox(OptionCategory, "deleteNowAutoFill", "\"지금파괴\" 자동기입", "아이템 파괴 확인 메시지를 자동으로 입력합니다.", true, dodo.DeleteNow)
    local settingChildDeleteNow, initChildDeleteNow = Checkbox(OptionCategory, "deleteNowHideEditbox", "아이템 파괴 간소화", "확인 메시지를 없애고 확인버튼만 남깁니다.", true, dodo.DeleteNow)
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
    dodoOptionLayout:AddInitializer(FrameScaleHeader)
    Slider(OptionCategory, "frameScale_gmf", "게임 메뉴", "게임 메뉴 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.9, "Percent", dodo.FrameScale)
    Slider(OptionCategory, "frameScale_mmbbb", "가방버튼", "가방버튼 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.7, "Percent", dodo.FrameScale)
    Slider(OptionCategory, "frameScale_th", "말머리", "말머리 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.8, "Percent", dodo.FrameScale)
    ---

    dodoOptionsCreated = true
    return OptionCategory
end

------------------------------
-- 이벤트
------------------------------
-- 애드온 로딩이 완료된 시점에 설정창을 미리 만들어둡니다.
local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("PLAYER_LOGIN")
initOptionFrame:SetScript("OnEvent", function()
    dodoCreateOptions()
end)

------------------------------
-- 명령어
------------------------------
SLASH_dodo1 = "/dd"
SLASH_dodo2 = "/ㅇㅇ"
SlashCmdList["dodo"] = function()
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    Settings.OpenToCategory(OptionCategory:GetID())
end