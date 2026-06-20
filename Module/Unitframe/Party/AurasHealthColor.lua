-- ==============================
-- Inspired
-- ==============================
-- HarreksAdvancedRaidFrames (https://www.curseforge.com/wow/addons/advancedraidframes) - HealthColor 인디케이터
-- 기본(Blizzard) 프레임 분기 그대로: 후킹 없이 texture:SetVertexColor 직접 호출 + oldColor 백업/복구

---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- WoW 에디트모드 유닛프레임 특수 고유 ID 빌드 (안전 가드 적용)
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Raid = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

local raid_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)
local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)

-- ==============================
-- 체력바 색상 watchlist: specID -> { spellID -> { active = 유지중 색상, expiring = 만료임박 색상, expiringThreshold = 임박 기준(초) } }
-- 현재 캐릭터의 spec에 해당하는 표만 적용됨
-- ==============================
---@class HealthColorEntry
---@field active table dodo.Colors 색상 — 버프 유지중
---@field expiring table|nil dodo.Colors 색상 — 만료임박
---@field expiringThreshold number|nil 만료임박 기준(초)

---@type table<number, table<number, HealthColorEntry>>
local HealthColorWatchlist = {
	[264] = { -- 복원 주술사
		[61295] = {
			active = dodo.Colors.HealthColorActive, -- 성난해일 유지중 - 녹색
			expiring = dodo.Colors.HealthColorExpiring, -- 만료 임박 - 빨간색
			expiringThreshold = 4, -- 남은시간(초) 이하면 expiring 색 적용
		},
	},
	[1473] = { -- 증강 기원사
		[410089] = {
			active = dodo.Colors.HealthColorActive,
			expiring = dodo.Colors.HealthColorExpiring,
			expiringThreshold = 5,
		},
	},
}

-- ==============================
-- 캐싱
-- ==============================
local AuraUtil = AuraUtil
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local IsInGroup = IsInGroup
local issecretvalue = issecretvalue or function() return false end
local next = next
local pairs = pairs

-- ==============================
-- 활성화 가드
-- ==============================
local function is_module_enabled()
	return dodoDB and dodoDB.enableAurasHealthColor ~= false
end

local function is_unit_enabled(unit)
	if not unit then return false end
	if unit == "player" or unit:match("^party%d+$") then
		return dodoDB and dodoDB.usePartyframeAurasHealthColor ~= false
	elseif unit:match("^raid%d+$") then
		return dodoDB and dodoDB.useRaidframeAurasHealthColor ~= false
	end
	return false
end

