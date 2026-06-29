-- ==============================
-- Inspired
-- ==============================
-- HidingBar (https://www.curseforge.com/wow/addons/hidingbar)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
    defaultPoint         = "TOPRIGHT",
    defaultRelativeTo    = "MinimapCluster",
    defaultRelativePoint = "BOTTOMRIGHT",
    defaultX             = -4,
    defaultY             = -1,
    defaultPadding       = -2,
    buttonSize           = 32,

    sortOrder = {
        ["ExpansionLandingPageMinimapButton"] = 1,
        ["SimpleAddonManager"]   = 2,
        ["NotEvenClose"]         = 3,
        ["SimulationCraft"]      = 4,
        ["BliZziInterrupts"]     = 95,
        ["Plater"]               = 96,
        ["MythicDungeonTools"]   = 97,
        ["ThisWeeksAuras"]       = 98,
        ["BugSack"]              = 99,
    },
    hideSet = {
        ["RaiderIO"] = true,
    },
}

local IGNORE_LIST = {
    "MinimapBackdrop",
    "Minimap.ZoomIn",
    "Minimap.ZoomOut",
    "MinimapCluster.Tracking",
}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer          = C_Timer
local CreateFrame      = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs           = ipairs
local pairs            = pairs
local table_insert     = table.insert
local table_remove     = table.remove
local table_sort       = table.sort
local LibStub          = LibStub
local UIParent         = UIParent

-- ==============================
-- 로컬 상태
-- ==============================
local bar_frame         = nil
local init_frame        = CreateFrame("Frame")
local collected_buttons = {}
local buttons_by_name   = {}
local ticker_obj        = nil
local last_child_count  = 0

local original_parent = {}
local original_points = {}

-- 숨김 컨테이너 (hideSet 버튼용)
local hidden_frame = CreateFrame("Frame")
hidden_frame:Hide()

local ldb  = nil
local ldbi = nil

-- ==============================
-- 기능: 원래 위치로 복구
-- ==============================
local function restore_button(btn)
    if not btn then return end
    local parent = original_parent[btn]
    if parent then btn:SetParent(parent) end

    local name = btn:GetName()
    -- LibDBIcon 버튼은 라이브러리에 위치 복구 위임 (minimapPos 각도 기반)
    if name and name:find("LibDBIcon10_", 1, true) and ldbi then
        btn:ClearAllPoints()
        ldbi:Show(name:sub(13))
        return
    end
    -- 비-LibDBIcon 버튼: 저장된 원래 SetPoint로 복구
    btn:ClearAllPoints()
    local pts = original_points[btn]
    if pts and pts[1] then
        btn:SetPoint(pts[1], pts[2], pts[3], pts[4], pts[5])
    end
end

-- ==============================
-- 기능: 정렬 기준
-- ==============================
local function sort_buttons(a, b)
    local name_a  = a:GetName() or ""
    local name_b  = b:GetName() or ""
    local addon_a = name_a:find("LibDBIcon10_", 1, true) and name_a:sub(13) or name_a
    local addon_b = name_b:find("LibDBIcon10_", 1, true) and name_b:sub(13) or name_b
    local order_a = Config.sortOrder[addon_a] or 999
    local order_b = Config.sortOrder[addon_b] or 999
    if order_a ~= order_b then return order_a < order_b end
    return name_a < name_b
end

-- ==============================
-- 기능: 레이아웃 정렬
-- ==============================
local function update_layout()
    if not bar_frame then return end
    if InCombatLockdown() then return end
    if dodoDB.enableHidingBar == false then return end

    local size    = Config.buttonSize
    local padding = Config.defaultPadding

    table_sort(collected_buttons, sort_buttons)

    local prev  = nil
    local count = 0

    for _, btn in ipairs(collected_buttons) do
        local name      = btn:GetName()
        local addon_key = name and (name:find("LibDBIcon10_", 1, true) and name:sub(13) or name)

        if Config.hideSet[addon_key] then
            btn:SetParent(hidden_frame)
            btn:Hide()
        elseif Config.sortOrder[addon_key] then
            btn:SetParent(bar_frame)
            btn:Show()
            btn:ClearAllPoints()
            btn:SetSize(size, size)
            if not prev then
                btn:SetPoint("TOPLEFT", bar_frame, "TOPLEFT", padding, -padding)
            else
                btn:SetPoint("LEFT", prev, "RIGHT", padding, 0)
            end
            prev  = btn
            count = count + 1
        else
            if original_parent[btn] and btn:GetParent() ~= original_parent[btn] then
                restore_button(btn)
                btn:Show()
            end
        end
    end

    if count == 0 then
        bar_frame:Hide()
    else
        bar_frame:Show()
        bar_frame:SetSize((size + padding) * count + padding, size + padding * 2)
    end
end

-- ==============================
-- 기능: 버튼 추가 / 제거
-- ==============================
local function is_ignored(name)
    if not name then return true end
    for _, v in ipairs(IGNORE_LIST) do
        if name == v or name:find(v, 1, true) then return true end
    end
    return false
