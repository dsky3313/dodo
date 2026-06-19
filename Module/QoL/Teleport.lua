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
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local math_abs = math.abs
local NineSliceUtil = NineSliceUtil
local strlenutf8 = strlenutf8
local table_insert = table.insert
local UnitFactionGroup = UnitFactionGroup
local UIParent = UIParent

local icon_config = {
    BUTTON_SIZE = 36,   -- 아이콘 크기
    BUTTON_SPACING = 6, -- 아이콘 간격
    ROW_HEIGHT = 55,    -- 행 높이
    ICON_X = 20,
    BUTTON_START_X = 70,
    START_Y = -20,
}


local col, row = 0, -1
local current_category = ""
local teleport_icons = {}

local exp_lookup = {}
for _, info in ipairs(dodo.DungeonExps) do
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
local row_count = #dodo.DungeonExps
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
for i, data in ipairs(dodo.Dungeons) do
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
-- 설정 등록
-- ==============================
local Checkbox = Checkbox
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "useTeleport", "던전 텔레포트 메뉴", "ESC 메뉴 옆에 던전 텔레포트 버튼을 표시합니다.", true, dodo.ESCTeleportFrame)
end)