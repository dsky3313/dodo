-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local _G = _G

-- ==============================
-- 설정 기본값
-- ==============================
dodo.UF_DEFAULTS = {
    enableUnitframeModule = true,
    power   = { player = true,  target = true,  focus = false, boss = true  },
    castbar = { player = true,  target = true,  focus = false, boss = true  },
    buffs   = { player = false, target = true,  focus = false, boss = true  },
    debuffs = { player = false, target = false, focus = false, boss = false },
    absorb  = { player = true,  target = false, focus = false, boss = false },
    combat  = { player = true,  target = false, focus = false, boss = false },
    rest    = { player = true,  target = false, focus = false, boss = false },
    leader  = { player = true,  target = true,  focus = false, boss = false },
}

-- ==============================
-- 설정 키
-- ==============================
dodo.UF_DB_KEYS = {
    power   = { player = "unitframePowerPlayer",   target = "unitframePowerTarget",   focus = "unitframePowerFocus",   boss = "unitframePowerBoss"   },
    castbar = { player = "unitframeCastbarPlayer",  target = "unitframeCastbarTarget",  focus = "unitframeCastbarFocus",  boss = "unitframeCastbarBoss"  },
    buffs   = { player = "unitframeBuffsPlayer",   target = "unitframeBuffsTarget",   focus = "unitframeBuffsFocus",   boss = "unitframeBuffsBoss"   },
    debuffs = { player = "unitframeDebuffsPlayer",  target = "unitframeDebuffsTarget",  focus = "unitframeDebuffsFocus",  boss = "unitframeDebuffsBoss"  },
    absorb  = { player = "unitframeAbsorbPlayer",  target = "unitframeAbsorbTarget",  focus = "unitframeAbsorbFocus"  },
    combat  = { player = "unitframeCombatPlayer",  target = "unitframeCombatTarget",  focus = "unitframeCombatFocus",  boss = "unitframeCombatBoss"  },
    rest    = { player = "unitframeRestPlayer"  },
    leader  = { player = "unitframeLeaderPlayer",  target = "unitframeLeaderTarget",  focus = "unitframeLeaderFocus",  boss = "unitframeLeaderBoss"  },
}

local POWER_KEYS     = dodo.UF_DB_KEYS.power
local POWER_DEFAULTS = dodo.UF_DEFAULTS.power
local CASTBAR_KEYS     = dodo.UF_DB_KEYS.castbar
local CASTBAR_DEFAULTS = dodo.UF_DEFAULTS.castbar
local BUFFS_KEYS     = dodo.UF_DB_KEYS.buffs
local BUFFS_DEFAULTS = dodo.UF_DEFAULTS.buffs
local DEBUFFS_KEYS     = dodo.UF_DB_KEYS.debuffs
local DEBUFFS_DEFAULTS = dodo.UF_DEFAULTS.debuffs
local ABSORB_KEYS     = dodo.UF_DB_KEYS.absorb
local ABSORB_DEFAULTS = dodo.UF_DEFAULTS.absorb
local SIM_COMBAT_KEYS = dodo.UF_DB_KEYS.combat
local SIM_LEADER_KEYS = dodo.UF_DB_KEYS.leader

-- MultiDropDown은 nil을 true(체크)로 해석 — false 기본값 항목 초기화 필요
local FALSE_DEFAULTS = {
	unitframePowerFocus    = false,
	unitframeCastbarFocus  = false,
	unitframeBuffsPlayer   = false,
	unitframeBuffsFocus    = false,
	unitframeAbsorbTarget  = false,
	unitframeAbsorbFocus   = false,
	-- 전투 표시 (player만 기본 true)
	unitframeCombatTarget  = false,
	unitframeCombatFocus   = false,
	unitframeCombatBoss    = false,
	-- 휴식 표시 (player만 기본 true)
	unitframeRestTarget    = false,
	unitframeRestFocus     = false,
	unitframeRestBoss      = false,
	-- 파티장 표시 (player·target 기본 true)
	unitframeLeaderFocus   = false,
	unitframeLeaderBoss    = false,
	-- 약화효과 (모두 기본 false)
	unitframeDebuffsPlayer = false,
	unitframeDebuffsTarget = false,
	unitframeDebuffsFocus  = false,
	unitframeDebuffsBoss   = false,
}

