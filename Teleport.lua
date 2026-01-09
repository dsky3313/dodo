------------------------------
-- 테이블
------------------------------

local expTable = {
    { category = "Classic", name = "오리지널", iconID = 135763 },
    { category = "BC", name = "불성", iconID = 135760 },
    { category = "WoL", name = "리분", iconID = 237509 },
    { category = "CATA", name = "대격변", iconID = 462340 },
    { category = "MoP", name = "판다", iconID = 851298 },
    { category = "WoD", name = "드레노어", iconID = 1535376 },
    { category = "Legion", name = "군단", iconID = 1535374 },
    { category = "BfA", name = "격아", iconID = 2176535 },
    { category = "SL", name = "어둠땅", iconID = 3847780 },
    { category = "DF", name = "용군단", iconID = 4661645 },
    { category = "TWW", name = "내부전쟁", iconID = 5901551 },
    { category = "ETC", name = "기타", iconID = 132311 },
}

local teleportTable = {
    -- Classic
    { spellID = 18984, type = "item", iconID = 133873, category = "Classic", name = "기공 얼" },
    { spellID = 18986, type = "item", iconID = 133870, category = "Classic", name = "기공 호" },

    -- BC
    { spellID = 151016, type = "item", iconID = 133731, category = "BC", name = "검사" },
    { spellID = 30544, type = "item", iconID = 321487, category = "BC", name = "기공 얼" },
    { spellID = 30542, type = "item", iconID = 133865, category = "BC", name = "기공 호" },

    -- WoL
    { spellID = 48933, type = "item", iconID = 135778, category = "WoL", name = "기공" },

    -- CATA
    { spellID = 410080, type = "spell", iconID = 409599, category = "CATA", name = "소용돌이" },
    { spellID = 424142, type = "spell", iconID = 409600, category = "CATA", name = "파도" },
    { spellID = 445424, type = "spell", iconID = 409596, category = "CATA", name = "그림바톨" },

    -- MoP
    { spellID = 87215, type = "item", iconID = 651094, category = "MoP", name = "기공" },
    { spellID = 131204, type = "spell", iconID = 603529, category = "MoP", name = "옥룡사" },
    { spellID = 131205, type = "spell", iconID = 594272, category = "MoP", name = "Stormstout Brewery" },
    { spellID = 131206, type = "spell", iconID = 603795, category = "MoP", name = "Shado-Pan Monastery" },
    { spellID = 131222, type = "spell", iconID = 615499, category = "MoP", name = "Mogu'shan Palace" },
    { spellID = 131225, type = "spell", iconID = 603962, category = "MoP", name = "Gate of the Setting Sun" },
    { spellID = 131228, type = "spell", iconID = 615986, category = "MoP", name = "Siege of Niuzao Temple" },
    { spellID = 131229, type = "spell", iconID = 135955, category = "MoP", name = "Scarlet Monastery" },
    { spellID = 131231, type = "spell", iconID = 133154, category = "MoP", name = "Scarlet Halls" },
    { spellID = 131232, type = "spell", iconID = 135974, category = "MoP", name = "Scholomance" },

    -- WoD
    { spellID = 112059, type = "item", iconID = 892831, category = "WoD", name = "기공" },
    { spellID = 159901, type = "spell", iconID = 1052644, category = "WoD", name = "상록숲" },
    { spellID = 159899, type = "spell", iconID = 1002600, category = "WoD", name = "어둠달" },
    { spellID = 159900, type = "spell", iconID = 1002598, category = "WoD", name = "정비소" },
    { spellID = 159896, type = "spell", iconID = 1003154, category = "WoD", name = "선착장" },
    { spellID = 159895, type = "spell", iconID = 1002599, category = "WoD", name = "Bloodmaul Slag Mines" },
    { spellID = 159897, type = "spell", iconID = 1002597, category = "WoD", name = "Auchindoun" },
    { spellID = 159898, type = "spell", iconID = 1002596, category = "WoD", name = "Skyreach" },
    { spellID = 159902, type = "spell", iconID = 1002601, category = "WoD", name = "Upper Blackrock Spire" },

    -- Legion
    { spellID = 151652, type = "item", iconID = 237560, category = "Legion", name = "기공" },
    { spellID = 393764, type = "spell", iconID = 1417427, category = "Legion", name = "용맹" },
    { spellID = 410078, type = "spell", iconID = 1417429, category = "Legion", name = "넬둥" },
    { spellID = 393766, type = "spell", iconID = 1417424, category = "Legion", name = "별궁" },
    { spellID = 373262, type = "spell", iconID = 1530372, category = "Legion", name = "카라잔" },
    { spellID = 424153, type = "spell", iconID = 1417423, category = "Legion", name = "검떼" },
    { spellID = 424163, type = "spell", iconID = 1417425, category = "Legion", name = "어숲" },

    -- BfA
    { spellID = 168807, type = "item", iconID = 2000841, category = "BfA", name = "기공 얼" },
    { spellID = 168808, type = "item", iconID = 2000840, category = "BfA", name = "기공 호" },
    { spellID = 410071, type = "spell", iconID = 2011112, category = "BfA", name = "자유지대" },
    { spellID = 410074, type = "spell", iconID = 2011151, category = "BfA", name = "썩은굴" },
    { spellID = 373274, type = "spell", iconID = 3024540, category = "BfA", name = "메카곤" },
    { spellID = 424167, type = "spell", iconID = 2011154, category = "BfA", name = "저택" },
    { spellID = 424187, type = "spell", iconID = 2011105, category = "BfA", name = "아탈" },
    { spellID = 445418, type = "spell", iconID = 2011139, category = "BfA", name = "보랄", faction = "Alliance" },
    { spellID = 464256, type = "spell", iconID = 2011139, category = "BfA", name = "보랄", faction = "Horde" },
    { spellID = 467553, type = "spell", iconID = 2011121, category = "BfA", name = "왕노", faction = "Alliance" },
    { spellID = 467555, type = "spell", iconID = 2011121, category = "BfA", name = "왕노", faction = "Horde" },

    -- SL
    { spellID = 172924, type = "item", iconID = 3610528, category = "SL", name = "기공" },
    { spellID = 354462, type = "spell", iconID = 3601560, category = "SL", name = "죽상" },
    { spellID = 354463, type = "spell", iconID = 3601535, category = "SL", name = "역병" },
    { spellID = 354464, type = "spell", iconID = 3601531, category = "SL", name = "티르너", isSeason = true },
    { spellID = 354465, type = "spell", iconID = 3601526, category = "SL", name = "속죄", isSeason = true },
    { spellID = 354466, type = "spell", iconID = 3601545, category = "SL", name = "승천" },
    { spellID = 354467, type = "spell", iconID = 3601550, category = "SL", name = "고투" },
    { spellID = 354468, type = "spell", iconID = 3601561, category = "SL", name = "저편" },
    { spellID = 354469, type = "spell", iconID = 3601540, category = "SL", name = "핏빛" },
    { spellID = 367416, type = "spell", iconID = 4062727, category = "SL", name = "타자베쉬" },
    { spellID = 373190, type = "spell", iconID = 3614361, category = "SL", name = "나스리아" },
    { spellID = 373191, type = "spell", iconID = 4062765, category = "SL", name = "지배" },
    { spellID = 373192, type = "spell", iconID = 4254074, category = "SL", name = "태존매" },

    -- DF
    { spellID = 198156, type = "item", iconID = 4548860, category = "DF", name = "기공" },
    { spellID = 393262, type = "spell", iconID = 4578413, category = "DF", name = "노쿠드" },
    { spellID = 393267, type = "spell", iconID = 4578412, category = "DF", name = "담쟁이" },
    { spellID = 393273, type = "spell", iconID = 4578414, category = "DF", name = "대학" },
    { spellID = 393256, type = "spell", iconID = 4578416, category = "DF", name = "루비" },
    { spellID = 393276, type = "spell", iconID = 4578417, category = "DF", name = "넬타" },
    { spellID = 393279, type = "spell", iconID = 4578411, category = "DF", name = "보관소" },
    { spellID = 393283, type = "spell", iconID = 4578415, category = "DF", name = "주입" },
    { spellID = 393222, type = "spell", iconID = 4578418, category = "DF", name = "울다만" },
    { spellID = 424197, type = "spell", iconID = 5247561, category = "DF", name = "여명" },
    { spellID = 432254, type = "spell", iconID = 4630363, category = "DF", name = "금고" },
    { spellID = 432257, type = "spell", iconID = 5161748, category = "DF", name = "아베루스" },
    { spellID = 432258, type = "spell", iconID = 5342929, category = "DF", name = "아미드랏실" },

    -- TWW
    { spellID = 221966, type = "item", iconID = 4548859, category = "TWW", name = "기공" },
    { spellID = 445269, type = "spell", iconID = 5899333, category = "TWW", name = "바금" },
    { spellID = 445443, type = "spell", iconID = 5899332, category = "TWW", name = "부화장" },
    { spellID = 445414, type = "spell", iconID = 5899330, category = "TWW", name = "새인호", isSeason = true },
    { spellID = 445444, type = "spell", iconID = 5899331, category = "TWW", name = "수도원", isSeason = true },
    { spellID = 1216786, type = "spell", iconID = 6392629, category = "TWW", name = "수문", isSeason = true },
    { spellID = 445416, type = "spell", iconID = 5899328, category = "TWW", name = "실타래" },
    { spellID = 445417, type = "spell", iconID = 5899326, category = "TWW", name = "아라카라", isSeason = true },
    { spellID = 445440, type = "spell", iconID = 5899327, category = "TWW", name = "양조장" },
    { spellID = 445441, type = "spell", iconID = 5899329, category = "TWW", name = "어불동" },
    { spellID = 1237215, type = "spell", iconID = 6921877, category = "TWW", name = "알다니", isSeason = true },
    { spellID = 1226482, type = "spell", iconID = 6392630, category = "TWW", name = "언더마인" },
    { spellID = 1239155, type = "spell", iconID = 6997112, category = "TWW", name = "마괴종" },

    -- ETC
    { spellID = 1233637, type = "macro", iconID = 409599, category = "ETC", name = "하우징" },
}

