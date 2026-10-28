-- ==============================
-- PartyTracker 설정 (/dd 전투 > 파티 주문 추적 탭, 파티원 주요 기술은 /dd 유닛프레임 > 파티프레임 탭)
-- ==============================
-- 엔진 설정은 dodoDB.partyTracker.partyCDs (ns.PTCGetCfg) 에 저장됨.
-- 여기선 dodoDB 토글 → 엔진 cfg 동기화만 담당.

---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local _, ns = ...
local dodo = _G.dodo
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame

dodo.PT_DEFAULTS = {
    enablePartyCD         = true,
    usePartyCDShowSelf    = true,
    usePartyCDDungeonOnly = false,
    partyCDSide           = "LEFT",
    partyCDSize           = 36,
    partyCDSpacing        = 0,
    usePartyCDTooltip     = true,
    usePartyCDReverse     = false,
    partyCDMaxIcons       = 5,
    usePartyCDKeepRace    = true,
    enablePartyDefensives = true,
    -- partyDefensivesStyle  = "icon", -- dodo: 바 형식 고정 (아이콘 모드 주석처리)
    partyDefensivesWidth  = 180,
    partyDefensivesHeight = 20,
    usePartyDefensivesTooltip = true,
    enablePartyInterrupts = true,
    partyInterruptsIconGap = 0,
    partyInterruptsSpacing = -1,
    partyInterruptsWidth  = 180,
    partyInterruptsHeight = 20,
    usePartyInterruptsTooltip = true,
    enablePartyCC      = true,
    partyCCSize        = 36,
    partyCCSpacing     = 2,
    partyCCPerRow      = 8,
    usePartyCCTooltip  = true,
}

-- dodo: 공생기 바 형식 고정 (아이콘 모드 주석처리)
-- local STYLE_OPTIONS = {
--     { value = "icon", text = "아이콘" },
--     { value = "bar",  text = "바" },
-- }

local SIDE_OPTIONS = {
    { value = "RIGHT", text = "오른쪽" },
    { value = "LEFT",  text = "왼쪽" },
}

local function get(key)
    local v = dodoDB[key]
    if v == nil then v = dodo.PT_DEFAULTS[key] end
    return v
end

-- dodoDB 토글 → 엔진 cfg
local function sync_party_cd()
    if not ns.PTCGetCfg then return end
    local cfg = ns.PTCGetCfg()
    cfg.enable = get("enablePartyCD")
    cfg.showSelf = get("usePartyCDShowSelf")
    cfg.dungeonOnly = get("usePartyCDDungeonOnly")
    cfg.side = get("partyCDSide")
    cfg.size = get("partyCDSize")
    cfg.spacing = get("partyCDSpacing")
    cfg.tooltip = get("usePartyCDTooltip")
    cfg.reverse = get("usePartyCDReverse")
    cfg.maxIcons = get("partyCDMaxIcons")
    cfg.keepRace = get("usePartyCDKeepRace")
    ns.PTCApply()
    if dodo.UnitframeRefreshPreview then dodo.UnitframeRefreshPreview() end
end

-- 공생기 / 차단기 / 군중제어
local function sync_defensives()
    if not ns.PDFGetCfg then return end
    local cfg = ns.PDFGetCfg()
    cfg.enable = get("enablePartyDefensives") and dodoDB.enableCombat ~= false
    -- cfg.style = get("partyDefensivesStyle")
    cfg.style = "bar" -- dodo: 바 형식 고정
    cfg.barWidth = get("partyDefensivesWidth")
    cfg.size = get("partyDefensivesHeight") -- 바 높이 = 아이콘 크기
    cfg.tooltip = get("usePartyDefensivesTooltip")
    ns.PDFApply()
    if dodo.CombatRefreshPreview then dodo.CombatRefreshPreview() end
end

local function sync_interrupts()
    if not ns.IKGetCfg then return end
    local cfg = ns.IKGetCfg()
    cfg.enable = get("enablePartyInterrupts") and dodoDB.enableCombat ~= false
    cfg.iconGap = get("partyInterruptsIconGap")
    cfg.spacing = get("partyInterruptsSpacing")
    cfg.width = get("partyInterruptsWidth")
    cfg.height = get("partyInterruptsHeight")
    cfg.tooltip = get("usePartyInterruptsTooltip")
    ns.IKApply()
    if dodo.CombatRefreshPreview then dodo.CombatRefreshPreview() end
end

local function sync_cc()
    if not ns.CCGetCfg then return end
    local cfg = ns.CCGetCfg()
    cfg.enable = get("enablePartyCC") and dodoDB.enableCombat ~= false
    cfg.size1 = get("partyCCSize")
    cfg.spacing1 = get("partyCCSpacing")
    cfg.perRow = get("partyCCPerRow")
    cfg.tooltip = get("usePartyCCTooltip")
    ns.CCApply()
    if dodo.CombatRefreshPreview then dodo.CombatRefreshPreview() end
end

