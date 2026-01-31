------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...
dodoDB = dodoDB or {}
local IconLib = dodo.IconLib

local teleportIcons = {}

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
    { id = 18984, type = "item", category = "Classic", name = "기공 얼" },
    { id = 18986, type = "item", category = "Classic", name = "기공 호" },

    -- BC
    { id = 151016, type = "item", category = "BC", name = "검사" },
    { id = 30544, type = "item", category = "BC", name = "기공 얼" },
    { id = 30542, type = "item", category = "BC", name = "기공 호" },

    -- WoL
    { id = 48933, type = "item", category = "WoL", name = "기공" },

    -- CATA
    { id = 410080, type = "spell", category = "CATA", name = "소용돌이" },
    { id = 424142, type = "spell", category = "CATA", name = "파도" },
    { id = 445424, type = "spell", category = "CATA", name = "그림바톨" },

    -- MoP
    { id = 87215, type = "item", category = "MoP", name = "기공" },
    { id = 131204, type = "spell", category = "MoP", name = "옥룡사" },
    { id = 131205, type = "spell", category = "MoP", name = "양조장" },
    { id = 131206, type = "spell", category = "MoP", name = "음영파" },
    { id = 131222, type = "spell", category = "MoP", name = "모구샨" },
    { id = 131225, type = "spell", category = "MoP", name = "석양문" },
    { id = 131228, type = "spell", category = "MoP", name = "사원" },
    { id = 131229, type = "spell", category = "MoP", name = "붉수도원" },
    { id = 131231, type = "spell", category = "MoP", name = "전당" },
    { id = 131232, type = "spell", category = "MoP", name = "스칼로" },

    -- WoD
    { id = 112059, type = "item", category = "WoD", name = "기공" },
    { id = 159901, type = "spell", category = "WoD", name = "상록숲" },
    { id = 159899, type = "spell", category = "WoD", name = "어둠달" },
    { id = 159900, type = "spell", category = "WoD", name = "정비소" },
    { id = 159896, type = "spell", category = "WoD", name = "선착장" },
    { id = 159895, type = "spell", category = "WoD", name = "피망치" },
    { id = 159897, type = "spell", category = "WoD", name = "아킨둔" },
    { id = 159898, type = "spell", category = "WoD", name = "하늘탑" },
    { id = 159902, type = "spell", category = "WoD", name = "검바탑" },

    -- Legion
    { id = 151652, type = "item", category = "Legion", name = "기공" },
    { id = 393764, type = "spell", category = "Legion", name = "용맹" },
    { id = 410078, type = "spell", category = "Legion", name = "넬둥" },
    { id = 393766, type = "spell", category = "Legion", name = "별궁" },
    { id = 373262, type = "spell", category = "Legion", name = "카라잔" },
    { id = 424153, type = "spell", category = "Legion", name = "검떼" },
    { id = 424163, type = "spell", category = "Legion", name = "어숲" },

    -- BfA
    { id = 168807, type = "item", category = "BfA", name = "기공 얼" },
    { id = 168808, type = "item", category = "BfA", name = "기공 호" },
    { id = 410071, type = "spell", category = "BfA", name = "자유지대" },
    { id = 410074, type = "spell", category = "BfA", name = "썩은굴" },
    { id = 373274, type = "spell", category = "BfA", name = "메카곤" },
    { id = 424167, type = "spell", category = "BfA", name = "저택" },
    { id = 424187, type = "spell", category = "BfA", name = "아탈" },
    { id = 445418, type = "spell", category = "BfA", name = "보랄", faction = "Alliance" },
    { id = 464256, type = "spell", category = "BfA", name = "보랄", faction = "Horde" },
    { id = 467553, type = "spell", category = "BfA", name = "왕노", faction = "Alliance" },
    { id = 467555, type = "spell", category = "BfA", name = "왕노", faction = "Horde" },

    -- SL
    { id = 172924, type = "item", category = "SL", name = "기공" },
    { id = 354462, type = "spell", category = "SL", name = "죽상" },
    { id = 354463, type = "spell", category = "SL", name = "역병" },
    { id = 354464, type = "spell", category = "SL", name = "티르너" },
    { id = 354465, type = "spell", category = "SL", name = "속죄", isSeason = true },
    { id = 354466, type = "spell", category = "SL", name = "승천" },
    { id = 354467, type = "spell", category = "SL", name = "고투" },
    { id = 354468, type = "spell", category = "SL", name = "저편" },
    { id = 354469, type = "spell", category = "SL", name = "핏빛" },
    { id = 367416, type = "spell", category = "SL", name = "타자베쉬", isSeason = true },
    { id = 373190, type = "spell", category = "SL", name = "나스리아" },
    { id = 373191, type = "spell", category = "SL", name = "지배" },
    { id = 373192, type = "spell", category = "SL", name = "태존매" },

    -- DF
    { id = 198156, type = "item", category = "DF", name = "기공" },
    { id = 393262, type = "spell", category = "DF", name = "노쿠드" },
    { id = 393267, type = "spell", category = "DF", name = "담쟁이" },
    { id = 393273, type = "spell", category = "DF", name = "대학" },
    { id = 393256, type = "spell", category = "DF", name = "루비" },
    { id = 393276, type = "spell", category = "DF", name = "넬타" },
    { id = 393279, type = "spell", category = "DF", name = "보관소" },
    { id = 393283, type = "spell", category = "DF", name = "주입" },
    { id = 393222, type = "spell", category = "DF", name = "울다만" },
    { id = 424197, type = "spell", category = "DF", name = "여명" },
    { id = 432254, type = "spell", category = "DF", name = "금고" },
    { id = 432257, type = "spell", category = "DF", name = "아베루스" },
    { id = 432258, type = "spell", category = "DF", name = "아미" },

    -- TWW
    { id = 221966, type = "item", category = "TWW", name = "기공" },
    { id = 445269, type = "spell", category = "TWW", name = "바금" },
    { id = 445443, type = "spell", category = "TWW", name = "부화장" },
    { id = 445414, type = "spell", category = "TWW", name = "새인호", isSeason = true },
    { id = 445444, type = "spell", category = "TWW", name = "수도원", isSeason = true },
    { id = 1216786, type = "spell", category = "TWW", name = "수문", isSeason = true },
    { id = 445416, type = "spell", category = "TWW", name = "실타래" },
    { id = 445417, type = "spell", category = "TWW", name = "아라카라", isSeason = true },
    { id = 445440, type = "spell", category = "TWW", name = "양조장" },
    { id = 445441, type = "spell", category = "TWW", name = "어불동" },
    { id = 1237215, type = "spell", category = "TWW", name = "알다니", isSeason = true },
    { id = 1226482, type = "spell", category = "TWW", name = "언더마인" },
    { id = 1239155, type = "spell", category = "TWW", name = "마괴종" },

    -- ETC
    { id = 1233637, type = "macro", iconID = 409599, category = "ETC", name = "하우징" },
}