-- ==============================
-- 유닛별 업데이트 함수
-- ==============================
local function apply_power(unit)
    if unit == "boss" then
        for i = 1, 5 do
            local f = _G["dodoBossFrame" .. i]
            if f and f.Power then f.Power:ForceUpdate() end
        end
    else
        local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
        local f = map[unit]
        if f and f.Power then f.Power:ForceUpdate() end
    end
end

local function apply_castbar(unit, enabled)
    if unit == "boss" then
        for i = 1, 5 do
            local f = _G["dodoBossFrame" .. i]
            if f and f.Castbar then
                if enabled then f:EnableElement("Castbar") else f:DisableElement("Castbar") end
            end
        end
    else
        local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
        local f = map[unit]
        if f and f.Castbar then
            if enabled then f:EnableElement("Castbar") else f:DisableElement("Castbar") end
        end
    end
end

local function apply_buffs(unit, enabled)
    if unit == "boss" then
        for i = 1, 5 do
            local f = _G["dodoBossFrame" .. i]
            if f and f.Buffs then
                if enabled then f.Buffs:Show() else f.Buffs:Hide() end
            end
        end
    else
        local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
        local f = map[unit]
        if f and f.Buffs then
            if enabled then f.Buffs:Show() else f.Buffs:Hide() end
        end
    end
end

local function apply_debuffs(unit, enabled)
    if unit == "boss" then
        for i = 1, 5 do
            local f = _G["dodoBossFrame" .. i]
            if f and f.Debuffs then
                if enabled then f.Debuffs:Show() else f.Debuffs:Hide() end
            end
        end
    else
        local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
        local f = map[unit]
        if f and f.Debuffs then
            if enabled then f.Debuffs:Show() else f.Debuffs:Hide() end
        end
    end
end

local function apply_absorb(unit)
    local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
    local f = map[unit]
    if f and f.Health then f.Health:ForceUpdate() end