end

local function add_button(btn, name)
    if not btn then return end
    name = name or btn:GetName()
    if not name or buttons_by_name[name] then return end
    if is_ignored(name) then return end

    if not original_parent[btn] then
        original_parent[btn] = btn:GetParent()
        local pts = {}
        for i = 1, btn:GetNumPoints() do
            pts[i] = { btn:GetPoint(i) }
        end
        original_points[btn] = pts[1]
    end

    buttons_by_name[name] = btn
    table_insert(collected_buttons, btn)
end

local function remove_button(btn, name)
    if not btn then return end
    name = name or btn:GetName()
    if not name then return end

    if buttons_by_name[name] then
        buttons_by_name[name] = nil
        for i, v in ipairs(collected_buttons) do
            if v == btn then
                table_remove(collected_buttons, i)
                break
            end
        end
        restore_button(btn)
    end
end

-- ==============================
-- 기능: 버튼 수집
-- ==============================
local function grab_db_icon_buttons()
    if ldbi and ldbi.objects then
        for name, btn in pairs(ldbi.objects) do
            if btn then
                add_button(btn, "LibDBIcon10_" .. name)
            end
        end
    end
end

local function scan_minimap_children()
    local count = Minimap:GetNumChildren()
    if count == last_child_count then return end
    last_child_count = count

    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        local name = child:GetName()
        if name and name:find("LibDBIcon10_", 1, true) then
            local addon_key = name:sub(13)
            if addon_key and addon_key ~= "" then
                add_button(child, name)
            end
        end
    end
end

local function refresh_all_buttons()
    if InCombatLockdown() then return end

    grab_db_icon_buttons()
    scan_minimap_children()

    local exp_btn = ExpansionLandingPageMinimapButton
    if exp_btn then
        add_button(exp_btn, "ExpansionLandingPageMinimapButton")
    end

    update_layout()
end

-- ==============================
-- 기능: UI 생성
-- ==============================
local function create_ui()
    if bar_frame then return end

    bar_frame = CreateFrame("Frame", "dodo_HidingBarFrame", UIParent)
    bar_frame:SetFrameStrata("MEDIUM")
    bar_frame:SetSize(1, 1)
    bar_frame:EnableMouse(false)
    bar_frame:ClearAllPoints()

    local relativeTo = _G[Config.defaultRelativeTo] or UIParent
    bar_frame:SetPoint(Config.defaultPoint, relativeTo, Config.defaultRelativePoint, Config.defaultX, Config.defaultY)
end

local function initialize()
    if dodoDB.enableHidingBar == nil then dodoDB.enableHidingBar = true end
    create_ui()

    -- Blizzard 버그 워크어라운드: title 미초기화 시 SetText(nil) 에러 방지
    local exp_btn = ExpansionLandingPageMinimapButton
    if exp_btn and exp_btn.SetTooltip then
        local orig = exp_btn.SetTooltip
        exp_btn.SetTooltip = function(self)
            if self.title then orig(self) end
        end
    end
end

-- ==============================
-- 기능: 활성/비활성 처리
-- ==============================
local function update_visual()
    local is_enabled = dodoDB.enableHidingBar ~= false
    if is_enabled then
        if bar_frame then bar_frame:Show() end
        refresh_all_buttons()
        if not ticker_obj then
            ticker_obj = C_Timer.NewTicker(2.0, refresh_all_buttons)
        end
    else
        if ticker_obj then
            ticker_obj:Cancel()
            ticker_obj = nil
        end
        for _, btn in ipairs(collected_buttons) do
            restore_button(btn)
        end
        collected_buttons = {}
        buttons_by_name   = {}
        if bar_frame then bar_frame:Hide() end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
        else
            if arg1 == "Blizzard_GarrisonUI" and GarrisonLandingPage and GarrisonLandingPage.SetupCovenantTopPanel then
                -- Blizzard 버그 워크어라운드: 패치 12.0에서 섀도우랜즈 covenantData nil 크래시 방지
                local orig_setup = GarrisonLandingPage.SetupCovenantTopPanel
                GarrisonLandingPage.SetupCovenantTopPanel = function(self, ...)
                    pcall(orig_setup, self, ...)
                end
            end
            refresh_all_buttons()
        end
    elseif event == "PLAYER_LOGIN" then
        ldb  = LibStub and LibStub("LibDataBroker-1.1", true)
        ldbi = LibStub and LibStub("LibDBIcon-1.0", true)

        initialize()
        update_visual()

        if ldb then
            ldb.RegisterCallback("dodoHidingBar", "LibDataBroker_DataObjectCreated", refresh_all_buttons)
        end

        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_REGEN_ENABLED" then
        refresh_all_buttons()
    end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록 (미니맵 하위)
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.Minimap, {
        {
            name     = "애드온 아이콘 모음",
            get      = function() return dodoDB.enableHidingBar ~= false end,
            set      = function(v) dodoDB.enableHidingBar = v; update_visual() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        },
    })
end
