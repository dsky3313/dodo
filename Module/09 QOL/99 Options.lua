---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.RegisterOption("편의기능", function(category)
    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    -- ── 인터페이스 ──
    T(dodo.UI:SettingsSectionHeader(category, "인터페이스"))

    T(dodo.UI:SettingsCheckboxSlider(category, "useCameraTilt", "cameraAngle",
        "카메라 시점 조절", "카메라를 위에서 내려다보는 시점으로 조절합니다.",
        0.3, 1.0, 0.05, true, 0.55, "Decimalplaces",
        function() if dodo.CameraTilt then dodo.CameraTilt() end end))

    T(dodo.UI:SettingsCheckboxDropDown(category, "useChatbubbleFont", "chatbubbleFontPath",
        "말풍선 글꼴", "채팅 말풍선 글꼴을 변경합니다.",
        dodo.chatbubbleFontTable, true, "Fonts\\2002.TTF",
        function() if dodo.ChatBubble then dodo.ChatBubble() end end))

    T(dodo.UI:SettingsCheckboxSlider(category, "useChatbubbleFontSize", "chatbubbleFontSize",
        "말풍선 글꼴 크기", "채팅 말풍선 글꼴 크기를 조정합니다.",
        8, 20, 1, true, 10, "Integer",
        function() if dodo.ChatBubble then dodo.ChatBubble() end end))

    T(dodo.UI:SettingsCheckbox(category, "enableExpFilter", "확장팩 필터",
        "경매장/주문 제작창을 열 때 자동으로 현재 확장팩 필터를 적용합니다.",
        true, function(val)
            if dodo.UpdateExpFilter then dodo.UpdateExpFilter(val) end
        end))

    T(dodo.UI:SettingsCheckboxSlider(category, "enableFrameOption", "frameScale_th",
        "말머리 크기 변경", "대화 말머리 프레임 크기를 조정합니다.",
        0.5, 1.5, 0.1, true, 0.8, "Decimalplaces",
        function() if dodo.FrameScale then dodo.FrameScale() end end))

    T(dodo.UI:SettingsCheckbox(category, "useInsDifficultyFrame", "인스턴스 난이도",
        "인스턴스 난이도 선택 패널을 표시합니다.",
        true, function()
            if dodo.InsDifficultyUI then dodo.InsDifficultyUI() end
        end))

    -- ── 편의기능 ──
    T(dodo.UI:SettingsSectionHeader(category, "편의기능"))

    T(dodo.UI:SettingsCheckbox(category, "enableColorPicker", "색상 팔레트",
        "색상 선택기에 팔레트, 수치 입력 패널을 추가합니다.",
        true, function(checked)
            if dodo.UpdateColorPicker then dodo.UpdateColorPicker(checked) end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useDeleteNow", "아이템 파괴 간소화",
        "아이템 파괴 확인창에서 확인 입력 없이 즉시 삭제합니다.",
        true, function(val)
            if dodo.DeleteNowHooks then dodo.DeleteNowHooks(val) end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useFriends", "친구창+",
        "친구 목록에 클래스 색상 및 추가 정보를 표시합니다.",
        true, function()
            if dodo.RefreshFriends then dodo.RefreshFriends() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "enableMerchant", "자동 판매 & 수리",
        "상인 창을 열 때 잡템 판매 및 장비 자동 수리를 진행합니다.",
        true, nil))

    T(dodo.UI:SettingsCheckbox(category, "enableKeystoneModule", "쐐기돌 목록 표시",
        "파티 내 쐐기돌 목록 패널을 표시합니다.",
        true, function()
            if dodo.UpdateKeystoneModuleState then dodo.UpdateKeystoneModuleState() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useKeyRoll", "쐐기돌 굴림 알림",
        "던전 클리어 후 쐐기돌을 굴리라는 알림을 보냅니다.",
        true, nil))

    T(dodo.UI:SettingsCheckbox(category, "useQuickBobber", "낚시찌 장난감",
        "직업 창이 열려 있을 때 낚시찌 아이템 버튼을 표시합니다.",
        true, function()
            if dodo.QuickBobber then dodo.QuickBobber() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useTeleport", "던전 텔레포트 메뉴",
        "ESC 메뉴 옆에 던전 텔레포트 버튼을 표시합니다.",
        true, function()
            if dodo.ESCTeleportFrame then dodo.ESCTeleportFrame() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "enableLFGTimer", "던전찾기 타이머",
        "던전찾기 수락 팝업에 남은 시간 타이머를 표시합니다.",
        true, function()
            if dodo.UpdateLFGTimer then dodo.UpdateLFGTimer() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useWowheadLink", "와우헤드 링크",
        "퀘스트·업적 창에 와우헤드 링크 입력창을 표시합니다.",
        true, function()
            if dodo.WowheadLink then dodo.WowheadLink() end
        end))
end, 9500)

dodo.RegisterOption("편의기능.캐릭터 정보", function(category)
    dodo.UI:SettingsCheckbox(category, "enableCharacterFrame", "아이템 레벨 및 마법부여", "캐릭터창과 가방에 아이템 레벨, 마법부여, 보석 정보를 표시합니다.", true, dodo.ToggleCharacterFrame)
end, 9000)

dodo.RegisterOption("편의기능.파티모집창", function(category)
    dodo.UI:SettingsCheckbox(category, "useBrowseGroup",    "파티 탐색하기 버튼",  "파티 탐색하기 / 파티로 돌아가기 버튼을 표시합니다.", true, dodo.BrowseGroup)
    dodo.UI:SettingsCheckbox(category, "usePartyClass",     "파티 직업 및 유틸",  "파티찾기창에서 파티원 및 유틸 현황을 확인할 수 있습니다.", true, dodo.PartyClass)
    dodo.UI:SettingsCheckbox(category, "enableQuickselect", "파티만들기 빠른선택", "파티 만들기 창에서 던전 빠른선택 버튼을 표시합니다.", true, dodo.QuickSelectUpdate)
end, 9020)

dodo.RegisterOption("편의기능.NPC 대화창", function(category)
    dodo.UI:SettingsCheckbox(category, "enableGossipID",        "NPC ID 표시",     "NPC 대화창 선택지·퀘스트에 ID를 표시합니다.", true, dodo.GossipFrame.UpdateID)
    dodo.UI:SettingsCheckbox(category, "enableGossipAutoSelect", "NPC 자동 선택",   "M+ 던전 버프 NPC 대화를 자동으로 선택합니다.", true, nil)
    dodo.UI:SettingsCheckbox(category, "enableKeystoneLindormi", "린도르미 현재돌", "린도르미 NPC 대화창에 보유 쐐기돌 정보를 표시합니다.", true, dodo.GossipFrame.UpdateKeystoneLindormi)
end, 9030)

dodo.RegisterOption("편의기능.모험안내서", function(category)
    dodo.UI:SettingsCheckbox(category, "enableEJAchievements", "업적 탭 활성화", "모험 안내서에 업적 탭을 추가합니다.", true, function() end)
    dodo.UI:SettingsCheckbox(category, "enableEJID", "ID 표시", "모험 안내서에 우두머리와 능력의 ID를 표시합니다.", true, function() dodo.EJID.SetEnabled(dodoDB.enableEJID ~= false) end)
end, 9040)