-- [에러 방지] 루프에서 사용하기 전에 미리 lookup 테이블을 생성합니다.
local expLookup = {}
for _, info in ipairs(expTable) do 
    expLookup[info.category] = info 
end

------------------------------
-- 배경
------------------------------

local TeleportBackground = CreateFrame("Frame", "TeleportMenuFrame", UIParent, "BackdropTemplate") -- 배경 생성
TeleportBackground:SetSize(650, 750) -- 크기 설정
TeleportBackground:SetPoint("LEFT", GameMenuFrame, "RIGHT", 20, 0) -- 위치 설정
TeleportBackground:Hide() -- 처음엔 숨김

NineSliceUtil.ApplyLayoutByName(TeleportBackground, "Dialog") -- NineSlice 레이아웃 적용

TeleportBackground.Bg = TeleportBackground:CreateTexture(nil, "BACKGROUND")
TeleportBackground.Bg:SetPoint("TOPLEFT", 8, -8)
TeleportBackground.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
TeleportBackground.Bg:SetAtlas("UI-DialogBox-Background-Dark")
TeleportBackground.Bg:SetAlpha(0.7)


------------------------------
-- 수집 상태, 쿨타임
------------------------------
local function UpdateAllButtonStates() -- 수집 상태
    for i, data in ipairs(teleportTable) do
        local btn = _G["TeleBtn"..i]
        if btn and btn.data then
            local isKnown = false
            local d = btn.data
            if d.type == "spell" then
                isKnown = IsSpellKnown(d.spellID)
            elseif d.type == "item" then
                isKnown = PlayerHasToy(d.spellID) or (C_Item.GetItemCount(d.spellID) > 0)
            else
                isKnown = true
            end

            if isKnown then
                if btn.icon then btn.icon:SetDesaturated(false) end
                btn:SetAlpha(1.0)
                if btn.border then btn.border:SetVertexColor(1, 1, 1) end
            else
                if btn.icon then btn.icon:SetDesaturated(true) end
                btn:SetAlpha(0.4)
                if btn.border then btn.border:SetVertexColor(0.4, 0.4, 0.4) end
            end
        end
    end
