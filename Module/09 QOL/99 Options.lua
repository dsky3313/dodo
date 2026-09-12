---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.QOL_DEFAULTS = {
    enableQOL             = true,
    useCameraTilt         = true,  cameraAngle          = 0.65,
    useCameraMaxZoom      = true,  cameraMaxZoom        = 2.6,
    useChatbubbleFont     = true,  chatbubbleFontPath   = "Fonts\\2002.TTF",
    useChatbubbleFontSize = true,  chatbubbleFontSize   = 10,
    enableExpFilter       = true,
    enableFrameOption     = true,  frameScale_th        = 0.8,
    useInsDifficultyFrame = true,
    enableColorPicker     = true,
    useDeleteNow          = true,
    useFriends            = true,
    enableMerchant        = true,
    enableKeystoneModule  = true,
    useKeyRoll            = true,
    useCinematicSkip      = true,
    useQuickBobber        = true,
    useTeleport           = true,
    enableLFGTimer        = true,
    useWorldMapCoords     = true,
    enableWorldMapIcon    = true,
    useWowheadLink        = true,
    enableCharacterFrame  = true,
    useBrowseGroup        = true,  usePartyClass        = true,  enableQuickselect     = true,
    enableGossipID        = true,  enableGossipAutoSelect = true, enableKeystoneLindormi = true,
    enableEJAchievements  = true,  enableEJID           = true,
}

