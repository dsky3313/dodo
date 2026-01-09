------------------------------
-- 테이블
------------------------------
-- OptionCategory = OptionCategory or nil
-- hodoOptionLayout = hodoOptionLayout or nil
------------------------------
-- 설정창
------------------------------
function hodoCreateOptions()
    if not hodoOptionCategoryRegistered then -- 중복 등록 방지
        OptionCategory, hodoOptionLayout = Settings.RegisterVerticalLayoutCategory("1hodo") -- 카테고리 등록 및 레이아웃 가져오기
        Settings.RegisterAddOnCategory(OptionCategory)
        hodoOptionCategoryRegistered = true
    end

    if not hodoOptionLayout and OptionCategory then
        hodoOptionLayout = SettingsPanel:GetLayout(OptionCategory)
    end

    if not hodoOptionLayout then
        return
    end

    if hodoOptionsCreated then
        return OptionCategory
    end


    ------------------------------
    -- 설정값
    ------------------------------
    -- 경매장
    local AuctionFilterHeader = CreateSettingsListSectionHeaderInitializer("경매장 및 주문제작")
    hodoOptionLayout:AddInitializer(AuctionFilterHeader)
    Checkbox(OptionCategory, "useAuctionFilter", "경매장 필터", "경매장 메뉴에서 '현행 확장팩 전용'을 활성화합니다.", true)
    Checkbox(OptionCategory, "useCraftFilter", "주문제작 필터", "주문제작 메뉴에서 '현행 확장팩 전용'을 활성화합니다.", true)

    -- 말풍선
    local ChatbubbleHeader = CreateSettingsListSectionHeaderInitializer("말풍선")
    hodoOptionLayout:AddInitializer(ChatbubbleHeader)
    DropDown(OptionCategory, "CB_FontPath", "말풍선 글꼴", "원하는 폰트를 선택하세요.", FontOption, FontOption[1].value)
    Slider(OptionCategory, "CB_FontSize", "글꼴 크기", "설명", 8, 14, 1, 10, "Integer")

    -- 인스턴스 난이도
    local InsDifficultyHeader = CreateSettingsListSectionHeaderInitializer("인스턴스 난이도")
    hodoOptionLayout:AddInitializer(InsDifficultyHeader)
    CheckBoxDropDown(OptionCategory, "useInsDifficultyDungeon", "InsDifficultyDungeon", "던전 난이도", "파티장일 시, 해당 난이도로 자동 변경합니다.", difficultyTable.dungeon, true, "23")
    CheckBoxDropDown(OptionCategory, "useInsDifficultyRaid", "InsDifficultyRaid", "공격대 난이도", "파티장이 되면 공격대 난이도를 자동으로 변경합니다.", difficultyTable.raid, true, "16")
    CheckBoxDropDown(OptionCategory, "useInsDifficultyLegacy", "InsDifficultyLegacy", "낭만 공격대 규모", "공격대 인원 및 이전 확장팩 난이도를 설정합니다.", difficultyTable.legacy, true, "4")

    -- 지금삭제
    local DeleteNowHeader = CreateSettingsListSectionHeaderInitializer("지금삭제")
    hodoOptionLayout:AddInitializer(DeleteNowHeader)
    local parentSetting, parentInit = Checkbox(OptionCategory, "DeleteNow", "삭제 간소화", "아이템 삭제 과정을 간소화합니다.", true)
    local childSetting, childInit = Checkbox(OptionCategory, "DeleteNowEditbox", "'지금삭제' 자동 기입 모드", "문구를 자동으로 입력합니다.", false)
        if parentInit and childInit then
            local function IsModifiable()
                return parentSetting:GetValue(); -- 부모가 체크되어 있으면 true 반환
            end
            childInit:SetParentInitializer(parentInit, IsModifiable)
        end

    -- 파티 편의기능
    local PartyQoLHeader = CreateSettingsListSectionHeaderInitializer("파티 편의기능")
    hodoOptionLayout:AddInitializer(PartyQoLHeader)
    Checkbox(OptionCategory, "useMyKey", "내돌", "파티 제목란에 돌을 보여줍니다.", true)
    local parentSetting, parentInit = CheckBoxDropDown(OptionCategory, "useNewLFG", "NewLFG_AlertSoundTableID", "파티 신청 알림", "신규 파티 신청자가 있을 때,\n알림 메시지와 선택한 소리를 재생합니다.", NewLFG_AlertSoundTable, true, "5274")
    local childSetting, childInit = Checkbox(OptionCategory, "NewLFG_LeaderOnly", "파티장 일때 활성화", "본인이 파티장일 시 기능 활성화.", true)
        if parentInit and childInit then
            local function IsModifiable()
                return parentSetting:GetValue();
            end
            childInit:SetParentInitializer(parentInit, IsModifiable)
        end
    Checkbox(OptionCategory, "usePartyClass", "파티 클래스 현황 표시", "유틸리티 보유 현황을 PVE 프레임 옆에 표시합니다.", true)

    -- 카메라
    local CameraTiltHeader = CreateSettingsListSectionHeaderInitializer("카메라 ")
    hodoOptionLayout:AddInitializer(CameraTiltHeader)
    CheckboxSlider(OptionCategory, "useCameraBase", "CameraBase", "카메라 시점", "카메라 기능을 활성화하고 기본 높이를 조절합니다.", 0.05, 1.0, 0.05, true, 0.55, "Percent")
    CheckboxSlider(OptionCategory, "useCameraDown", "CameraDown", "수직 시점", "내려다 봤을 때의 시점을 조절합니다.", 0.05, 1.0, 0.05, true, 0.55, "Percent")
    CheckboxSlider(OptionCategory, "useCameraFlying", "CameraFlying", "날탈 시점", "날탈 시점을 조절합니다.", 0.05, 1.0, 0.05, true, 0.55, "Percent")

    -- 프레임 스케일
    local FrameScaleHeader = CreateSettingsListSectionHeaderInitializer("프레임 크기")
    hodoOptionLayout:AddInitializer(FrameScaleHeader)
    Slider(OptionCategory, "FrameScale_GM", "게임 메뉴 크기", "ESC 메뉴의 크기를 조절합니다.", 0.5, 1.0, 0.05, 0.9, "Percent")
    Slider(OptionCategory, "FrameScale_TH", "말머리 크기", "말머리 대화창의 크기를 조절합니다.", 0.5, 1.0, 0.05, 0.8, "Percent")
    Slider(OptionCategory, "FrameScale_MMBBB", "가방 크기", "가방의 크기를 조절합니다.", 0.5, 1.0, 0.05, 0.65, "Percent")


    -- -- 텔레포트
    -- local TeleportHeader = CreateSettingsListSectionHeaderInitializer("텔레포트")
    -- hodolayout:AddInitializer(TeleportHeader)
    -- -- 인스 밝기
    -- local InsBrightHeader = CreateSettingsListSectionHeaderInitializer("인스 밝기")
    -- hodolayout:AddInitializer(InsBrightHeader)

    hodoOptionsCreated = true
    return OptionCategory
end


------------------------------
-- 명령어
------------------------------
SLASH_hodo1 = "/hh"
SLASH_hodo2 = "/ㅗㅗ"
SlashCmdList["hodo"] = function()
    if InCombatLockdown() then
        print("|cffff00001hodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end

    SettingsPanel:Show()
    local categories = SettingsPanel:GetCategoryList().allCategories
    for _, category in ipairs(categories) do
        if category == OptionCategory or category:GetName() == "1hodo" then
            SettingsPanel:SelectCategory(category)
            break
        end
    end
end