end

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("유닛프레임", function(category)
	local D = dodo.UF_DEFAULTS

	-- false가 기본인 항목 초기화 (nil → MultiDropDown이 체크로 오인 방지)
	if dodoDB then
		for key, val in pairs(FALSE_DEFAULTS) do
			if dodoDB[key] == nil then dodoDB[key] = val end
		end
	end

	-- 마스터 토글
	local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableUnitframeModule", "유닛프레임 모듈 활성화",
		"유닛프레임 모듈을 활성화합니다.",
		D.enableUnitframeModule, function(val)
			if dodoDB then dodoDB.enableUnitframeModule = val end
			if dodo.UpdateUnitframeModuleState then dodo.UpdateUnitframeModuleState() end
			dodo.UnitframeRefreshPreview()
		end)

	-- T() = 유닛탭(플레이어/대상/우두머리)에서만 보이는 항목 수집
	-- P() = 파티프레임 탭에서만 보이는 항목 수집
	-- → 하단 AddShownPredicate에서 일괄 부착
	local _unit_sub  = {}
	local _party_sub = {}
	local function T(v) if v then _unit_sub[#_unit_sub+1]  = v end return v end
	local function P(v) if v then _party_sub[#_party_sub+1] = v end return v end

	-- 미리보기는 두 목록 모두 제외: 탭에 무관하게 항상 표시되어야 함
	-- (_unit_sub에 넣으면 파티 탭 선택 시 predicate가 false → 프레임 자체가 숨겨짐)
	local _preview_init = dodo.UI:SettingsTabbedPreview(category, { "플레이어", "대상", "주시대상", "우두머리", "파티프레임" }, dodoUnitframePreviewMixin)

	-- 구성 요소 섹션
	T(dodo.UI:SettingsSectionHeader(category, "구성 요소"))

	-- 자원 바
	local power_init = T(dodo.UI:SettingsMultiDropDown(category, "자원 바", {
		{ text = "플레이어", key = POWER_KEYS.player },
		{ text = "대상",     key = POWER_KEYS.target },
		{ text = "주시대상", key = POWER_KEYS.focus },
		{ text = "우두머리", key = POWER_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(POWER_KEYS) do
			if k == key then apply_power(unit) end
		end
		dodo.UnitframeRefreshPreview()
	end, "유닛프레임 아래에 자원 바를 표시합니다."))
	-- PanelInitializer는 GetSetting 없음 → SetParentInitializer 내부 크래시 방지
	if power_init then power_init.GetSetting = function() return nil end end

	local mana_init = dodo.UI:SettingsCheckbox(category, "unitframePowerOnlyMana", "2차자원이 마나일 경우에만 활성화",
		"2차자원이 마나일 때만 자원 바를 표시합니다.\n해당 클래스 : 드루이드, 주술사, 암흑사제",
		true, function(val)
			if dodoDB then dodoDB.unitframePowerOnlyMana = val end
			apply_power("player")
		end)
	if mana_init and power_init and mana_init.SetParentInitializer then
		mana_init:SetParentInitializer(power_init)
	end

	-- 탭 전환 시 설정 리스트 재평가 트리거
	-- OnTabSelected → UnitframeSetTabChangeFn() → SETTING_VALUE_CHANGED 발생
	-- → 설정 패널이 모든 AddShownPredicate 재실행 → T/P 항목 표시/숨김 전환
	dodo.UnitframeSetTabChangeFn(function()
		if master_setting then
			master_setting:SetValue(master_setting:GetValue())
		end
	end)

	-- 캐스팅바
	T(dodo.UI:SettingsMultiDropDown(category, "캐스팅바", {
		{ text = "플레이어", key = CASTBAR_KEYS.player },
		{ text = "대상",     key = CASTBAR_KEYS.target },
		{ text = "주시대상", key = CASTBAR_KEYS.focus },
		{ text = "우두머리", key = CASTBAR_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local unit_map = {
			[CASTBAR_KEYS.player] = "player",
			[CASTBAR_KEYS.target] = "target",
			[CASTBAR_KEYS.focus]  = "focus",
			[CASTBAR_KEYS.boss]   = "boss",
		}
		local unit = unit_map[key]
		if unit then apply_castbar(unit, selected) end
		dodo.UnitframeRefreshPreview()
	end, "주문을 시전할 때, 시전바를 표시합니다."))

	-- 보호막
	T(dodo.UI:SettingsMultiDropDown(category, "보호막 표시", {
		{ text = "플레이어", key = ABSORB_KEYS.player },
		{ text = "대상",     key = ABSORB_KEYS.target },
		{ text = "주시대상", key = ABSORB_KEYS.focus },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(ABSORB_KEYS) do
			if k == key then apply_absorb(unit) end
		end
		dodo.UnitframeRefreshPreview()
	end, "생명력 바에 보호막과 흡수량을 표시합니다."))

	-- 강화 및 약화 효과 섹션
	T(dodo.UI:SettingsSectionHeader(category, "강화 및 약화 효과"))

	-- 강화효과
	T(dodo.UI:SettingsMultiDropDown(category, "강화효과", {
		{ text = "플레이어", key = BUFFS_KEYS.player },
		{ text = "대상",     key = BUFFS_KEYS.target },
		{ text = "주시대상", key = BUFFS_KEYS.focus },
		{ text = "우두머리", key = BUFFS_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(BUFFS_KEYS) do
			if k == key then apply_buffs(unit, selected) end
		end
		dodo.UnitframeRefreshPreview()
	end, "강화효과 아이콘을 표시합니다."))

	-- 약화효과
	T(dodo.UI:SettingsMultiDropDown(category, "약화효과", {
		{ text = "플레이어", key = DEBUFFS_KEYS.player },
		{ text = "대상",     key = DEBUFFS_KEYS.target },
		{ text = "주시대상", key = DEBUFFS_KEYS.focus },
		{ text = "우두머리", key = DEBUFFS_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(DEBUFFS_KEYS) do
			if k == key then apply_debuffs(unit, selected) end
		end
		dodo.UnitframeRefreshPreview()
	end, "약화효과 아이콘을 표시합니다."))

	-- 추가기능 섹션
	T(dodo.UI:SettingsSectionHeader(category, "추가기능"))

	local function toggle(frame, elem, selected)
		if not frame then return end
		if selected then frame:EnableElement(elem) else frame:DisableElement(elem) end
	end

	-- 파티장 표시
	T(dodo.UI:SettingsMultiDropDown(category, "파티장 표시", {
		{ text = "플레이어", key = "unitframeLeaderPlayer" },
		{ text = "대상",     key = "unitframeLeaderTarget" },
		{ text = "주시대상", key = "unitframeLeaderFocus"  },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local map = { unitframeLeaderPlayer = dodo.PlayerFrame, unitframeLeaderTarget = dodo.TargetFrame, unitframeLeaderFocus = dodo.FocusFrame }
		if map[key] then toggle(map[key], 'LeaderIndicator', selected) end
		dodo.UnitframeRefreshPreview()
	end, "파티장 아이콘을 표시합니다."))

	-- 휴식 표시
	T(dodo.UI:SettingsMultiDropDown(category, "휴식 표시", {
		{ text = "플레이어", key = "unitframeRestPlayer" },
		{ text = "대상",     key = "unitframeRestTarget" },
		{ text = "주시대상", key = "unitframeRestFocus"  },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		if key == "unitframeRestPlayer" then toggle(dodo.PlayerFrame, 'RestingIndicator', selected) end
		dodo.UnitframeRefreshPreview()
	end, "휴식장소 아이콘을 표시합니다."))

	-- 전투 표시
	T(dodo.UI:SettingsMultiDropDown(category, "전투 표시", {
		{ text = "플레이어", key = "unitframeCombatPlayer" },
		{ text = "대상",     key = "unitframeCombatTarget" },
		{ text = "주시대상", key = "unitframeCombatFocus"  },
		{ text = "우두머리", key = "unitframeCombatBoss"   },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local map = { unitframeCombatPlayer = dodo.PlayerFrame, unitframeCombatTarget = dodo.TargetFrame, unitframeCombatFocus = dodo.FocusFrame }
		if map[key] then
			toggle(map[key], 'CombatIndicator', selected)
		elseif key == "unitframeCombatBoss" then
			for i = 1, 5 do toggle(_G['dodoBossFrame'..i], 'CombatIndicator', selected) end
		end
		dodo.UnitframeRefreshPreview()
	end, "전투 중 아이콘을 표시합니다."))

	-- 파티프레임 섹션
	P(dodo.UI:SettingsSectionHeader(category, "파티프레임"))

	P(dodo.UI:SettingsCheckbox(category, "enablePartyframeLeader", "파티장 아이콘",
	"파티장 아이콘을 표시합니다.",
	true, function(val)
		if dodoDB then dodoDB.enablePartyframeLeader = val end
		dodo.UnitframeRefreshPreview()
	end))

	P(dodo.UI:SettingsCheckbox(category, "enablePartyframeOvershield", "초과보호막 표시",
	"파티원의 초과보호막을 체력바 위에 표시합니다.",
	true, function(val)
		if dodoDB then dodoDB.enablePartyframeOvershield = val end
		dodo.UnitframeRefreshPreview()
	end))

	P(dodo.UI:SettingsCheckbox(category, "usePartyframeAurasHealthColor", "체력바 색상 변경",
		"특정 버프를 파티원에게 시전했을 때, 해당 파티원의 체력바 색상을 변경합니다.",
		true, function(val)
			if dodoDB then dodoDB.usePartyframeAurasHealthColor = val end
			dodo.UnitframeRefreshPreview()
		end))

	-- predicate 정의: 현재 선택된 탭 + 마스터 토글로 항목 표시 여부 결정
	local function _unit_shown()   -- 유닛 탭(비파티)일 때만 표시
		return master_setting:GetValue() and dodo.UnitframeGetPreviewUnit() ~= "party"
	end
	local function _party_shown()  -- 파티프레임 탭일 때만 표시
		return master_setting:GetValue() and dodo.UnitframeGetPreviewUnit() == "party"
	end
	-- 미리보기는 마스터 ON이면 탭 무관하게 항상 표시
	if _preview_init and _preview_init.AddShownPredicate then
		_preview_init:AddShownPredicate(function() return master_setting:GetValue() end)
	end
	for _, v in ipairs(_unit_sub)  do if v.AddShownPredicate then v:AddShownPredicate(_unit_shown)  end end
	for _, v in ipairs(_party_sub) do if v.AddShownPredicate then v:AddShownPredicate(_party_shown) end end
	-- mana_init: 마스터 ON + 플레이어 탭일 때만 표시 (SetParentInitializer 이외 추가 조건)
	if mana_init and mana_init.AddShownPredicate then
		mana_init:AddShownPredicate(function()
			return master_setting:GetValue() and dodo.UnitframeGetPreviewUnit() == "player"
		end)
	end

end, 3000)
