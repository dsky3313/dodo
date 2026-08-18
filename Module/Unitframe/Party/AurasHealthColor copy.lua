-- ==============================
-- Inspired
-- ==============================
-- HarreksAdvancedRaidFrames (https://www.curseforge.com/wow/addons/advancedraidframes) - HealthColor 인디케이터
-- AuraContainer 기반 재작성 — GetAuraSlots() taint 회피

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
---@field expiring table|nil dodo.Colors 색상 — 만료임박 (미구현)
---@field expiringThreshold number|nil 만료임박 기준(초) (미구현)

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
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
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
local has_active_watchlist = false

local SPEC_WATCHLIST_RETRY_DELAY = 1
local SPEC_WATCHLIST_MAX_RETRIES = 10
local spec_watchlist_retry_count = 0

-- ==============================
-- AuraContainer 관리
-- ==============================
local unit_containers = {}
local pending_rebuild = false

local function destroy_container(unit)
	local container = unit_containers[unit]
	if container then
		container:SetEnabled(false)
		container:Hide()
		unit_containers[unit] = nil
	end
end

local function get_health_texture(frame)
	local healthBar = frame and frame.healthBar
	if not healthBar then return nil end
	return healthBar:GetStatusBarTexture()
end

local function create_container(frame)
	if not frame then return end
	local unit = frame.unit
	if not unit then return end

	destroy_container(unit)

	if not is_module_enabled() or not is_unit_enabled(unit) or not has_active_watchlist then
		return
	end

	if InCombatLockdown() then
		pending_rebuild = true
		return
	end

	local healthTexture = get_health_texture(frame)
	if not healthTexture then return end

	local displayedUnit = frame.displayedUnit or unit

	local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
	container:SetAllPoints(frame)
	container:SetUnit(displayedUnit)

	for spellId, cfg in pairs(current_spec_watchlist) do
		local color = cfg.active
		container:AddAuraSlot("hcslot_" .. spellId, "PLAYER|HELPFUL", {
			candidateFilters = {
				includeSpellIDs = { [spellId] = true },
			},
			initializeFrame = function(btn)
				local healthBar = frame.healthBar
				if healthBar then
					btn:SetFrameLevel(healthBar:GetFrameLevel())
				end
				local tint = btn:CreateTexture(nil, "ARTWORK")
				tint:SetAllPoints(healthTexture)
				local texPath = healthTexture:GetTexture()
				if texPath then
					tint:SetTexture(texPath)
				end
				tint:SetVertexColor(color.r, color.g, color.b)
			end
		})
	end

	container:SetEnabled(true)
	unit_containers[unit] = container
end

local function rebuild_all_containers()
	if InCombatLockdown() then
		pending_rebuild = true
		return
	end
	pending_rebuild = false

	for unit, container in pairs(unit_containers) do
		container:SetEnabled(false)
		container:Hide()
	end
	wipe(unit_containers)

	if not is_module_enabled() or not has_active_watchlist then return end

	for unit, frame in pairs(unit_frame_map) do
		create_container(frame)
	end
end

-- ==============================
-- spec watchlist 갱신
-- ==============================
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

	rebuild_all_containers()
end

-- ==============================
-- 후킹: unit -> frame 매핑 구축 + 컨테이너 생성
-- ==============================
local function on_frame_unit_updated(frame)
	if not frame then return end

	local old_unit = frame.dodoAurasHealthColorUnit
	local new_unit = frame.unit

	if old_unit and old_unit ~= new_unit then
		destroy_container(old_unit)
		if unit_frame_map[old_unit] == frame then
			unit_frame_map[old_unit] = nil
		end
		frame.dodoAurasHealthColorUnit = nil
	end

	if not is_tracked_unit(new_unit) then return end

	unit_frame_map[new_unit] = frame
	frame.dodoAurasHealthColorUnit = new_unit

	create_container(frame)
end

hooksecurefunc("CompactUnitFrame_SetUnit", on_frame_unit_updated)

-- ==============================
-- 이벤트
-- ==============================
local function on_event(self, event, unit)
	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		if unit == "player" then
			refresh_spec_watchlist()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending_rebuild then
			rebuild_all_containers()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		for _, container in pairs(unit_containers) do
			container:SetEnabled(false)
			container:Hide()
		end
		wipe(unit_containers)
		-- unit_frame_map 유지: CompactUnitFrame_SetUnit이 재발동 안 할 수 있음
		C_Timer.After(0.2, rebuild_all_containers)
	else
		-- GROUP_ROSTER_UPDATE
		C_Timer.After(0.2, rebuild_all_containers)
	end
end

local event_frame = CreateFrame("Frame")
event_frame:SetScript("OnEvent", on_event)

local function update_visual()
	if is_module_enabled() then
		event_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
		event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		event_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		rebuild_all_containers()
	else
		event_frame:UnregisterAllEvents()
		for _, container in pairs(unit_containers) do
			container:SetEnabled(false)
			container:Hide()
		end
		wipe(unit_containers)
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
				rebuild_all_containers()
			end
		}
	})

	dodo.RegisterEditModeSystemSetting(raid_system_id, {
		{
			name = "오라 (체력바 색상)",
			get = function() return dodoDB and dodoDB.useRaidframeAurasHealthColor ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.useRaidframeAurasHealthColor = checked end
				rebuild_all_containers()
			end
		}
	})
end
