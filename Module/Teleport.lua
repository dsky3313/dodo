-- ==============================
-- 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}
local IconLib = dodo.IconLib
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local teleportIcons = {}

local iconConfig = {
    BUTTON_SIZE = 36,   -- 아이콘 크기
    BUTTON_SPACING = 6, -- 아이콘 간격
    ROW_HEIGHT = 55,    -- 행 높이
    ICON_X = 20,
    BUTTON_START_X = 70,
    START_Y = -20,
}

local expTable = {
    { category = "Classic", name = L["오리지널"], iconID = 135763 },
    { category = "BC", name = L["불성"], iconID = 135760 },
    { category = "WoL", name = L["리분"], iconID = 237509 },
    { category = "CATA", name = L["대격변"], iconID = 462340 },
    { category = "MoP", name = L["판다"], iconID = 851298 },
    { category = "WoD", name = L["드레노어"], iconID = 1535376 },
    { category = "Legion", name = L["군단"], iconID = 1535374 },
    { category = "BfA", name = L["격아"], iconID = 2176535 },
    { category = "SL", name = L["어둠땅"], iconID = 3847780 },
    { category = "DF", name = L["용군단"], iconID = 4661645 },
    { category = "TWW", name = L["내부전쟁"], iconID = 5901551 },
    { category = "MN", name = L["한밤"], iconID = 7294993 },
    { category = "ETC", name = L["기타"], iconID = 132311 },
}

