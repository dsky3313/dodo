-- ==============================
-- Inspired
-- ==============================
-- [Midnight] Quickselect Dungeons by Yukero (https://wago.io/BEYrOCKMG)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 2dodo 규격에 맞춰 아이콘 크기 및 간격 변수 중앙 캐싱 관리!
local Config = {
    defaultX = 0,
    defaultY = 0,
    defaultPoint = "CENTER",
    iconSize = 32, -- 개별 던전 아이콘 크기 (기본: 32px)
    spacing = 5,   -- 아이콘 사이의 간격 (기본: 6px)
}

---@class DungeonItem
---@field name string 단축 이름
---@field dID string 던전 LFG 활동 ID
---@field texture number 던전 아이콘 텍스처 번호

---@type DungeonItem[]
local DungeonList = {
    { name = "대학", dID = "1160", texture = 4578414 },
    { name = "마정", dID = "1760", texture = 7439625 },
    { name = "동굴", dID = "1764", texture = 7322719 },
    { name = "제나스", dID = "1768", texture = 7553062 },
    { name = "사론", dID = "1770", texture = 343641 },
    { name = "삼두정", dID = "486", texture = 1711340 },
    { name = "하늘탑", dID = "182", texture = 1002596 },
    { name = "첨탑", dID = "1542", texture = 7266215 },
}
-- dID 매크로. 절대 지우지 말것. (/run print("선택된 dID:", LFGListFrame.EntryCreation.selectedActivity))

-- ==============================
-- 캐싱
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_GossipInfo = C_GossipInfo
local C_LFGList = C_LFGList
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue
local tonumber = tonumber

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local main_frame = nil
local initFrame = CreateFrame("Frame")
local dungeon_buttons = {}

-- ==============================
-- 기능 3: UI 생성 및 쐐기 스캔
-- ==============================
local function get_d_check(id)
    local activityID = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
    return activityID and (tonumber(id) == tonumber(activityID)) or false
end

local function get_keystone_lvl(id)
    if get_d_check(id) then 
        local _, _, lvl = C_LFGList.GetOwnedKeystoneActivityAndGroupAndLevel()
        return lvl or ""
    else
        return ""
    end
end

-- 실시간 가방/로그인 시 보유 쐐기돌 스캔 및 텍스트 갱신 (투명도 인위조정 제거!)
local function refresh_keystones()
    if not main_frame then return end

    for i, btn in ipairs(dungeon_buttons) do
        local data = DungeonList[i]
        if data then
            local is_mine = get_d_check(data.dID)
            btn.text:SetText(data.name) -- 던전 이름은 하단에 고정 표시
            if is_mine then
                local lvl = get_keystone_lvl(data.dID)
                if btn.lvlText then
                    btn.lvlText:SetText(lvl) -- 보유 쐐기단수는 좌상단 표시
                end
                if btn.icon then
                    btn.icon:SetDesaturated(false) -- 보유한 쐐기돌은 컬러로 강조
                end
            else
                if btn.lvlText then
                    btn.lvlText:SetText("") -- 미보유 시 단수 비움
                end
                if btn.icon then
                    btn.icon:SetDesaturated(true) -- 보유하지 않은 던전은 흑백 필터 전환
                end
            end
        end
    end
end

local function on_button_down(self)
    local dID = self.dID
    local listingData = {
        activityIDs = {dID},
        questID = nil,
        isAutoAccept = false,
        isCrossFactionListing = true,
        isPrivateGroup = false,
        newPlayerFriendly = false,
        playstyle = Enum.LFGEntryPlaystyle.None,
        requiredDungeonScore = 0,
        requiredItemLevel = 0,
        requiredPvpRating = 0,
    }
    C_LFGList.CreateListing(listingData)
end

local function get_d_name(id)
    local name, _, _, _ = C_ChallengeMode.GetMapUIInfo(id)
    return name
end

-- Space Fix 레이아웃 교정용 정적 헬퍼 (익명 함수 제거 및 12.0.0+ 안전 가드 추가)
local function apply_space_fix()
    local ec = LFGListFrame.EntryCreation
    if not ec then return end

    if ec.DescriptionLabel and ec.NameLabel then
        ec.DescriptionLabel:ClearAllPoints()
        ec.DescriptionLabel:SetPoint("TOPLEFT", ec.NameLabel, "TOPLEFT", 0, -85)
    end

    if ec.Description then
        ec.Description:SetHeight(25)
    end

    -- 12.0.0+에서는 PlayStyleLabel 대신 PlayStyleDropdown이 사용됨을 대응한 예방 앵커링
    local playstyle_widget = ec.PlayStyleDropdown or ec.PlayStyleLabel
    if playstyle_widget then
        playstyle_widget:ClearAllPoints()
        playstyle_widget:SetPoint("TOPLEFT", ec.DescriptionLabel or ec.Description, "TOPLEFT", 0, -55)
    end
end

local function create_ui()
    if main_frame then return end

    if not LFGListFrame or not LFGListFrame.EntryCreation then
        return
    end

    main_frame = CreateFrame("Frame", "dodo_QuickselectFrame", LFGListFrame.EntryCreation, "BackdropTemplate")
    
    -- Config의 iconSize와 spacing 설정을 바탕으로 가로 사이즈 및 세로 사이즈 자동 갱신
    local total_width = Config.iconSize * #DungeonList + Config.spacing * (#DungeonList - 1)
    main_frame:SetSize(total_width, Config.iconSize)

    -- 프레임 계층 가방 뒤로 묻힘 원천 해결
    local parent_strata = LFGListFrame.EntryCreation:GetFrameStrata()
    local parent_level = LFGListFrame.EntryCreation:GetFrameLevel()

    main_frame:SetFrameStrata(parent_strata)
    main_frame:SetFrameLevel(parent_level + 10)

    main_frame:ClearAllPoints()
    main_frame:SetPoint("TOPLEFT", LFGListFrame.EntryCreation.Name, "BOTTOMLEFT", -4, -4)

    -- dodo.LibIcon이 준비되었는지 확인하고 로드
    local has_lib_icon = dodo.LibIcon and dodo.LibIcon.Create

    -- 간격 계산을 위한 이동 스텝 계산 (아이콘 크기 + 마진간격)
    local step = Config.iconSize + Config.spacing

    for i, data in ipairs(DungeonList) do
        local btn
        if has_lib_icon then
            -- Config 지정 아이콘 크기 기반 동적 생성
            btn = dodo.LibIcon:Create("dodo_QuickselectBtn" .. i, main_frame, { iconsize = {Config.iconSize, Config.iconSize} })
            
            local icon_config = {
                type = "macro",
                icon = data.texture,
                label = data.name,
                fontsize = 10,
                outline = true,
                useTooltip = false, -- 인게임 가독성을 위해 간결화
                framestrata = parent_strata, -- 묻힘 방지용 스트라타 주입!
                fontposition = { "TOP", nil, "BOTTOM", 0, 4 }, -- 폰트 위치 하단 앵커링 주입!
            }
            btn:ApplyConfig(icon_config)
            btn:SetFrameLevel(main_frame:GetFrameLevel() + 5) -- 묻힘 방지용 레벨 강제 지정!
            
            -- 기존 텍스트 핸들러를 LibIcon.Name으로 연동
            btn.text = btn.Name

            -- 단수용 FontString 생성 (TOPLEFT)
            local lvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
            lvlText:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            local fontPath, _, fontFlags = lvlText:GetFont()
            if fontPath then
                lvlText:SetFont(fontPath, 11, "OUTLINE")
            end
            local r, g, b = 1.0, 0.82, 0.0
            if dodo.Colors and dodo.Colors.Gold then
                r, g, b = dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b
            end
            lvlText:SetTextColor(r, g, b)
            btn.lvlText = lvlText
        else
            -- 폴백: 일반 프레임 방식
            btn = CreateFrame("Frame", nil, main_frame)
            btn:SetSize(Config.iconSize, Config.iconSize)
            btn:SetFrameStrata(parent_strata)
            btn:SetFrameLevel(main_frame:GetFrameLevel() + 5)
            
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexture(data.texture)
            icon:SetVertexColor(1, 1, 1, 1)
            btn.icon = icon

            -- 던전명 FontString (하단)
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
            text:SetPoint("TOP", btn, "BOTTOM", 0, -2)
            text:SetJustifyH("CENTER")
            text:SetText(data.name)
            local fontPath, _, fontFlags = text:GetFont()
            if fontPath then
                text:SetFont(fontPath, 10, "OUTLINE")
            end
            btn.text = text

            -- 단수용 FontString (TOPLEFT)
            local lvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
            lvlText:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            if fontPath then
                lvlText:SetFont(fontPath, 11, "OUTLINE")
            end
            local r, g, b = 1.0, 0.82, 0.0
            if dodo.Colors and dodo.Colors.Gold then
                r, g, b = dodo.Colors.Gold.r, dodo.Colors.Gold.g, dodo.Colors.Gold.b
            end
            lvlText:SetTextColor(r, g, b)
            btn.lvlText = lvlText

            local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            btn.cooldown = cooldown
        end

        -- Config에 정의된 동적 간격(step)을 적용하여 정렬 배치!
        btn:SetPoint("LEFT", main_frame, "LEFT", (i - 1) * step, 0)
        btn.dID = data.dID
        btn:SetScript("OnMouseDown", on_button_down)

        btn.getdName = get_d_name
        btn.getdCheck = get_d_check
        btn.getKeystoneLvl = get_keystone_lvl

        dungeon_buttons[i] = btn
    end

    hooksecurefunc(LFGListFrame.EntryCreation, "Show", apply_space_fix)
end

local function initialize()
    if dodoDB and dodoDB.enableQuickselect == nil then dodoDB.enableQuickselect = true end
    create_ui()
    refresh_keystones()

    hooksecurefunc(C_GossipInfo, "SelectOption", function(gossipOptionID)
        if gossipOptionID == 107597 then
            C_Timer.After(0.5, refresh_keystones)
        end
    end)
end

-- ==============================
-- 기능 2: 상태 업데이트 (자원 절약 가드 포함)
-- ==============================
local function update_visual()
    local is_enabled = (dodoDB and dodoDB.enableQuickselect ~= false)
    if is_enabled then
        if main_frame then
            main_frame:Show()
            refresh_keystones()
        end
        if initFrame then
            initFrame:RegisterEvent("BAG_UPDATE_DELAYED")
            initFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
            initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
    else
        if main_frame then main_frame:Hide() end
        if initFrame then
            initFrame:UnregisterEvent("BAG_UPDATE_DELAYED")
            initFrame:UnregisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
            initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
        elseif arg1 == "Blizzard_LFGList" then
            initialize()
            update_visual()
        end
    elseif event == "PLAYER_LOGIN" then
        initialize()
        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "BAG_UPDATE_DELAYED" or event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        refresh_keystones()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "파티만들기 빠른선택",
            get = function() return dodoDB and dodoDB.enableQuickselect ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableQuickselect = checked end
                update_visual()
            end
        }
    })
end