dodo.RegisterOption("편의기능", function(category)
    local D = dodo.QOL_DEFAULTS
    local sub = {}
    local function T(v) if v then sub[#sub+1] = v end return v end

    local _, master = dodo.UI:SettingsCheckbox(category, "enableQOL", "편의기능 모듈",
        "편의기능 모듈을 활성화합니다.",
        D.enableQOL, function(val)
            if dodoDB then dodoDB.enableQOL = val end
        end)

    -- 캐릭터 정보
    T(dodo.UI:SettingsSectionHeader(category, "캐릭터 정보"))
    T(dodo.UI:SettingsCheckbox(category, "enableCharacterFrame", "아이템 레벨 및 마법부여",
        "캐릭터창과 가방에 아이템 레벨, 마법부여, 보석 정보를 표시합니다.",
        D.enableCharacterFrame, dodo.ToggleCharacterFrame))

    -- 쐐기돌
    T(dodo.UI:SettingsSectionHeader(category, "쐐기돌"))
    T(dodo.UI:SettingsCheckbox(category, "useInsDifficultyFrame", "인스턴스 난이도",
        "인스턴스 난이도 선택 패널을 표시합니다.",
        D.useInsDifficultyFrame, function()
            if dodo.InsDifficultyUI then dodo.InsDifficultyUI() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "enableKeystoneTimer", "쐐기 타이머 개선",
        "+2/+3 쐐기돌 타이머를 표시하고, 퍼센트를 소수점까지 표시합니다.",
        true, function(val)
            if dodoDB then
                dodoDB.enableKeystoneTimer = val
                dodoDB.useKeystoneTimerBarStyle = val
                dodoDB.useKeystoneTimerPercent = val
                dodoDB.useKeystoneTimerTick = val
            end
            if dodo.KeystoneTimerUpdateVisual then dodo.KeystoneTimerUpdateVisual() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "enableChallengesAutoInsert", "쐐기돌 자동 삽입",
        "쐐기돌을 자동으로 슬롯에 삽입합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableChallengesAutoInsert = val end
            if dodo.InsertKeystoneUpdateVisual then dodo.InsertKeystoneUpdateVisual() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "enableKeystoneModule", "쐐기돌 목록 표시",
        "파티 내 쐐기돌 목록 패널을 표시합니다.",
        D.enableKeystoneModule, function()
            if dodo.UpdateKeystoneModuleState then dodo.UpdateKeystoneModuleState() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useKeyRoll", "쐐기돌 굴림 알림",
        "던전 클리어 후 쐐기돌을 굴리라는 알림을 보냅니다.",
        D.useKeyRoll, nil))
    T(dodo.UI:SettingsCheckbox(category, "enableReadyCheckTimer", "전투준비 타이머",
        "전투 준비 확인 시, 남은 시간 바를 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableReadyCheckTimer = val end
            if dodo.ReadyCheckTimerUpdateVisual then dodo.ReadyCheckTimerUpdateVisual() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useCinematicSkip", "시네마틱 건너뛰기",
        "쐐기 중, 시네마틱을 자동으로 건너뜁니다.",
        D.useCinematicSkip, nil))

    T(dodo.UI:SettingsCheckbox(category, "enableCollapse", "퀘스트 목록 접기",
        "인스턴스 진입 시 퀘스트 목록을 자동으로 접습니다.",
        true, function(val)
            if dodoDB then dodoDB.enableCollapse = val end
            if dodo.CollapseUpdateVisual then dodo.CollapseUpdateVisual() end
        end))

    -- 파티모집창
    T(dodo.UI:SettingsSectionHeader(category, "파티모집창"))
    T(dodo.UI:SettingsCheckbox(category, "useBrowseGroup", "파티 탐색하기 버튼",
        "파티 탐색하기 / 파티로 돌아가기 버튼을 표시합니다.", D.useBrowseGroup, dodo.BrowseGroup))
    T(dodo.UI:SettingsCheckbox(category, "usePartyClass", "파티 직업 및 유틸",
        "파티찾기창에서 파티원 및 유틸 현황을 확인할 수 있습니다.", D.usePartyClass, dodo.PartyClass))
    T(dodo.UI:SettingsCheckbox(category, "enableQuickselect", "파티만들기 빠른선택",
        "파티 만들기 창에서 던전 빠른선택 버튼을 표시합니다.", D.enableQuickselect, dodo.QuickSelectUpdate))

    -- NPC 대화창
    T(dodo.UI:SettingsSectionHeader(category, "NPC 대화창"))
    T(dodo.UI:SettingsCheckbox(category, "enableGossipID", "NPC ID 표시",
        "NPC 대화창 선택지·퀘스트에 ID를 표시합니다.", D.enableGossipID, dodo.GossipFrame.UpdateID))
    T(dodo.UI:SettingsCheckbox(category, "enableGossipAutoSelect", "NPC 자동 선택",
        "M+ 던전 버프 NPC 대화를 자동으로 선택합니다.", D.enableGossipAutoSelect, nil))
    T(dodo.UI:SettingsCheckbox(category, "enableKeystoneLindormi", "린도르미 현재돌",
        "린도르미 NPC 대화창에 보유 쐐기돌 정보를 표시합니다.", D.enableKeystoneLindormi, dodo.GossipFrame.UpdateKeystoneLindormi))

    -- 모험안내서
    T(dodo.UI:SettingsSectionHeader(category, "모험안내서"))
    T(dodo.UI:SettingsCheckbox(category, "enableEJAchievements", "업적 탭 활성화",
        "모험 안내서에 업적 탭을 추가합니다.", D.enableEJAchievements, function() end))
    T(dodo.UI:SettingsCheckbox(category, "enableEJID", "ID 표시",
        "모험 안내서에 우두머리와 능력의 ID를 표시합니다.", D.enableEJID,
        function() dodo.EJID.SetEnabled(dodoDB.enableEJID ~= false) end))

    -- 편의기능
    T(dodo.UI:SettingsSectionHeader(category, "편의기능"))
    local _cb1, _sl1, _init1 = dodo.UI:SettingsCheckboxSlider(category, "useCameraTilt", "cameraAngle",
        "시점 조절", "카메라의 상하 시점을 조절합니다.",
        0.3, 1.0, 0.05, D.useCameraTilt, D.cameraAngle, "Decimalplaces",
        function() if dodo.CameraTilt then dodo.CameraTilt() end end)
    T(_init1)
    local _cb2, _sl2, _init2 = dodo.UI:SettingsCheckboxSlider(category, "useCameraMaxZoom", "cameraMaxZoom",
        "최대 줌", "카메라 줌아웃 최대 거리를 조정합니다.",
        1.0, 2.6, 0.1, D.useCameraMaxZoom, D.cameraMaxZoom, "Decimal1",
        function() if dodo.CameraMaxZoom then dodo.CameraMaxZoom() end end)
    T(_init2)
    local _cb3, _dd3, _init3 = dodo.UI:SettingsCheckboxDropDown(category, "useChatbubbleFont", "chatbubbleFontPath",
        "말풍선 글꼴", "말풍선 글꼴을 변경합니다.",
        dodo.chatbubbleFontTable, D.useChatbubbleFont, D.chatbubbleFontPath,
        function() if dodo.ChatBubble then dodo.ChatBubble() end end)
    T(_init3)
    local _cb4, _sl4, _init4 = dodo.UI:SettingsCheckboxSlider(category, "useChatbubbleFontSize", "chatbubbleFontSize",
        "말풍선 글꼴 크기", "말풍선 글꼴 크기를 조정합니다.",
        8, 20, 1, D.useChatbubbleFontSize, D.chatbubbleFontSize, "Integer",
        function() if dodo.ChatBubble then dodo.ChatBubble() end end)
    T(_init4)
    T(dodo.UI:SettingsCheckbox(category, "enableColorPicker", "색상 선택기 개선",
        "색상 선택기에 팔레트, 수치 입력 칸을 추가합니다.",
        D.enableColorPicker, function(checked)
            if dodo.UpdateColorPicker then dodo.UpdateColorPicker(checked) end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useDeleteNow", "아이템 파괴 간소화",
    "아이템 파괴 확인창에서 '지금파괴' 입력을 간소화 합니다.",
        D.useDeleteNow, function(val)
            if dodo.DeleteNowHooks then dodo.DeleteNowHooks(val) end
        end))
    local _cb5, _sl5, _init5 = dodo.UI:SettingsCheckboxSlider(category, "enableFrameOption", "frameScale_th",
        "말머리 크기 변경", "대화 말머리 프레임 크기를 조정합니다.",
        0.5, 1.5, 0.1, D.enableFrameOption, D.frameScale_th, "Decimalplaces",
        function() if dodo.FrameScale then dodo.FrameScale() end end)
    T(_init5)
    T(dodo.UI:SettingsCheckbox(category, "useFriends", "친구창 개선",
        "친구 목록에 클래스 색상 및 추가 정보를 표시합니다.",
        D.useFriends, function()
            if dodo.RefreshFriends then dodo.RefreshFriends() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "enableMerchant", "자동 판매 & 수리",
        "상인 창을 열 때, 잡템 판매 및 장비 자동 수리를 진행합니다.",
        D.enableMerchant, nil))
    T(dodo.UI:SettingsCheckbox(category, "useQuickBobber", "낚시찌 장난감",
        "낚시 아이콘 (전문기술) 옆에 낚시찌 아이템 버튼을 표시합니다.",
        D.useQuickBobber, function()
            if dodo.QuickBobber then dodo.QuickBobber() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useTeleport", "던전 텔레포트 메뉴",
        "ESC 메뉴에 순간이동 버튼을 표시합니다.",
        D.useTeleport, function()
            if dodo.ESCTeleportFrame then dodo.ESCTeleportFrame() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "enableLFGTimer", "던전찾기 타이머",
        "던전찾기 수락창에 남은 시간을 표시합니다.",
        D.enableLFGTimer, function()
            if dodo.UpdateLFGTimer then dodo.UpdateLFGTimer() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useWorldMapCoords", "월드맵 좌표",
        "월드맵에 커서/플레이어 좌표와 맵 ID를 표시합니다.",
        D.useWorldMapCoords, nil))
    T(dodo.UI:SettingsCheckbox(category, "enableWorldMapIcon", "월드맵 커스텀 아이콘",
        "월드맵에 경매장, 은행 등 커스텀 아이콘을 표시합니다.",
        D.enableWorldMapIcon, function(val)
            if dodo.WorldMapIconUpdateVisual then dodo.WorldMapIconUpdateVisual() end
        end))
    T(dodo.UI:SettingsCheckbox(category, "useWowheadLink", "와우헤드 링크",
        "퀘스트,업적 창 하단에 와우헤드 링크 입력창을 표시합니다.",
        D.useWowheadLink, function()
            if dodo.WowheadLink then dodo.WowheadLink() end
        end))

    local function _shown() return master:GetValue() end
    for _, w in ipairs(sub) do if w.AddShownPredicate then w:AddShownPredicate(_shown) end end
end, 9010)

--[[ Didnt use
    T(dodo.UI:SettingsCheckbox(category, "enableExpFilter", "확장팩 필터",
        "경매장/주문 제작창을 열 때 자동으로 현재 확장팩 필터를 적용합니다.",
        D.enableExpFilter, function(val)
            if dodo.UpdateExpFilter then dodo.UpdateExpFilter(val) end
        end))
]]