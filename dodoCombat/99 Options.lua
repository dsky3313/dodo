-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 설정 기본값
-- ==============================
dodo.COMBAT_DEFAULTS = {
    enableCombat            = true,

    -- ResourceBar
    enableResourceBarModule = true,
    useResourceBarSmooth    = true,
    resourceBarWidth        = 266,
    resourceBarHeight       = 10,
    resourceBarHeight2      = 7,
    resourceBarFontSize     = 12,

    -- Debuff
    useDebuff               = true,
    debuffSize              = 56,
    debuffMax               = 6,
    debuffAnchorPoint       = "RIGHT",
    debuffAnchorRelPoint    = "CENTER",
    debuffAnchorX           = 394,
    debuffAnchorY           = -20,
    debuffX                 = 250,
    debuffY                 = 0,

    -- CursorSpellTracker
    enableCursorSpellTracker    = true,
    cursorSpellTrackerIconSize  = 26,  -- 아이콘 크기
    cursorSpellTrackerIconGap   = 0,   -- 아이콘 간 간격 (가로)
    cursorSpellTrackerRowGap    = 0,   -- 열 간 간격 (세로, 2열 배치일 때만)
    cursorSpellTrackerX         = 44,  -- 커서 기준 X 오프셋
    cursorSpellTrackerY         = -34, -- 커서 기준 Y 오프셋
    cursorSpellTrackerRowCount  = "2", -- "1" = 전부 한 줄, "2" = group별 줄 분리 (1열 기준, 2열은 그 위)

    -- BloodBrez
    useBloodBrez            = true,
    blbrIconSize            = 46,
    blbrIconPadding         = 2,

    -- Stance
    enableStance            = true,
    stanceIconSize          = 80,
}

-- 커서 주문추적: group별 배치 열 (2열 배치일 때만 적용, 미지정 group은 1열)
dodo.CST_ROW_BY_GROUP = {
    cd = 1,        -- 쿨기
    cc = 1,        -- 군중제어
    interrupt = 2, -- 차단기
    dispel = 2,    -- 해제
}

-- 같은 열 안 배치 순서 (앞 = 왼쪽). 여기 없는 group(미지정 포함)은 맨 뒤에 데이터 순서대로
-- 위 줄: 차단기 → 해제 / 아래 줄: 쿨기 → 군중제어
dodo.CST_GROUP_ORDER = { "interrupt", "dispel", "cd", "cc" }

