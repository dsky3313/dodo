---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 설정 기본값
-- ==============================
dodo.CST_DEFAULTS = {
    enableCursorSpellTracker    = true,
    cursorSpellTrackerIconSize  = 26,  -- 아이콘 크기
    cursorSpellTrackerIconGap   = 2,   -- 아이콘 간 간격 (가로)
    cursorSpellTrackerRowGap    = 2,   -- 열 간 간격 (세로, 2열 배치일 때만)
    cursorSpellTrackerX         = 44,  -- 커서 기준 X 오프셋
    cursorSpellTrackerY         = -34, -- 커서 기준 Y 오프셋
    cursorSpellTrackerRowCount  = "2", -- "1" = 전부 한 줄, "2" = group별 줄 분리 (1열 기준, 2열은 그 위)
}

-- group별 배치 열 (2열 배치일 때만 적용, 미지정 group은 1열)
dodo.CST_ROW_BY_GROUP = {
    cc = 1,        -- 군중제어
    interrupt = 2, -- 차단기
}

-- ==============================
-- /dd 설정 등록
-- ==============================
local function apply_layout()
    if dodo.CursorSpellTrackerApplyLayout then dodo.CursorSpellTrackerApplyLayout() end
    if dodo.CursorSpellTrackerRefreshPreview then dodo.CursorSpellTrackerRefreshPreview() end
end

dodo.RegisterOption("커서 주문추적", function(category)
    local D = dodo.CST_DEFAULTS

    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableCursorSpellTracker", "커서 주문추적 모듈 활성화",
        "현재 직업/특성의 주요 스킬을 커서 근처에 표시합니다.",
        D.enableCursorSpellTracker, function(val)
            dodoDB.enableCursorSpellTracker = val
            if dodo.CursorSpellTrackerSetEnabled then dodo.CursorSpellTrackerSetEnabled(val) end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsTabbedPreview(category, { "배치" }, dodoCursorSpellTrackerPreviewMixin))

    T(dodo.UI:SettingsSectionHeader(category, "배치"))

    T(dodo.UI:SettingsSlider(category, "cursorSpellTrackerX", "가로 위치",
        "커서 기준 가로 위치를 설정합니다.",
        -150, 150, 1, D.cursorSpellTrackerX, "Integer", function(val)
            dodoDB.cursorSpellTrackerX = val
            apply_layout()
        end))

    T(dodo.UI:SettingsSlider(category, "cursorSpellTrackerY", "세로 위치",
        "커서 기준 세로 위치를 설정합니다.",
        -150, 150, 1, D.cursorSpellTrackerY, "Integer", function(val)
            dodoDB.cursorSpellTrackerY = val
            apply_layout()
        end))
        
    local row_setting, row_init = dodo.UI:SettingsDropDown(category, "cursorSpellTrackerRowCount", "열 배치",
        "2열: 차단기는 위쪽 줄, 군중제어는 아래쪽 줄에 배치합니다.",
        { { value = "1", text = "1열" }, { value = "2", text = "2열" } },
        D.cursorSpellTrackerRowCount, function(val)
            dodoDB.cursorSpellTrackerRowCount = val
            apply_layout()
        end)
        T(row_init)

    -- 열 간격: 열 배치 하위 (2열일 때만 표시)
    local row_gap_init = dodo.UI:SettingsSlider(category, "cursorSpellTrackerRowGap", "열 간격",
        "1열과 2열 사이 세로 간격을 설정합니다.",
        0, 20, 1, D.cursorSpellTrackerRowGap, "Integer", function(val)
            dodoDB.cursorSpellTrackerRowGap = val
            apply_layout()
        end)
    local function _two_rows() return master_setting:GetValue() and row_setting:GetValue() == "2" end
    if row_gap_init and row_init and row_gap_init.SetParentInitializer then
        row_gap_init:SetParentInitializer(row_init, _two_rows)
    end
    if row_gap_init and row_gap_init.AddShownPredicate then
        row_gap_init:AddShownPredicate(_two_rows)
    end

    T(dodo.UI:SettingsSlider(category, "cursorSpellTrackerIconSize", "아이콘 크기",
        "커서 아이콘 크기를 설정합니다.",
        16, 48, 1, D.cursorSpellTrackerIconSize, "Integer", function(val)
            dodoDB.cursorSpellTrackerIconSize = val
            apply_layout()
        end))

    T(dodo.UI:SettingsSlider(category, "cursorSpellTrackerIconGap", "아이콘 간격",
        "같은 줄 아이콘 사이 가로 간격을 설정합니다.",
        0, 10, 1, D.cursorSpellTrackerIconGap, "Integer", function(val)
            dodoDB.cursorSpellTrackerIconGap = val
            apply_layout()
        end))


    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 7000)
