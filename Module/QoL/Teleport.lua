-- ==============================
-- Inspired
-- ==============================
-- M+ Dungeon Teleports [Retail] (https://www.curseforge.com/wow/addons/dungeonports)
-- Teleport Menu (https://www.curseforge.com/wow/addons/teleport-me-nu)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local lib_icon = dodo.LibIcon

-- ==============================
-- 캐싱
-- ==============================
local C_Housing = C_Housing
local CreateFrame = CreateFrame
local GameMenuFrame = GameMenuFrame
local GetInstanceInfo = GetInstanceInfo
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_abs = math.abs
local NineSliceUtil = NineSliceUtil
local strlenutf8 = strlenutf8
local table_insert = table.insert
local UnitFactionGroup = UnitFactionGroup
local UIParent = UIParent
local unpack = unpack

local icon_config = {
    BUTTON_SIZE = 36,   -- 아이콘 크기
    BUTTON_SPACING = 6, -- 아이콘 간격
    ROW_HEIGHT = 55,    -- 행 높이
    ICON_X = 20,
    BUTTON_START_X = 70,
    START_Y = -20,
}

local exp_table = {
    { iconID = 135763, category = "Classic", name = "오리지널" },
    { iconID = 135760, category = "BC", name = "불성" },
    { iconID = 237509, category = "WoL", name = "리분" },
    { iconID = 462340, category = "CATA", name = "대격변" },
    { iconID = 851298, category = "MoP", name = "판다" },
    { iconID = 1535376, category = "WoD", name = "드레노어" },
    { iconID = 1535374, category = "Legion", name = "군단" },
    { iconID = 2176535, category = "BfA", name = "격아" },
    { iconID = 3847780, category = "SL", name = "어둠땅" },
    { iconID = 4661645, category = "DF", name = "용군단" },
    { iconID = 5901551, category = "TWW", name = "내부전쟁" },
    { iconID = 7294993, category = "MN", name = "한밤" },
    { iconID = 132311, category = "ETC", name = "기타" },
}

local teleport_table = {
    -- Classic
    { id = 18984, type = "item", category = "Classic", name = "기공 얼" },
    { id = 18986, type = "item", category = "Classic", name = "기공 호" },

    -- BC
    { id = 151016, type = "item", category = "BC", name = "검사" },
    { id = 30544, type = "item", category = "BC", name = "기공 얼" },
    { id = 30542, type = "item", category = "BC", name = "기공 호" },

    -- WoL
    { id = 48933, type = "item", category = "WoL", name = "기공" },
    { id = 1254555, type = "spell", category = "WoL", name = "사론", isSeason = true  },

    -- CATA
    { id = 410080, type = "spell", category = "CATA", name = "누각" },
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
    { id = 159898, type = "spell", category = "WoD", name = "하늘탑", isSeason = true  },
    { id = 159902, type = "spell", category = "WoD", name = "검바탑" },

    -- Legion
    { id = 151652, type = "item", category = "Legion", name = "기공" },
    { id = 1254551, type = "spell", category = "Legion", name = "삼두정", isSeason = true  },
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
    { id = 354465, type = "spell", category = "SL", name = "속죄"},
    { id = 354466, type = "spell", category = "SL", name = "승천" },
    { id = 354467, type = "spell", category = "SL", name = "고투" },
    { id = 354468, type = "spell", category = "SL", name = "저편" },
    { id = 354469, type = "spell", category = "SL", name = "핏빛" },
    { id = 367416, type = "spell", category = "SL", name = "타자베쉬"},
    { id = 373190, type = "spell", category = "SL", name = "나스리아" },
    { id = 373191, type = "spell", category = "SL", name = "지배" },
    { id = 373192, type = "spell", category = "SL", name = "태존매" },

    -- DF
    { id = 198156, type = "item", category = "DF", name = "기공" },
    { id = 393262, type = "spell", category = "DF", name = "노쿠드" },
    { id = 393267, type = "spell", category = "DF", name = "담쟁이" },
    { id = 393273, type = "spell", category = "DF", name = "대학", isSeason = true  },
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
    { id = 445414, type = "spell", category = "TWW", name = "새인호"},
    { id = 445444, type = "spell", category = "TWW", name = "수도원"},
    { id = 1216786, type = "spell", category = "TWW", name = "수문"},
    { id = 445416, type = "spell", category = "TWW", name = "실타래" },
    { id = 445417, type = "spell", category = "TWW", name = "아라카라"},
    { id = 445440, type = "spell", category = "TWW", name = "양조장" },
    { id = 445441, type = "spell", category = "TWW", name = "어불동" },
    { id = 1237215, type = "spell", category = "TWW", name = "알다니"},
    { id = 1226482, type = "spell", category = "TWW", name = "언더마인" },
    { id = 1239155, type = "spell", category = "TWW", name = "마괴종" },

    -- MN
    { id = 248485, type = "item", category = "MN", name = "기공" },
    { id = 1254559, type = "spell", category = "MN", name = "동굴", isSeason = true  },
    { id = 1254572, type = "spell", category = "MN", name = "정원", isSeason = true  },
    { id = 1254563, type = "spell", category = "MN", name = "제나스", isSeason = true  },
    { id = 1254400, type = "spell", category = "MN", name = "첨탑", isSeason = true  },

    -- ETC
    { id = 1263273, type = "housing", category = "ETC", name = "하우징" },
    { id = 243056, type = "item", category = "ETC", name = "도르노갈" },
    { id = 253629, type = "item", category = "ETC", name = "여관" },
}

local col, row = 0, -1
local current_category = ""
local teleport_icons = {}

local exp_lookup = {}
for _, info in ipairs(exp_table) do
    exp_lookup[info.category] = info
end

local function set_color_from_table(obj, color_table, is_vertex)
    if obj and color_table then
        if is_vertex then
            obj:SetVertexColor(color_table[1] or 1, color_table[2] or 1, color_table[3] or 1)
        else
            obj:SetTextColor(color_table[1] or 1, color_table[2] or 1, color_table[3] or 1)
        end
    end
end

-- ==============================
-- 디스플레이
-- ==============================
-- 동적 높이 계산
local row_count = #exp_table
local frame_height = math_abs(icon_config.START_Y) + (row_count * icon_config.ROW_HEIGHT) + 10

-- 프레임 크기 적용
local teleport_frame = CreateFrame("Frame", "TeleportFrame", UIParent, "BackdropTemplate")
teleport_frame:SetSize(650, frame_height)
teleport_frame:SetPoint("LEFT", GameMenuFrame, "RIGHT", 20, 0)
teleport_frame:Hide()

NineSliceUtil.ApplyLayoutByName(teleport_frame, "Dialog")

teleport_frame.Bg = teleport_frame:CreateTexture(nil, "BACKGROUND")
teleport_frame.Bg:SetPoint("TOPLEFT", 8, -8)
teleport_frame.Bg:SetPoint("BOTTOMRIGHT", -8, 8)
teleport_frame.Bg:SetAtlas("UI-DialogBox-Background-Dark")
teleport_frame.Bg:SetAlpha(0.7)

-- ==============================
-- 아이콘 생성 루프
-- ==============================
local season_col, season_row = 0, 0
local player_faction = UnitFactionGroup("player")

-- 시즌 아이콘
local season_btn_start_x = icon_config.BUTTON_START_X + ((icon_config.BUTTON_SIZE + icon_config.BUTTON_SPACING) * 6)
local icon_season_title = lib_icon:Create("TeleSeasonTitle", teleport_frame, {iconsize = {icon_config.BUTTON_SIZE, icon_config.BUTTON_SIZE}})
icon_season_title:SetPoint("TOPLEFT", teleport_frame, "TOPLEFT", season_btn_start_x, icon_config.START_Y)
icon_season_title:ApplyConfig({
    type = "macro",
    icon = 5868902,
    label = "현재 시즌",
    fontsize = 11,
    fontposition = { "TOP", icon_season_title, "BOTTOM", 0, 3 },
    fontcolor = "yellow",
    outline = true,
    useTooltip = false,
    framestrata = "HIGH",
})

-- 아이콘 생성
for i, data in ipairs(teleport_table) do
    if not (data.faction and data.faction ~= player_faction) then

        -- 확장팩 아이콘
        if data.category ~= current_category then
            row = row + 1
            col = 0
            current_category = data.category
            local expinfo = exp_lookup[data.category]

            local iconEXPConfig = {
                isAction = false,
                id = 0,
                type = "macro",
                iconsize = { icon_config.BUTTON_SIZE, icon_config.BUTTON_SIZE },
                label = expinfo and expinfo.name or "",
                fontsize = 12,
                fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
                fontcolor = "yellow",
                outline = true,
                useTooltip = false,
                framestrata = "HIGH",
            }

            local icnoEXP = lib_icon:Create("tpEXP" .. data.category, teleport_frame, iconEXPConfig)
            icnoEXP:SetPoint("TOPLEFT", teleport_frame, "TOPLEFT", icon_config.ICON_X, icon_config.START_Y - (row * icon_config.ROW_HEIGHT))
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
            iconsize = { icon_config.BUTTON_SIZE, icon_config.BUTTON_SIZE },
            label = data.name,
            fontsize = 11,
            fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
            outline = true,
            cooldownSize = 12,
            useTooltip = true,
            framestrata = "HIGH",
        }

        local iconTP = lib_icon:Create("tpBtn" .. i, teleport_frame, iconTPConfig)
        iconTP:SetPoint("TOPLEFT", teleport_frame, "TOPLEFT", icon_config.BUTTON_START_X + (col * (icon_config.BUTTON_SIZE + icon_config.BUTTON_SPACING)), icon_config.START_Y - (row * icon_config.ROW_HEIGHT))
        iconTP:ApplyConfig(iconTPConfig)

        local btnFont, _, btnOutline = iconTP.Name:GetFont()
        iconTP.Name:SetFont(btnFont, (strlenutf8(data.name) >= 4) and 10 or 11, btnOutline)

        table_insert(teleport_icons, iconTP)

        -- 시즌 아이콘
        if data.isSeason then
            local iconSeasonConfig = {
                isAction = true,
                type = data.type,
                id = data.id,
                macrotext = data.macrotext,
                iconsize = { icon_config.BUTTON_SIZE, icon_config.BUTTON_SIZE },
                label = data.name,
                fontsize = 11,
                fontposition = { "TOP", nil, "BOTTOM", 0, 2 },
                outline = true,
                cooldownSize = 12,
                useTooltip = true,
                framestrata = "HIGH",
            }

            local iconSeason = lib_icon:Create("seasonBtn" .. i, teleport_frame, iconSeasonConfig)
            iconSeason:SetPoint("TOPLEFT", teleport_frame, "TOPLEFT", season_btn_start_x + (season_col * (icon_config.BUTTON_SIZE + icon_config.BUTTON_SPACING) + 50), icon_config.START_Y - (season_row * icon_config.ROW_HEIGHT))
            iconSeason:ApplyConfig(iconSeasonConfig)

            local btnFont, _, btnOutline = iconSeason.Name:GetFont()
            iconSeason.Name:SetFont(btnFont, (strlenutf8(data.name) >= 4) and 10 or 11, btnOutline)

            iconSeason.seasonColor = { 0.1, 1, 0.1 }
            table_insert(teleport_icons, iconSeason)

            season_col = season_col + 1
            if season_col >= 4 then
                season_col = 0
                season_row = season_row + 1
            end
        end

        col = col + 1
    end
end

local function update_ui_status()
    if InCombatLockdown() then return end

    for _, icon in ipairs(teleport_icons) do
        if icon.UpdateStatus then icon:UpdateStatus() end

        if icon.seasonColor then
            set_color_from_table(icon.Name, icon.seasonColor)
            set_color_from_table(icon.normalTexture, icon.seasonColor, true)
        end
    end
end

local init_teleport_frame = CreateFrame("Frame")

local function toggle_events(enable)
    if enable then
        init_teleport_frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        init_teleport_frame:RegisterEvent("BAG_UPDATE_DELAYED")
        init_teleport_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        init_teleport_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        init_teleport_frame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
        init_teleport_frame:RegisterEvent("HOUSE_PLOT_ENTERED")
        init_teleport_frame:RegisterEvent("HOUSE_PLOT_EXITED")
    else
        init_teleport_frame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        init_teleport_frame:UnregisterEvent("BAG_UPDATE_DELAYED")
        init_teleport_frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        init_teleport_frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        init_teleport_frame:UnregisterEvent("PLAYER_HOUSE_LIST_UPDATED")
        init_teleport_frame:UnregisterEvent("HOUSE_PLOT_ENTERED")
        init_teleport_frame:UnregisterEvent("HOUSE_PLOT_EXITED")
    end
end

local function esc_teleport_frame()
    if InCombatLockdown() then return end
    local is_enabled = (dodoDB and dodoDB.useTeleport ~= false)

    if is_enabled and GameMenuFrame:IsShown() then
        if not teleport_frame:IsShown() then
            teleport_frame:Show()
        end
        toggle_events(true)
    else
        if teleport_frame:IsShown() then
            teleport_frame:Hide()
        end
        toggle_events(false)
    end
end

-- ==============================
-- 이벤트
-- ==============================
teleport_frame:SetScript("OnShow", update_ui_status)

init_teleport_frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function on_event(self, event, ...)
    local is_enabled = (dodoDB and dodoDB.useTeleport ~= false)
    if not is_enabled then
        toggle_events(false)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if C_Housing and C_Housing.GetPlayerOwnedHouses then
            init_teleport_frame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
            C_Housing.GetPlayerOwnedHouses()
        end
        toggle_events(true)
        update_ui_status()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        esc_teleport_frame()
    elseif event == "PLAYER_REGEN_DISABLED" then
        teleport_frame:Hide()
    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        local housingInfo = ...
        if housingInfo then
            dodo.houseData = housingInfo
            if teleport_frame:IsShown() and not InCombatLockdown() then
                update_ui_status()
            end
        end
    else
        if teleport_frame:IsShown() and not InCombatLockdown() then
            update_ui_status()
        end
    end
end

init_teleport_frame:SetScript("OnEvent", on_event)

-- 메뉴 후킹
GameMenuFrame:HookScript("OnShow", esc_teleport_frame)
GameMenuFrame:HookScript("OnHide", esc_teleport_frame)

dodo.ESCTeleportFrame = esc_teleport_frame

-- ==============================
-- 외부 노출 및 설정 동적 등록 (RegisterEditModeModuleSetting 이관)
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "던전 텔레포트 메뉴",
            get = function() return dodoDB and dodoDB.useTeleport ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTeleport = checked end
                esc_teleport_frame()
            end
        }
    })
end