local expLookup = {}
for _, info in ipairs(expTable) do
    expLookup[info.category] = info
end

------------------------------
-- 디스플레이
------------------------------
local TeleportFrame = CreateFrame("Frame", "TeleportMenuFrame", UIParent, "BackdropTemplate")
TeleportFrame:SetSize(650, 750)
TeleportFrame:SetPoint("LEFT", GameMenuFrame, "RIGHT", 20, 0)
TeleportFrame:Hide()

NineSliceUtil.ApplyLayoutByName(TeleportFrame, "Dialog")

TeleportFrame.Bg = TeleportFrame:CreateTexture(nil, "BACKGROUND")
TeleportFrame.Bg:SetPoint("TOPLEFT", 8, -8)
TeleportFrame.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
TeleportFrame.Bg:SetAtlas("UI-DialogBox-Background-Dark")
TeleportFrame.Bg:SetAlpha(0.7)

local BUTTON_SIZE, BUTTON_SPACING, ROW_HEIGHT = 36, 6, 55
local ICON_X, BUTTON_START_X, START_Y = 20, 70, -25
local currentCategory = ""
local col, row = 0, -1
local playerFaction = UnitFactionGroup("player")

------------------------------
-- 아이콘 생성 루프
------------------------------
for i, data in ipairs(teleportTable) do
    if not (data.faction and data.faction ~= playerFaction) then
        
        -- [1] 확장팩 로고 생성
        if data.category ~= currentCategory then
            row = row + 1; col = 0; currentCategory = data.category
            local expinfo = expLookup[data.category]
            
            local logoConfig = {
                isAction = false,
                id = 0,
                type = "macro",
                iconsize = {BUTTON_SIZE, BUTTON_SIZE},
                label = expinfo and expinfo.name or "",
                fontsize = 12,
                fontposition = {"TOP", nil, "BOTTOM", 0, 2},
                fontcolor = "yellow",
                outline = true,
                useTooltip = false,
            }

            local logo = IconLib:Create("TeleExpLogo_"..data.category, TeleportFrame, logoConfig)
            logo:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", ICON_X, START_Y - (row * ROW_HEIGHT))
            logo:ApplyConfig(logoConfig)
            logo.icon:SetTexture(expinfo and expinfo.iconID or 132311)
            local expFont, _, expOutline = logo.Name:GetFont()
            logo.Name:SetFont(expFont, (strlenutf8(expinfo.name) >= 4) and 11 or 12, expOutline)

            -- local mask = logo:CreateMaskTexture()
            -- mask:SetAllPoints(logo.icon); mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            -- logo.icon:AddMaskTexture(mask)
        end

        -- [2] 텔레포트 버튼 생성
        local btnConfig = {
            isAction = true,
            type = data.type,
            id = data.id,
            macrotext = data.macrotext,
            iconsize = {BUTTON_SIZE, BUTTON_SIZE},
            label = data.name,
            fontsize = 11,
            fontposition = {"TOP", nil, "BOTTOM", 0, 2},
            outline = true,
            cooldownSize = 12,
            useTooltip = true,
            framestrata = "HIGH",
        }
        
        local btn = IconLib:Create("TeleBtn"..i, TeleportFrame, btnConfig)
        btn:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", 
            BUTTON_START_X + (col * (BUTTON_SIZE + BUTTON_SPACING)), 
            START_Y - (row * ROW_HEIGHT))
        
        -- 라이브러리 함수 호출로 모든 설정 적용
        btn:ApplyConfig(btnConfig)

        local btnFont, _, btnOutline = btn.Name:GetFont()
        btn.Name:SetFont(btnFont, (strlenutf8(data.name) >= 4) and 10 or 11, btnOutline)

        table.insert(teleportIcons, btn)
        col = col + 1
    end
end

------------------------------
-- 이벤트 및 상태 업데이트
------------------------------
local function UpdateUIStatus()
    for _, icon in ipairs(teleportIcons) do
        if icon.UpdateStatus then icon:UpdateStatus() end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:SetScript("OnEvent", UpdateUIStatus)

TeleportFrame:SetScript("OnShow", UpdateUIStatus)
GameMenuFrame:HookScript("OnShow", function() TeleportFrame:Show() end)
GameMenuFrame:HookScript("OnHide", function() TeleportFrame:Hide() end)