local function is_tracked_unit(unit)
	return unit and (unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$"))
end

-- ==============================
-- 유닛 -> CompactUnitFrame 매핑 (CompactUnitFrame_SetUnit 후킹으로 구축, 풀 순회 없음)
-- ==============================
local unit_frame_map = {}

-- ==============================
-- 현재 spec에 해당하는 watchlist 선택
-- ==============================
local current_spec_watchlist = {}
local has_active_watchlist = false -- current_spec_watchlist 비어있으면 false (불필요한 aura 순회/ticker 차단)

local refresh_ticker -- 후방 선언 (틱커 섹션에서 할당)
local on_tick -- 후방 선언 (틱커 섹션에서 할당)

local SPEC_WATCHLIST_RETRY_DELAY = 1 -- 로그인 직후 spec 정보 미준비 시 재시도 간격(초)
local SPEC_WATCHLIST_MAX_RETRIES = 10
local spec_watchlist_retry_count = 0

local function refresh_spec_watchlist()
	local specIndex = GetSpecialization()
	local specID = specIndex and GetSpecializationInfo(specIndex)
	if not specID then
		if spec_watchlist_retry_count < SPEC_WATCHLIST_MAX_RETRIES then
			spec_watchlist_retry_count = spec_watchlist_retry_count + 1
			C_Timer.After(SPEC_WATCHLIST_RETRY_DELAY, refresh_spec_watchlist)
		end
		return
	end

	spec_watchlist_retry_count = 0
	current_spec_watchlist = HealthColorWatchlist[specID] or {}
	has_active_watchlist = next(current_spec_watchlist) ~= nil

	if refresh_ticker then refresh_ticker() end
	if on_tick then on_tick() end
end

-- ==============================
-- 체력바 색상 override (버프중 / 만료임박) 조회
-- ==============================
local health_color_result

local function health_color_aura_callback(aura)
	local sid = aura.spellId
	if not sid or issecretvalue(sid) then return false end

	local cfg = current_spec_watchlist[sid]
	if not cfg then return false end

	local color = cfg.active
	local duration = aura.duration
	local expirationTime = aura.expirationTime
	if cfg.expiring and expirationTime and expirationTime > 0 and duration and duration > 0 then
		local remaining = expirationTime - GetTime()
		if remaining <= (cfg.expiringThreshold or 0) then
			color = cfg.expiring
		end
	end

	health_color_result = color
	return true
end

local function get_health_color_override(unit)
	if not has_active_watchlist then return nil end

	health_color_result = nil
	AuraUtil.ForEachAura(unit, "HELPFUL", nil, health_color_aura_callback, true)
	return health_color_result
end

-- ==============================
-- 체력바 색상 적용/복구 — 후킹 없이 texture:SetVertexColor 직접 호출, oldColor 백업/복구
-- ==============================
local function apply_health_color(frame, color)
	local healthBar = frame.healthBar
	if not healthBar then return end
	local texture = healthBar:GetStatusBarTexture()
	if not texture then return end

	if color then
		if not frame.dodoAurasHealthColorOldColor then
			local r, g, b = texture:GetVertexColor()
			frame.dodoAurasHealthColorOldColor = { r = r, g = g, b = b }
		end
		texture:SetVertexColor(color.r, color.g, color.b)
	elseif frame.dodoAurasHealthColorOldColor then
		local old = frame.dodoAurasHealthColorOldColor
		texture:SetVertexColor(old.r, old.g, old.b)
		frame.dodoAurasHealthColorOldColor = nil
	end
end

-- ==============================
-- 메인 갱신
-- ==============================
local function update_unit_health_color(unit)
	if not is_tracked_unit(unit) then return end

	local frame = unit_frame_map[unit]
	if not frame then return end

	if not is_module_enabled() or not is_unit_enabled(unit) then
		apply_health_color(frame, nil)
		return
	end

	local override = get_health_color_override(frame.displayedUnit)
	apply_health_color(frame, override)
end

-- ==============================
-- 후킹: unit -> frame 매핑 구축 + 초기 적용
-- ==============================
local function on_frame_unit_updated(frame)
	if not frame then return end

	local old_unit = frame.dodoAurasHealthColorUnit
	local new_unit = frame.unit

	if old_unit and old_unit ~= new_unit then
		apply_health_color(frame, nil)
		if unit_frame_map[old_unit] == frame then
			unit_frame_map[old_unit] = nil
		end
		frame.dodoAurasHealthColorUnit = nil
	end

	if not is_tracked_unit(new_unit) then return end

	unit_frame_map[new_unit] = frame
	frame.dodoAurasHealthColorUnit = new_unit

	update_unit_health_color(new_unit)
end

hooksecurefunc("CompactUnitFrame_SetUnit", on_frame_unit_updated)

-- ==============================
-- 후킹: 체력바 색상 재계산(체력 변동/사망/연결끊김 등) 시 워치리스트 색으로 재덮어쓰기
-- ==============================
local function on_update_health_color(frame)
	if not frame then return end
	update_unit_health_color(frame.unit)
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", on_update_health_color)

-- ==============================
-- 틱커: 만료임박 색상 전환 (UNIT_AURA/체력변동 트리거만으론 만료시점 못 잡음)
-- ==============================
local AURAS_TICK_INTERVAL = 1
local auras_ticker

on_tick = function()
	for unit in pairs(unit_frame_map) do
		update_unit_health_color(unit)
	end
end

local function start_ticker()
	if auras_ticker then return end
	auras_ticker = C_Timer.NewTicker(AURAS_TICK_INTERVAL, on_tick)
end

local function stop_ticker()
	if auras_ticker then
		auras_ticker:Cancel()
		auras_ticker = nil
	end
end

refresh_ticker = function()
	if is_module_enabled() and IsInGroup() and has_active_watchlist then
		start_ticker()
	else
		stop_ticker()
	end
end

-- ==============================
-- 이벤트 — 버프 적용/해제 즉시 반영 + 그룹 변동 시 틱커 갱신
-- ==============================
local function on_event(self, event, unit)
	if event == "UNIT_AURA" then
		update_unit_health_color(unit)
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if unit == "player" then
			refresh_spec_watchlist()
			refresh_ticker()
			on_tick()
		end
	else
		if event == "PLAYER_ENTERING_WORLD" then
			refresh_spec_watchlist()
		end
		refresh_ticker()
	end
end

local event_frame = CreateFrame("Frame")
event_frame:SetScript("OnEvent", on_event)

local function update_visual()
	if is_module_enabled() then
		event_frame:RegisterEvent("UNIT_AURA")
		event_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
		event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		event_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		refresh_ticker()
	else
		event_frame:UnregisterAllEvents()
		stop_ticker()
		on_tick()
	end
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		dodoDB = dodoDB or {}
	elseif event == "PLAYER_LOGIN" then
		refresh_spec_watchlist()
		update_visual()
		self:UnregisterEvent("ADDON_LOADED")
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
	dodo.RegisterEditModeModuleSetting("인터페이스", {
		{
			name = "오라",
			get = function() return dodoDB and dodoDB.enableAurasHealthColor ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enableAurasHealthColor = checked end
				update_visual()
			end
		}
	})
end

if dodo.RegisterEditModeSystemSetting then
	dodo.RegisterEditModeSystemSetting(party_system_id, {
		{
			name = "오라 (체력바 색상)",
			get = function() return dodoDB and dodoDB.usePartyframeAurasHealthColor ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.usePartyframeAurasHealthColor = checked end
				on_tick()
			end
		}
	})

	dodo.RegisterEditModeSystemSetting(raid_system_id, {
		{
			name = "오라 (체력바 색상)",
			get = function() return dodoDB and dodoDB.useRaidframeAurasHealthColor ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.useRaidframeAurasHealthColor = checked end
				on_tick()
			end
		}
	})
end