-- 유닛프레임 99 Options 의 "파티프레임" 탭에서 호출. 생성한 initializer 목록 반환 (탭 표시 조건 부착용)
function dodo.PTBuildPartyCDOptions(category)
    local D = dodo.PT_DEFAULTS
    local list = {}
    local function A(v) if v then list[#list+1] = v end return v end
    A(dodo.UI:SettingsSectionHeader(category, "파티원 주요 기술"))
    local cd_init, cd_setting = dodo.UI:SettingsCheckbox(category, "enablePartyCD", "파티원 주요 기술",
        "파티원 생존기 등 주요 기술의 재사용 대기시간을 파티 프레임 옆에 표시합니다.",
        D.enablePartyCD, sync_party_cd)
    A(cd_init)
    local function cd_on() return cd_setting:GetValue() end

    local self_init = A(dodo.UI:SettingsCheckbox(category, "usePartyCDShowSelf", "본인 포함",
        "본인 주요 기술도 함께 표시합니다.",
        D.usePartyCDShowSelf, sync_party_cd))
    if self_init and cd_init and self_init.SetParentInitializer then
        self_init:SetParentInitializer(cd_init, cd_on)
    end

    local dungeon_init = A(dodo.UI:SettingsCheckbox(category, "usePartyCDDungeonOnly", "던전 안에서만",
        "던전 안에서만 표시합니다.",
        D.usePartyCDDungeonOnly, sync_party_cd))
    if dungeon_init and cd_init and dungeon_init.SetParentInitializer then
        dungeon_init:SetParentInitializer(cd_init, cd_on)
    end
    A(select(2, dodo.UI:SettingsDropDown(category, "partyCDSide", "위치",
        "파티 프레임 기준 아이콘 위치를 선택합니다.",
        SIDE_OPTIONS, D.partyCDSide, sync_party_cd)))
    A(dodo.UI:SettingsSlider(category, "partyCDSize", "아이콘 크기",
        "아이콘 크기를 조절합니다.",
        16, 48, 1, D.partyCDSize, "Integer", sync_party_cd))
    A(dodo.UI:SettingsSlider(category, "partyCDSpacing", "아이콘 간격",
        "아이콘 사이 간격을 조절합니다.",
        0, 10, 1, D.partyCDSpacing, "Integer", sync_party_cd))
    local max_init = dodo.UI:SettingsSlider(category, "partyCDMaxIcons", "아이콘 개수",
        "파티원 한 명당 표시할 최대 아이콘 수. 넘치면 정렬 순서 뒤쪽부터 숨깁니다.",
        1, 8, 1, D.partyCDMaxIcons, "Integer", sync_party_cd)
    A(max_init)
    local function max_limited() return true end
    local race_init = A(dodo.UI:SettingsCheckbox(category, "usePartyCDKeepRace", "종족 특성 항상 보이기",
        "아이콘 개수 제한에 걸려도 종족 특성은 숨기지 않습니다. (종족 특성이 한 칸 차지)",
        D.usePartyCDKeepRace, sync_party_cd))
    if race_init and max_init and race_init.SetParentInitializer then
        race_init:SetParentInitializer(max_init, max_limited)
    end
    A(dodo.UI:SettingsCheckbox(category, "usePartyCDReverse", "아이콘 역순 정렬",
        "아이콘 정렬 순서를 반대로 뒤집습니다.",
        D.usePartyCDReverse, sync_party_cd))
    A(dodo.UI:SettingsCheckbox(category, "usePartyCDTooltip", "툴팁 표시",
        "전투 중이 아닐 때 아이콘에 마우스를 올리면 주문 툴팁을 표시합니다.",
        D.usePartyCDTooltip, sync_party_cd))

    -- 주문 목록 (직업/특성별 켜기/끄기, 위젯은 15 SpellList.lua)
    A(dodo.UI:SettingsSectionHeader(category, "주문 목록"))
    if dodo.PTCreateSpellListInitializer then A(dodo.PTCreateSpellListInitializer(category)) end
    return list
end

-- 전투 99 Options 의 "파티 주문 추적" 탭에서 호출. 생성한 initializer 목록 반환 (탭 표시 조건 부착용)
-- 순서: 차단기 > 군중제어 > 공생기 (하위 항목은 부모 체크 시 활성)
function dodo.PTBuildOptions(category)
    local D = dodo.PT_DEFAULTS
    local list = {}
    local function A(v) if v then list[#list+1] = v end return v end
    local function child(init, parent_init, parent_on)
        if init and parent_init and init.SetParentInitializer then
            init:SetParentInitializer(parent_init, parent_on)
        end
        return A(init)
    end
    A(dodo.UI:SettingsSectionHeader(category, "파티 주문 추적"))

    -- 차단기
    local ik_init, ik_setting = dodo.UI:SettingsCheckbox(category, "enablePartyInterrupts", "차단기",
        "파티원 차단기 쿨을 바 형태로 표시합니다. 위치는 편집모드에서 이동.",
        D.enablePartyInterrupts, sync_interrupts)
    A(ik_init)
    local function ik_on() return ik_setting:GetValue() end
    child(dodo.UI:SettingsSlider(category, "partyInterruptsWidth", "너비",
        "차단기 바 너비를 조절합니다.",
        80, 300, 1, D.partyInterruptsWidth, "Integer", sync_interrupts), ik_init, ik_on)
    child(dodo.UI:SettingsSlider(category, "partyInterruptsHeight", "높이",
        "차단기 바 높이를 조절합니다.",
        10, 40, 1, D.partyInterruptsHeight, "Integer", sync_interrupts), ik_init, ik_on)
    child(dodo.UI:SettingsCheckbox(category, "usePartyInterruptsTooltip", "툴팁 표시",
        "전투 중이 아닐 때 바에 마우스를 올리면 차단기 툴팁을 표시합니다.",
        D.usePartyInterruptsTooltip, sync_interrupts), ik_init, ik_on)

    -- 군중제어
    local cc_init, cc_setting = dodo.UI:SettingsCheckbox(category, "enablePartyCC", "군중제어",
        "파티원 광역/단일 군중제어기 쿨을 표시합니다. 위치는 편집모드에서 이동.",
        D.enablePartyCC, sync_cc)
    A(cc_init)
    local function cc_on() return cc_setting:GetValue() end
    child(dodo.UI:SettingsSlider(category, "partyCCSize", "아이콘 크기",
        "군중제어 아이콘 크기를 조절합니다.",
        16, 48, 1, D.partyCCSize, "Integer", sync_cc), cc_init, cc_on)
    child(dodo.UI:SettingsSlider(category, "partyCCSpacing", "아이콘 간격",
        "군중제어 아이콘 사이 간격을 조절합니다.",
        0, 10, 1, D.partyCCSpacing, "Integer", sync_cc), cc_init, cc_on)
    child(dodo.UI:SettingsSlider(category, "partyCCPerRow", "행 당 개수",
        "한 줄에 표시할 아이콘 수. 넘치면 다음 줄로 넘어갑니다.",
        1, 20, 1, D.partyCCPerRow, "Integer", sync_cc), cc_init, cc_on)
    child(dodo.UI:SettingsCheckbox(category, "usePartyCCTooltip", "툴팁 표시",
        "전투 중이 아닐 때 아이콘에 마우스를 올리면 주문 툴팁을 표시합니다.",
        D.usePartyCCTooltip, sync_cc), cc_init, cc_on)

    -- 공생기
    local df_init, df_setting = dodo.UI:SettingsCheckbox(category, "enablePartyDefensives", "공생기",
        "켜면 공생기(대마법 지대, 재집결의 함성 등)를 별도 묶음으로 모아 표시합니다. 위치는 편집모드에서 이동. 끄면 각 파티원 주요 기술 줄에 함께 표시합니다.",
        D.enablePartyDefensives, sync_defensives)
    A(df_init)
    local function df_on() return df_setting:GetValue() end
    -- dodo: 바 형식 고정 (아이콘 모드 주석처리)
    -- child(select(2, dodo.UI:SettingsDropDown(category, "partyDefensivesStyle", "표시 방식",
    --     "공생기 묶음을 아이콘 또는 바 형식으로 표시합니다.",
    --     STYLE_OPTIONS, D.partyDefensivesStyle, sync_defensives)), df_init, df_on)
    child(dodo.UI:SettingsSlider(category, "partyDefensivesWidth", "너비",
        "공생기 바 너비를 조절합니다.",
        80, 300, 1, D.partyDefensivesWidth, "Integer", sync_defensives), df_init, df_on)
    child(dodo.UI:SettingsSlider(category, "partyDefensivesHeight", "높이",
        "공생기 바 높이를 조절합니다.",
        10, 40, 1, D.partyDefensivesHeight, "Integer", sync_defensives), df_init, df_on)
    child(dodo.UI:SettingsCheckbox(category, "usePartyDefensivesTooltip", "툴팁 표시",
        "전투 중이 아닐 때 아이콘에 마우스를 올리면 주문 툴팁을 표시합니다.",
        D.usePartyDefensivesTooltip, sync_defensives), df_init, df_on)

    -- 주문 목록 (탭: 차단기 / 군중제어 / 공생기, 위젯은 15 SpellList.lua)
    A(dodo.UI:SettingsSectionHeader(category, "주문 목록"))
    if dodo.PTCreateTrackListInitializer then A(dodo.PTCreateTrackListInitializer(category)) end
    return list
end

-- 전투 마스터 토글 변경 시 (dodo.CombatUpdateModuleState). 파티원 주요 기술은 유닛프레임 설정이라 제외
function dodo.PTSyncAll()
    sync_defensives()
    sync_interrupts()
    sync_cc()
end

local login_frame = CreateFrame("Frame")
local function on_login(self)
    self:UnregisterAllEvents()
    sync_party_cd()
    sync_defensives()
    sync_interrupts()
    sync_cc()
end
login_frame:RegisterEvent("PLAYER_LOGIN")
login_frame:SetScript("OnEvent", on_login)