-- ==============================
-- /dd 전투 설정 등록
-- ==============================
dodo.RegisterOption("전투", function(category)
    -- 마스터 토글
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableCombat", "전투 모듈 활성화",
        "전투 관련 모듈을 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableCombat = val end
        end)

    -- 탭별 sub-list
    local _rb_sub, _df_sub, _cst_sub, _bb_sub, _st_sub = {}, {}, {}, {}, {}
    local function R(v) if v then _rb_sub[#_rb_sub+1] = v end return v end
    local function D(v) if v then _df_sub[#_df_sub+1] = v end return v end
    local function C(v) if v then _cst_sub[#_cst_sub+1] = v end return v end
    local function B(v) if v then _bb_sub[#_bb_sub+1] = v end return v end
    local function S(v) if v then _st_sub[#_st_sub+1] = v end return v end

    local layout = SettingsPanel:GetLayout(category)
    if layout and CreateSettingsButtonInitializer then
        local btn = CreateSettingsButtonInitializer("", "편집 모드 열기", function()
            SettingsPanel:Close(true)
            ShowUIPanel(EditModeManagerFrame)
        end, "편집 모드에서 전투 모듈의 위치와 크기를 조정할 수 있습니다.", false)
        layout:AddInitializer(btn)
        if btn and btn.AddShownPredicate then
            btn:AddShownPredicate(function() return master_setting:GetValue() end)
        end
    end

    -- 통합 미리보기 (마스터 ON이면 탭 무관 항상 표시)
    local _preview_init = dodo.UI:SettingsTabbedPreview(category, { "자원바", "디버프", "커서 주문추적", "블러드 & 전투부활", "태세" }, dodoCombatPreviewMixin)
    if _preview_init and _preview_init.AddShownPredicate then
        _preview_init:AddShownPredicate(function() return master_setting:GetValue() end)
    end

    -- ── 자원바 탭 ──
    R(dodo.UI:SettingsSectionHeader(category, "자원바"))

    local rb_init, rb_setting = dodo.UI:SettingsCheckbox(category, "enableResourceBarModule", "자원바",
        "직업자원 막대와 보조자원 막대를 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableResourceBarModule = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
            dodo.CombatRefreshPreview()
        end)
    R(rb_init)

    local _rbs_sub = {}
    local function RS(v) if v then _rbs_sub[#_rbs_sub+1] = v end return v end

    RS(dodo.UI:SettingsCheckbox(category, "useResourceBarSmooth", "부드러운 증감",
        "자원 증감 시 부드러운 보간 애니메이션을 사용합니다.",
        true, function(val)
            if dodoDB then dodoDB.useResourceBarSmooth = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateSmooth then dodo.ResourceBar.UpdateSmooth() end
        end))

    RS(dodo.UI:SettingsSlider(category, "resourceBarWidth", "너비",
        "자원바의 가로 길이를 설정합니다.",
        200, 300, 2, 266, "Integer", function(val)
            if dodoDB then dodoDB.resourceBarWidth = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
            dodo.CombatRefreshPreview()
        end))

    RS(dodo.UI:SettingsSlider(category, "resourceBarHeight", "높이 (자원)",
        "자원바(bar1)의 세로 높이를 설정합니다.",
        6, 20, 1, 10, "Integer", function(val)
            if dodoDB then dodoDB.resourceBarHeight = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
            dodo.CombatRefreshPreview()
        end))

    RS(dodo.UI:SettingsSlider(category, "resourceBarHeight2", "높이 (특성)",
        "특성바(bar2)의 세로 높이를 설정합니다.",
        4, 20, 1, 7, "Integer", function(val)
            if dodoDB then dodoDB.resourceBarHeight2 = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
            dodo.CombatRefreshPreview()
        end))

    RS(dodo.UI:SettingsSlider(category, "resourceBarFontSize", "글자 크기",
        "자원바 수치 텍스트의 글자 크기를 설정합니다.",
        8, 18, 1, 12, "Integer", function(val)
            if dodoDB then dodoDB.resourceBarFontSize = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
        end))

    -- ── 디버프 탭 ──
    D(dodo.UI:SettingsSectionHeader(category, "디버프 아이콘"))

    local df_init, df_setting = dodo.UI:SettingsCheckbox(category, "useDebuff", "디버프 아이콘",
        "플레이어의 디버프를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useDebuff = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
            dodo.CombatRefreshPreview()
        end)
    D(df_init)

    local _dfs_sub = {}
    local function DS(v) if v then _dfs_sub[#_dfs_sub+1] = v end return v end

    DS(dodo.UI:SettingsSlider(category, "debuffSize", "아이콘 크기",
        "디버프 아이콘의 크기를 설정합니다.",
        30, 80, 2, 56, "Integer", function(val)
            if dodoDB then dodoDB.debuffSize = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
            dodo.CombatRefreshPreview()
        end))

    DS(dodo.UI:SettingsSlider(category, "debuffMax", "최대 표시 개수",
        "화면에 표시할 최대 디버프 개수를 설정합니다.",
        1, 6, 1, 6, "Integer", function(val)
            if dodoDB then dodoDB.debuffMax = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
            dodo.CombatRefreshPreview()
        end))

    -- ── 커서 주문추적 탭 ──
    C(dodo.UI:SettingsSectionHeader(category, "커서 주문추적"))

    local cst_init, cst_setting = dodo.UI:SettingsCheckbox(category, "enableCursorSpellTracker", "커서 주문추적",
        "현재 직업/특성의 주요 스킬을 커서 근처에 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableCursorSpellTracker = val end
            if dodo.CursorSpellTrackerSetEnabled then dodo.CursorSpellTrackerSetEnabled(val) end
            dodo.CombatRefreshPreview()
        end)
    C(cst_init)

    local _csts_sub = {}
    local function CS(v) if v then _csts_sub[#_csts_sub+1] = v end return v end

    local function cst_apply()
        if dodo.CursorSpellTrackerApplyLayout then dodo.CursorSpellTrackerApplyLayout() end
        dodo.CombatRefreshPreview()
    end

    CS(dodo.UI:SettingsSlider(category, "cursorSpellTrackerX", "가로 위치",
        "커서 기준 가로 위치를 설정합니다.",
        -150, 150, 1, 44, "Integer", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerX = val end
            cst_apply()
        end))

    CS(dodo.UI:SettingsSlider(category, "cursorSpellTrackerY", "세로 위치",
        "커서 기준 세로 위치를 설정합니다.",
        -150, 150, 1, -34, "Integer", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerY = val end
            cst_apply()
        end))

    local cst_row_setting, cst_row_init = dodo.UI:SettingsDropDown(category, "cursorSpellTrackerRowCount", "열 배치",
        "2열: 차단기는 위쪽 줄, 군중제어는 아래쪽 줄에 배치합니다.",
        { { value = "1", text = "1열" }, { value = "2", text = "2열" } },
        "2", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerRowCount = val end
            cst_apply()
        end)
    CS(cst_row_init)

    -- 열 간격: 열 배치 하위 (2열일 때만 표시, predicate는 하단에서 부착)
    local cst_row_gap_init = dodo.UI:SettingsSlider(category, "cursorSpellTrackerRowGap", "열 간격",
        "1열과 2열 사이 세로 간격을 설정합니다.",
        0, 20, 1, 0, "Integer", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerRowGap = val end
            cst_apply()
        end)

    CS(dodo.UI:SettingsSlider(category, "cursorSpellTrackerIconSize", "아이콘 크기",
        "커서 아이콘 크기를 설정합니다.",
        16, 48, 1, 26, "Integer", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerIconSize = val end
            cst_apply()
        end))

    CS(dodo.UI:SettingsSlider(category, "cursorSpellTrackerIconGap", "아이콘 간격",
        "같은 줄 아이콘 사이 가로 간격을 설정합니다.",
        0, 10, 1, 0, "Integer", function(val)
            if dodoDB then dodoDB.cursorSpellTrackerIconGap = val end
            cst_apply()
        end))

    -- 주문 목록 (모든 직업/특성 켜기/끄기, 위젯은 99 Options Preview.lua dodoCSTSpellListMixin)
    CS(dodo.UI:SettingsSectionHeader(category, "주문 목록"))
    if layout then
        local list_init = Settings.CreatePanelInitializer("dodoCSTSpellListTemplate", {})
        list_init.GetExtent = function() return dodoCSTSpellListMixin.GetExtent() end
        list_init.InitFrame = function(_, frame)
            frame:SetHeight(dodoCSTSpellListMixin.GetExtent())
            if not frame._dodo_init then
                frame._dodo_init = true
                Mixin(frame, dodoCSTSpellListMixin)
                frame:OnLoad()
            end
            frame:Update()
        end
        layout:AddInitializer(list_init)
        CS(list_init)
    end

    -- ── 블러드 & 전투부활 탭 ──
    B(dodo.UI:SettingsSectionHeader(category, "블러드 & 전투부활"))

    local bb_init, bb_setting = dodo.UI:SettingsCheckbox(category, "useBloodBrez", "블러드 & 전투부활",
        "블러드 디버프와 전투부활 현황을 추적합니다.",
        true, function(val)
            if dodoDB then dodoDB.useBloodBrez = val end
            if dodo.BloodBrez then dodo.BloodBrez() end
            dodo.CombatRefreshPreview()
        end)
    B(bb_init)

    local _bbs_sub = {}
    local function BS(v) if v then _bbs_sub[#_bbs_sub+1] = v end return v end

    BS(dodo.UI:SettingsSlider(category, "blbrIconSize", "아이콘 크기",
        "블러드 & 전투부활 아이콘의 크기를 설정합니다.",
        30, 60, 2, 46, "Integer", function(val)
            if dodoDB then dodoDB.blbrIconSize = val end
            if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end
            dodo.CombatRefreshPreview()
        end))

    BS(dodo.UI:SettingsSlider(category, "blbrIconPadding", "아이콘 간격",
        "블러드 & 전투부활 아이콘 사이 간격을 설정합니다.",
        0, 10, 1, 2, "Integer", function(val)
            if dodoDB then dodoDB.blbrIconPadding = val end
            if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end
            dodo.CombatRefreshPreview()
        end))

    -- ── 태세 탭 ──
    S(dodo.UI:SettingsSectionHeader(category, "태세 아이콘"))

    local st_init, st_setting = dodo.UI:SettingsCheckbox(category, "enableStance", "태세 아이콘 ",
        "전사의 현재 태세를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableStance = val end
            if dodo.StanceApply then dodo.StanceApply(val) end
            dodo.CombatRefreshPreview()
        end)
    S(st_init)

    local _sts_sub = {}
    local function SS(v) if v then _sts_sub[#_sts_sub+1] = v end return v end

    SS(dodo.UI:SettingsSlider(category, "stanceIconSize", "아이콘 크기",
        "태세 아이콘의 크기를 설정합니다.",
        40, 100, 2, 80, "Integer", function(val)
            if dodoDB then dodoDB.stanceIconSize = val end
            if dodo.StanceApplyIconSize then dodo.StanceApplyIconSize(val) end
            dodo.CombatRefreshPreview()
        end))

    -- 탭 전환 시 AddShownPredicate 재평가 트리거
    dodo.CombatSetTabChangeFn(function()
        if master_setting then master_setting:SetValue(master_setting:GetValue()) end
    end)

    local function _tab() return dodo.CombatGetPreviewTab() end
    local function _rb_shown() return master_setting:GetValue() and _tab() == 1 end
    local function _df_shown() return master_setting:GetValue() and _tab() == 2 end
    local function _cst_shown() return master_setting:GetValue() and _tab() == 3 end
    local function _bb_shown() return master_setting:GetValue() and _tab() == 4 end
    local function _st_shown() return master_setting:GetValue() and _tab() == 5 end

    for _, v in ipairs(_rb_sub) do if v.AddShownPredicate then v:AddShownPredicate(_rb_shown) end end
    local function _rbs_shown() return _rb_shown() and (rb_setting and rb_setting:GetValue()) end
    for _, v in ipairs(_rbs_sub) do if v.AddShownPredicate then v:AddShownPredicate(_rbs_shown) end end
    for _, v in ipairs(_df_sub) do if v.AddShownPredicate then v:AddShownPredicate(_df_shown) end end
    local function _dfs_shown() return _df_shown() and (df_setting and df_setting:GetValue()) end
    for _, v in ipairs(_dfs_sub) do if v.AddShownPredicate then v:AddShownPredicate(_dfs_shown) end end
    for _, v in ipairs(_cst_sub) do if v.AddShownPredicate then v:AddShownPredicate(_cst_shown) end end
    local function _csts_shown() return _cst_shown() and (cst_setting and cst_setting:GetValue()) end
    for _, v in ipairs(_csts_sub) do if v.AddShownPredicate then v:AddShownPredicate(_csts_shown) end end
    local function _cst_two_rows() return _csts_shown() and cst_row_setting and cst_row_setting:GetValue() == "2" end
    if cst_row_gap_init and cst_row_init and cst_row_gap_init.SetParentInitializer then
        cst_row_gap_init:SetParentInitializer(cst_row_init, _cst_two_rows)
    end
    if cst_row_gap_init and cst_row_gap_init.AddShownPredicate then
        cst_row_gap_init:AddShownPredicate(_cst_two_rows)
    end
    for _, v in ipairs(_bb_sub) do if v.AddShownPredicate then v:AddShownPredicate(_bb_shown) end end
    local function _bbs_shown() return _bb_shown() and (bb_setting and bb_setting:GetValue()) end
    for _, v in ipairs(_bbs_sub) do if v.AddShownPredicate then v:AddShownPredicate(_bbs_shown) end end
    for _, v in ipairs(_st_sub) do if v.AddShownPredicate then v:AddShownPredicate(_st_shown) end end
    local function _sts_shown() return _st_shown() and (st_setting and st_setting:GetValue()) end
    for _, v in ipairs(_sts_sub) do if v.AddShownPredicate then v:AddShownPredicate(_sts_shown) end end
end, 4000)