local teleportTable = {
    -- Classic
    { id = 18984, type = "item", category = "Classic", name = L["기공 얼"] },
    { id = 18986, type = "item", category = "Classic", name = L["기공 호"] },

    -- BC
    { id = 151016, type = "item", category = "BC", name = L["검사"] },
    { id = 30544, type = "item", category = "BC", name = L["기공 얼"] },
    { id = 30542, type = "item", category = "BC", name = L["기공 호"] },

    -- WoL
    { id = 48933, type = "item", category = "WoL", name = L["기공"] },
    { id = 1254555, type = "spell", category = "WoL", name = L["샤론"] },

    -- CATA
    { id = 410080, type = "spell", category = "CATA", name = L["누각"] },
    { id = 424142, type = "spell", category = "CATA", name = L["파도"] },
    { id = 445424, type = "spell", category = "CATA", name = L["그림바톨"] },

    -- MoP
    { id = 87215, type = "item", category = "MoP", name = L["기공"] },
    { id = 131204, type = "spell", category = "MoP", name = L["옥룡사"] },
    { id = 131205, type = "spell", category = "MoP", name = L["양조장"] },
    { id = 131206, type = "spell", category = "MoP", name = L["음영파"] },
    { id = 131222, type = "spell", category = "MoP", name = L["모구샨"] },
    { id = 131225, type = "spell", category = "MoP", name = L["석양문"] },
    { id = 131228, type = "spell", category = "MoP", name = L["사원"] },
    { id = 131229, type = "spell", category = "MoP", name = L["붉수도원"] },
    { id = 131231, type = "spell", category = "MoP", name = L["전당"] },
    { id = 131232, type = "spell", category = "MoP", name = L["스칼로"] },

    -- WoD
    { id = 112059, type = "item", category = "WoD", name = L["기공"] },
    { id = 159901, type = "spell", category = "WoD", name = L["상록숲"] },
    { id = 159899, type = "spell", category = "WoD", name = L["어둠달"] },
    { id = 159900, type = "spell", category = "WoD", name = L["정비소"] },
    { id = 159896, type = "spell", category = "WoD", name = L["선착장"] },
    { id = 159895, type = "spell", category = "WoD", name = L["피망치"] },
    { id = 159897, type = "spell", category = "WoD", name = L["아킨둔"] },
    { id = 1254557, type = "spell", category = "WoD", name = L["하늘탑"] },
    { id = 159902, type = "spell", category = "WoD", name = L["검바탑"] },

    -- Legion
    { id = 151652, type = "item", category = "Legion", name = L["기공"] },
    { id = 1254551, type = "spell", category = "Legion", name = L["삼두정"] },
    { id = 393764, type = "spell", category = "Legion", name = L["용맹"] },
    { id = 410078, type = "spell", category = "Legion", name = L["넬둥"] },
    { id = 393766, type = "spell", category = "Legion", name = L["별궁"] },
    { id = 373262, type = "spell", category = "Legion", name = L["카라잔"] },
    { id = 424153, type = "spell", category = "Legion", name = L["검떼"] },
    { id = 424163, type = "spell", category = "Legion", name = L["어숲"] },

    -- BfA
    { id = 168807, type = "item", category = "BfA", name = L["기공 얼"] },
    { id = 168808, type = "item", category = "BfA", name = L["기공 호"] },
    { id = 410071, type = "spell", category = "BfA", name = L["자유지대"] },
    { id = 410074, type = "spell", category = "BfA", name = L["썩은굴"] },
    { id = 373274, type = "spell", category = "BfA", name = L["메카곤"] },
    { id = 424167, type = "spell", category = "BfA", name = L["저택"] },
    { id = 424187, type = "spell", category = "BfA", name = L["아탈"] },
    { id = 445418, type = "spell", category = "BfA", name = L["보랄"], faction = "Alliance" },
    { id = 464256, type = "spell", category = "BfA", name = L["보랄"], faction = "Horde" },
    { id = 467553, type = "spell", category = "BfA", name = L["왕노"], faction = "Alliance" },
    { id = 467555, type = "spell", category = "BfA", name = L["왕노"], faction = "Horde" },

    -- SL
    { id = 172924, type = "item", category = "SL", name = L["기공"] },
    { id = 354462, type = "spell", category = "SL", name = L["죽상"] },
    { id = 354463, type = "spell", category = "SL", name = L["역병"] },
    { id = 354464, type = "spell", category = "SL", name = L["티르너"] },
    { id = 354465, type = "spell", category = "SL", name = L["속죄"], isSeason = true },
    { id = 354466, type = "spell", category = "SL", name = L["승천"] },
    { id = 354467, type = "spell", category = "SL", name = L["고투"] },
    { id = 354468, type = "spell", category = "SL", name = L["저편"] },
    { id = 354469, type = "spell", category = "SL", name = L["핏빛"] },
    { id = 367416, type = "spell", category = "SL", name = L["타자베쉬"], isSeason = true },
    { id = 373190, type = "spell", category = "SL", name = L["나스리아"] },
    { id = 373191, type = "spell", category = "SL", name = L["지배"] },
    { id = 373192, type = "spell", category = "SL", name = L["태존매"] },

    -- DF
    { id = 198156, type = "item", category = "DF", name = L["기공"] },
    { id = 393262, type = "spell", category = "DF", name = L["노쿠드"] },
    { id = 393267, type = "spell", category = "DF", name = L["담쟁이"] },
    { id = 393273, type = "spell", category = "DF", name = L["대학"] },
    { id = 393256, type = "spell", category = "DF", name = L["루비"] },
    { id = 393276, type = "spell", category = "DF", name = L["넬타"] },
    { id = 393279, type = "spell", category = "DF", name = L["보관소"] },
    { id = 393283, type = "spell", category = "DF", name = L["주입"] },
    { id = 393222, type = "spell", category = "DF", name = L["울다만"] },
    { id = 424197, type = "spell", category = "DF", name = L["여명"] },
    { id = 432254, type = "spell", category = "DF", name = L["금고"] },
    { id = 432257, type = "spell", category = "DF", name = L["아베루스"] },
    { id = 432258, type = "spell", category = "DF", name = L["아미"] },

    -- TWW
    { id = 221966, type = "item", category = "TWW", name = L["기공"] },
    { id = 445269, type = "spell", category = "TWW", name = L["바금"] },
    { id = 445443, type = "spell", category = "TWW", name = L["부화장"] },
    { id = 445414, type = "spell", category = "TWW", name = L["새인호"], isSeason = true },
    { id = 445444, type = "spell", category = "TWW", name = L["수도원"], isSeason = true },
    { id = 1216786, type = "spell", category = "TWW", name = L["수문"], isSeason = true },
    { id = 445416, type = "spell", category = "TWW", name = L["실타래"] },
    { id = 445417, type = "spell", category = "TWW", name = L["아라카라"], isSeason = true },
    { id = 445440, type = "spell", category = "TWW", name = L["양조장"] },
    { id = 445441, type = "spell", category = "TWW", name = L["어불동"] },
    { id = 1237215, type = "spell", category = "TWW", name = L["알다니"], isSeason = true },
    { id = 1226482, type = "spell", category = "TWW", name = L["언더마인"] },
    { id = 1239155, type = "spell", category = "TWW", name = L["마괴종"] },

        -- MN
    { id = 221966, type = "item", category = "MN", name = L["기공"] },
    { id = 1254559, type = "spell", category = "MN", name = L["동굴"] },
    { id = 1254572, type = "spell", category = "MN", name = L["정원"] },
    { id = 1254563, type = "spell", category = "MN", name = L["제나스"] },
    { id = 1254400, type = "spell", category = "MN", name = L["첨탑"] },

    -- ETC
    { id = 1233637, type = "macro", iconID = 7252953, category = "ETC", name = L["하우징"] },
}

