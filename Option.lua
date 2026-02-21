-- ==============================
-- 테이블 /run dodoDB = nil; ReloadUI()
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field
local addonName, dodo = ...

-- 메인
local mainCategory = Settings.RegisterVerticalLayoutCategory("dodo")
Settings.RegisterAddOnCategory(mainCategory)

-- 하위
local subCategoryGeneral = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "일반")
local subCategoryInterface = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "인터페이스")
local subCategorySound = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "음성")
local subCategoryActionbar = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "행동 단축바")
local subCategoryCombat = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "전투")
local subCategoryParty = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "파티")
local subCategorySettingProfile = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "설정 & 프로필")

------------------------------
-- 설정 생성 함수
------------------------------
function dodoCreateOptions()
    if dodoOptionsCreated then return end

    -- 일반
    local layoutGeneral = SettingsPanel:GetLayout(subCategoryGeneral)
        -- 카메라
        layoutGeneral:AddInitializer(CreateSettingsListSectionHeaderInitializer("카메라 시점"))
        Slider(subCategoryGeneral, "cameraBase", "기본 시점", "기본시점 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 1, "Decimal2", dodo.CameraTilt)
        Slider(subCategoryGeneral, "cameraDown", "탑다운 뷰", "수직으로 내렸을 때 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 1, "Decimal2", dodo.CameraTilt)
        Slider(subCategoryGeneral, "cameraFlying", "하늘비행 탈것 시점", "하늘비행 탈것 탑승 시 각도를 조절합니다.\n\n|cffaaffaa기본 : 1.0|r", 0.3, 1.0, 0.05, 1, "Decimal2", dodo.CameraTilt)

    -- 인터페이스
    local layoutInterface = SettingsPanel:GetLayout(subCategoryInterface)
        -- 글꼴 섹션
        layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("글꼴"))
        DropDown(subCategoryInterface, "chatbubbleFontPath", "말풍선 글꼴", "말풍선에 적용할 글꼴를 선택하세요.", chatbubbleFontTable, chatbubbleFontTable[1].value, dodo.ChatBubble)
        Slider(subCategoryInterface, "chatbubbleFontSize", "말풍선 글꼴 크기", "말풍선 글꼴 크기를 변경합니다.", 8, 14, 1, 10, "Integer", dodo.ChatBubble)
        -- 편의기능 섹션
        layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("편의기능"))
        Checkbox(subCategoryInterface, "useAuctionFilter", "경매장 필터", "경매장에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
        Checkbox(subCategoryInterface, "useCraftFilter", "주문제작 필터", "주문제작에서 '현행 확장팩 전용'을 자동 활성화합니다.", true, dodo.expFilter)
        Checkbox(subCategoryInterface, "useQuickBobber", "낚시찌 장난감", "낚시버튼 옆에 낚시찌 장난감 버튼을 배치합니다.", true, dodo.quickBobber)
        local settingParentDeleteNow, initParentDeleteNow = Checkbox(subCategoryInterface, "deleteNowAutoFill", "\"지금파괴\" 자동기입", "아이템 파괴 확인 메시지를 자동으로 입력합니다.", true, dodo.DeleteNow)
        local settingChildDeleteNow, initChildDeleteNow = Checkbox(subCategoryInterface, "deleteNowHideEditbox", "아이템 파괴 간소화", "확인 메시지를 없애고 확인버튼만 남깁니다.", true, dodo.DeleteNow)
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
        Checkbox(subCategoryInterface, "useTeleport", "던전 텔레포트 버튼", "게임메뉴 옆에 텔레포트 버튼을 표시합니다.", true, dodo.ESCTeleportFrame)

        -- 프레임 크기
        layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("프레임 크기"))
        Slider(subCategoryInterface, "frameScale_gmf", "게임 메뉴", "게임 메뉴 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.9, "Percent", dodo.FrameScale)
        Slider(subCategoryInterface, "frameScale_mmbbb", "가방버튼", "가방버튼 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.7, "Percent", dodo.FrameScale)
        Slider(subCategoryInterface, "frameScale_th", "말머리", "말머리 크기를 조절합니다.", 0.5, 1.5, 0.1, 0.8, "Percent", dodo.FrameScale)

        -- 프레임 크기
        layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("미니맵"))
        Checkbox(subCategoryInterface, "useResetMinimapZoom", "미니맵 줌 리셋", "미니맵 줌 리셋", true, dodo.useResetMinimapZoom)

    -- 음성
    local layoutSound = SettingsPanel:GetLayout(subCategorySound)
        -- 출력 장치 동기화
        layoutSound:AddInitializer(CreateSettingsListSectionHeaderInitializer("출력장치"))
        Checkbox(subCategorySound, "useAudioSync", "출력장치 동기화", "출력장치 동기화.", false, dodo.audioSync)

    -- 행동 단축바
    -- local layoutActionbar = SettingsPanel:GetLayout(subCategoryActionbar)
    --     layoutActionbar:AddInitializer(CreateSettingsListSectionHeaderInitializer("행동 단축바 간격"))
    --     Slider(subCategoryActionbar, "actionBarPadding", "버튼 간격", "간격을 조절합니다.", 0, 10, 1, 2, "Integer", dodo.UpdateBarPadding)

    -- 전투
    local layoutCombat = SettingsPanel:GetLayout(subCategoryCombat)
        -- 자원바
        layoutCombat:AddInitializer(CreateSettingsListSectionHeaderInitializer("자원바 표시"))
        Checkbox(subCategoryCombat, "useResourceBar1", "플레이어 자원바", "플레이어 마나/분노 표시 바를 활성화합니다.", true, dodo.ResourceBar1)
        Checkbox(subCategoryCombat, "useResourceBar2", "버프 추적 바", "특성에 따른 버프 추적 바를 활성화합니다.", true, dodo.ResourceBar2)

    -- 파티
    local layoutParty = SettingsPanel:GetLayout(subCategoryParty)
        layoutParty:AddInitializer(CreateSettingsListSectionHeaderInitializer("파티"))
        Checkbox(subCategoryParty, "useBrowseGroup", "파티 탐색하기 버튼", "파티원일 경우에도 '파티 탐색하기' 버튼을 표시합니다.", true, dodo.browseGroupsButton)
        Checkbox(subCategoryParty, "useKeyRoll", "쐐기돌 굴림 알림", "쐐기 완료 후, 파티원의 돌목록과 돌변경 알림을 띄웁니다.", true, dodo.KeyRoll)
        Checkbox(subCategoryParty, "usePartyClass", "클래스 현황", "파티원의 유틸 현황을 확인할 수 있습니다.", true, dodo.PartyClass)

        local settingParentNewLFG, _, initParentNewLFG = CheckBoxDropDown(subCategoryParty, "useNewLFG", "soundID", "파티신청 알림", "새로운 파티신청 시 알림", newLFG_AlertSoundTable, true, newLFG_AlertSoundTable[2].value, dodo.NewLFG)
        local settingChildNewLFG, initChildNewLFG = Checkbox(subCategoryParty, "useNewLFGLeader", "파티원 기능 활성화", "파티장원일 경우에도 활성화합니다. ", false, dodo.NewLFG)
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

        -- 인스 난이도
        layoutParty:AddInitializer(CreateSettingsListSectionHeaderInitializer("인스턴스 난이도"))
        local settingParentInsDifficulty, initParentInsDifficulty = Checkbox(subCategoryParty, "useInsDifficulty", "인스 난이도 고정", "솔플 혹은 파티장일 시, 던전 난이도를 자동으로 변경합니다.", true, dodo.InsDifficulty)
        local settingChildInsDifficulty1, _, initChildInsDifficulty1 = CheckBoxDropDown(subCategoryParty, "useInsDifficultyDungeon", "InsDifficultyDungeon", "던전 난이도", "던전 난이도를 고정합니다.", difficultyTable.dungeon, true, difficultyTable.dungeon[3].value, dodo.InsDifficulty)
        local settingChildInsDifficulty2, _, initChildInsDifficulty2 = CheckBoxDropDown(subCategoryParty, "useInsDifficultyRaid", "InsDifficultyRaid", "공격대 난이도", "공격대 난이도를 고정합니다.", difficultyTable.raid, true, difficultyTable.raid[3].value, dodo.InsDifficulty)
        local settingChildInsDifficulty3, _, initChildInsDifficulty3 = CheckBoxDropDown(subCategoryParty, "useInsDifficultyLegacy", "InsDifficultyLegacy", "낭만 난이도", "낭만 난이도를 고정합니다.", difficultyTable.legacy, true, difficultyTable.legacy[2].value, dodo.InsDifficulty)
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

    -- 설정 & 프로필
    local layoutSettingProfile = SettingsPanel:GetLayout(subCategorySettingProfile)
        -- 이름표
        layoutSettingProfile:AddInitializer(CreateSettingsListSectionHeaderInitializer("이름표"))
        Checkbox(subCategorySettingProfile, "useNameplateFriendly", "아군 이름표 자동 설정", "아군 이름표에 클래스 색상을 적용하고 이름만 표시합니다.", true, dodo.nameplateFriendly)

    dodoOptionsCreated = true
end

-- ==============================
-- 이벤트
-- ==============================
local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("ADDON_LOADED")
initOptionFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        self:RegisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGIN" then
        if dodoCreateOptions then dodoCreateOptions() end
    end
end)

-- ==============================
-- 명령어
-- ==============================
SLASH_dodo1 = "/dd"
SLASH_dodo2 = "/ㅇㅇ"
SlashCmdList["dodo"] = function()
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    Settings.OpenToCategory(mainCategory:GetID())
end