end

local function UpdateAllCooldowns() -- 쿨타임
    if not TeleportMenuFrame:IsShown() then return end
    for i, data in ipairs(teleportTable) do
        local btn = _G["TeleBtn"..i]
        if btn and btn.cooldown then
            local start, duration = 0, 0
            if data.type == "spell" then
                local cdInfo = C_Spell.GetSpellCooldown(data.spellID)
                start = cdInfo and cdInfo.startTime or 0
                duration = cdInfo and cdInfo.duration or 0
            elseif data.type == "item" then
                start, duration = C_Item.GetItemCooldown(data.spellID)
            end
            if start and start > 0 and duration > 0 then
                btn.cooldown:SetCooldown(start, duration)
            else
                btn.cooldown:Clear()
            end
        end
    end
end


------------------------------
-- 이벤트
------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", UpdateAllCooldowns)

TeleportMenuFrame:SetScript("OnShow", function()
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    UpdateAllButtonStates() -- 열 때 흑백 체크
    UpdateAllCooldowns()    -- 열 때 쿨타임 체크
end)

TeleportMenuFrame:SetScript("OnHide", function()
    eventFrame:UnregisterAllEvents()
end)

GameMenuFrame:HookScript("OnShow", function() 
    TeleportBackground:Show() 
end)
GameMenuFrame:HookScript("OnHide", function() 
    TeleportBackground:Hide() 
end)