local expLookup = {}
for _, info in ipairs(expTable) do
    expLookup[info.category] = info
end

local currentCategory = ""
local col, row = 0, -1

-- ==============================
-- 디스플레이
-- ==============================
-- 동적 높이 계산
local rowCount = #expTable
local frameHeight = math.abs(iconConfig.START_Y) + (rowCount * iconConfig.ROW_HEIGHT) + 10

-- 프레임 크기 적용
local TeleportFrame = CreateFrame("Frame", "TeleportFrame", UIParent, "BackdropTemplate")
TeleportFrame:SetSize(650, frameHeight)
TeleportFrame:SetPoint("LEFT", GameMenuFrame, "RIGHT", 20, 0)
TeleportFrame:Hide()

NineSliceUtil.ApplyLayoutByName(TeleportFrame, "Dialog")

TeleportFrame.Bg = TeleportFrame:CreateTexture(nil, "BACKGROUND")
TeleportFrame.Bg:SetPoint("TOPLEFT", 8, -8)
TeleportFrame.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
TeleportFrame.Bg:SetAtlas("UI-DialogBox-Background-Dark")
TeleportFrame.Bg:SetAlpha(0.7)

-- ==============================
-- 아이콘 생성 루프
-- ==============================
local seasonCol, seasonRow = 0, 0
local playerFaction = UnitFactionGroup("player")

-- 시즌 아이콘
local seasonBtnStartX = iconConfig.BUTTON_START_X + ((iconConfig.BUTTON_SIZE + iconConfig.BUTTON_SPACING) * 6)
local iconSeasonTitle = IconLib:Create("TeleSeasonTitle", TeleportFrame, {iconsize = {iconConfig.BUTTON_SIZE, iconConfig.BUTTON_SIZE}})
iconSeasonTitle:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", seasonBtnStartX, iconConfig.START_Y)
iconSeasonTitle:ApplyConfig({
    type = "macro",
    icon = 5868902,
    label = "현재 시즌",
    fontsize = 11,
    fontposition = { "TOP", iconSeasonTitle, "BOTTOM", 0, 3 },
    fontcolor = "yellow",
    outline = true,
    useTooltip = false,
})

-- 아이콘 생성
for i, data in ipairs(teleportTable) do
    if not (data.faction and data.faction ~= playerFaction) then

        -- 확장팩 아이콘
        if data.category ~= currentCategory then
            row = row + 1
            col = 0
            currentCategory = data.category
            local expinfo = expLookup[data.category]

            local iconEXPConfig = {
                isAction = false,
                id = 0,
                type = "macro",
                iconsize = { iconConfig.BUTTON_SIZE, iconConfig.BUTTON_SIZE },
                label = expinfo and expinfo.name or "",
                fontsize = 12,
                fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
                fontcolor = "yellow",
                outline = true,
                useTooltip = false,
            }

            local icnoEXP = IconLib:Create("tpEXP" .. data.category, TeleportFrame, iconEXPConfig)
            icnoEXP:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", iconConfig.ICON_X, iconConfig.START_Y - (row * iconConfig.ROW_HEIGHT))
            icnoEXP:ApplyConfig(iconEXPConfig)
            icnoEXP.icon:SetTexture(expinfo and expinfo.iconID or 132311)
            local expFont, _, expOutline = icnoEXP.Name:GetFont()
            icnoEXP.Name:SetFont(expFont, (strlenutf8(expinfo.name) >= 4) and 11 or 12, expOutline)
        end

        -- 텔포 아이콘
        local iconTPConfig = {
            isAction = true,
            type = data.type,
            id = data.id,
            macrotext = data.macrotext,
            iconsize = { iconConfig.BUTTON_SIZE, iconConfig.BUTTON_SIZE },
            label = data.name,
            fontsize = 11,
            fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
            outline = true,
            cooldownSize = 12,
            useTooltip = true,
            framestrata = "HIGH",
        }

        local iconTP = IconLib:Create("tpBtn" .. i, TeleportFrame, iconTPConfig)
        iconTP:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", iconConfig.BUTTON_START_X + (col * (iconConfig.BUTTON_SIZE + iconConfig.BUTTON_SPACING)), iconConfig.START_Y - (row * iconConfig.ROW_HEIGHT))
        iconTP:ApplyConfig(iconTPConfig)

        local btnFont, _, btnOutline = iconTP.Name:GetFont()
        iconTP.Name:SetFont(btnFont, (strlenutf8(data.name) >= 4) and 10 or 11, btnOutline)

        -- 시즌 아이콘
        if data.isSeason then
            local iconSeasonConfig = {
                isAction = true,
                type = data.type,
                id = data.id,
                macrotext = data.macrotext,
                iconsize = { iconConfig.BUTTON_SIZE, iconConfig.BUTTON_SIZE },
                label = data.name,
                fontsize = 11,
                fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
                outline = true,
                cooldownSize = 12,
                useTooltip = true,
                framestrata = "HIGH",
            }

            local iconSeason = IconLib:Create("seasonBtn" .. i, TeleportFrame, iconSeasonConfig)
            iconSeason:SetPoint("TOPLEFT", TeleportFrame, "TOPLEFT", seasonBtnStartX + (seasonCol * (iconConfig.BUTTON_SIZE + iconConfig.BUTTON_SPACING) + 50), iconConfig.START_Y - (seasonRow * iconConfig.ROW_HEIGHT))
            iconSeason:ApplyConfig(iconSeasonConfig)

            local btnFont, _, btnOutline = iconSeason.Name:GetFont()
            iconSeason.Name:SetFont(btnFont, (strlenutf8(data.name) >= 4) and 10 or 11, btnOutline)

            iconSeason.seasonColor = { 0.1, 1, 0.1 }
            table.insert(teleportIcons, iconSeason)

            seasonCol = seasonCol + 1
            if seasonCol >= 4 then
                seasonCol = 0
                seasonRow = seasonRow + 1
            end
        end

        col = col + 1
    end
end

local function UpdateUIStatus()
    -- 전투 중에는 UI 상태 업데이트를 건너뜁니다 (에러 방지)
    if InCombatLockdown() then return end
    
    for _, icon in ipairs(teleportIcons) do
        if icon.UpdateStatus then
            icon:UpdateStatus()
        end

        if icon.seasonColor then
            icon.Name:SetTextColor(unpack(icon.seasonColor))
            icon.normalTexture:SetVertexColor(unpack(icon.seasonColor))
        end
    end
end

local function ESCTeleportFrame()
    -- 1. 현재 전투 중인지 먼저 확인 (가장 중요)
    if InCombatLockdown() then return end

    local isEnabled = (dodoDB and dodoDB.useTeleport ~= false)

    -- 2. 조건에 따라 Show/Hide 수행
    if isEnabled and GameMenuFrame:IsShown() then
        if not TeleportFrame:IsShown() then
            TeleportFrame:Show()
        end
    else
        if TeleportFrame:IsShown() then
            TeleportFrame:Hide()
        end
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initTeleportFrame = CreateFrame("Frame")
initTeleportFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
initTeleportFrame:RegisterEvent("BAG_UPDATE_DELAYED")
initTeleportFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
initTeleportFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- 전투 시작 이벤트 추가

initTeleportFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- 전투 종료 후 메뉴가 열려있다면 프레임을 다시 체크
        ESCTeleportFrame()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 전투가 시작되면 에러 방지를 위해 즉시 숨김 시도 (보통은 시스템이 차단하기 전 찰나에 수행)
        if TeleportFrame:IsShown() then
            TeleportFrame:Hide()
        end
    else
        -- 쿨다운 등 일반 업데이트 (전투 중 아닐 때만)
        if not InCombatLockdown() and TeleportFrame:IsShown() then
            UpdateUIStatus()
        end
    end
end)

-- 프레임 자체 스크립트에서도 전투 체크
TeleportFrame:SetScript("OnShow", function()
    if not InCombatLockdown() then
        UpdateUIStatus()
    end
end)

-- 메뉴 후킹 부분
GameMenuFrame:HookScript("OnShow", function()
    if not InCombatLockdown() then
        ESCTeleportFrame()
    end
end)

GameMenuFrame:HookScript("OnHide", function()
    if not InCombatLockdown() then
        ESCTeleportFrame()
    end
end)