------------------------------
-- 스킬 버튼 생성
------------------------------
local BUTTON_SIZE, BUTTON_SPACING, ROW_HEIGHT = 36, 4, 55 -- 버튼 크기, 간격, 행 간격
local ICON_X, BUTTON_START_X, START_Y = 20, 80, -25 -- 아이콘 X좌표, 버튼 시작 X좌표, 시작 Y좌표
local currentCategory = ""
local col, row = 0, -1
local playerFaction = UnitFactionGroup("player")

for i, data in ipairs(teleportTable) do
    if not (data.faction and data.faction ~= playerFaction) then
        -- [A] 섹션(확장팩 로고) 처리
        if data.category ~= currentCategory then
            row = row + 1; col = 0; currentCategory = data.category
            local expinfo = expLookup[data.category]
            local yPos = START_Y - (row * ROW_HEIGHT)
            
            local expTexture = TeleportBackground:CreateTexture(nil, "ARTWORK")
            expTexture:SetSize(BUTTON_SIZE, BUTTON_SIZE)
            expTexture:SetPoint("TOPLEFT", TeleportBackground, "TOPLEFT", ICON_X, yPos)
            expTexture:SetTexture(expinfo and expinfo.iconID or 132311)
            
            local mask = TeleportBackground:CreateMaskTexture()
            mask:SetAllPoints(expTexture); mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            expTexture:AddMaskTexture(mask)

            local expNameText = TeleportBackground:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
            expNameText:SetPoint("TOP", expTexture, "BOTTOM", 0, 3)
            expNameText:SetFont(expNameText:GetFont(), (strlenutf8(expinfo.name) >= 4) and 11 or 12, "OUTLINE")
            expNameText:SetText(expinfo.name); expNameText:SetTextColor(1, 0.82, 0)
        end

        -- [B] 버튼 생성 및 데이터 저장
        local btn = CreateFrame("Button", "TeleBtn"..i, TeleportBackground, "SecureActionButtonTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:SetPoint("TOPLEFT", TeleportBackground, "TOPLEFT", BUTTON_START_X + (col * (BUTTON_SIZE + BUTTON_SPACING)), START_Y - (row * ROW_HEIGHT))
        btn.data = data

        -- [C] 디자인 (아이콘 -> 테두리 -> 쿨타임 순서)
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexture(data.iconID or 134400)
        btn.icon = tex -- 업데이트 함수에서 참조할 수 있게 저장

        local btnMask = btn:CreateMaskTexture()
        btnMask:SetAllPoints(tex); btnMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        tex:AddMaskTexture(btnMask)

        local border = btn:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints(); border:SetAtlas("UI-HUD-ActionBar-IconFrame")
        btn.border = border

        local cd = CreateFrame("Cooldown", "TeleBtnCD"..i, btn, "CooldownFrameTemplate")
        cd:SetAllPoints(); btn.cooldown = cd
        cd:SetDrawEdge(false) -- 쿨타임 노란선

        local nameText = btn:CreateFontString(nil, "OVERLAY", "SystemFont_Outline_Small")
        nameText:SetPoint("TOP", btn, "BOTTOM", 0, 3)
        nameText:SetFont(nameText:GetFont(), (strlenutf8(data.name) >= 4) and 10 or 11, "OUTLINE")
        nameText:SetText(data.name)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAtlas("UI-HUD-ActionBar-IconFrame-MouseOver")
        hl:SetAllPoints()

        local pushed = btn:CreateTexture(nil, "OVERLAY")
        pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
        pushed:SetAllPoints()
        btn:SetPushedTexture(pushed)

        -- [D] 초기 상태 설정 (서버 데이터 미로딩 대비)
        tex:SetDesaturated(true); btn:SetAlpha(0.4)

        -- [E] 속성 및 툴팁
        btn:RegisterForClicks("AnyUp", "AnyDown")
        if data.type == "spell" then
            btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", data.spellID)
        elseif data.type == "item" then
            btn:SetAttribute("type", "item"); btn:SetAttribute("item", "item:"..data.spellID)
        elseif data.category == "ETC" then
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/run m=IsModifierKeyDown() and 2 or 1 EventUtil.RegisterOnceFrameEventAndCallback('PLAYER_HOUSE_LIST_UPDATED',function(a)h=a[m]C_Housing.TeleportHome(h.neighborhoodGUID,h.houseGUID,h.plotID)end)C_Housing.GetPlayerOwnedHouses()")
        end

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if data.type == "spell" then GameTooltip:SetSpellByID(data.spellID)
            elseif data.type == "item" then GameTooltip:SetItemByID(data.spellID)
            else GameTooltip:SetText(data.name) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        col = col + 1
    end
end