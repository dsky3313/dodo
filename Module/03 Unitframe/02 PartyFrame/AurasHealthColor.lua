-- ==============================
-- Inspired
-- ==============================
-- HarreksAdvancedRaidFrames - HealthColor 인디케이터
-- AuraContainer 기반 — GetAuraSlots() taint 회피

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

---@type table<number, table<number, { active: table }>>
local HealthColorWatchlist = {
	[264] = { -- 복원 주술사
		[61295] = { active = dodo.Colors.HealthColorActive }, -- 성난해일
	},
	[1473] = { -- 증강 기원사
		[410089] = { active = dodo.Colors.HealthColorActive },
	},
}

local Enum_EditModeSystem_UnitFrame      = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Raid  = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)
local raid_system_id  = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)

-- ==============================
-- 캐싱
-- ==============================
local C_Timer               = C_Timer
local CreateFrame           = CreateFrame
local GetSpecialization     = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local hooksecurefunc        = hooksecurefunc
local InCombatLockdown      = InCombatLockdown
local next                  = next
local pairs                 = pairs
local wipe                  = wipe

-- ==============================
-- 상태
-- ==============================
local unit_frame_map         = {}
local unit_containers        = {}
local pending_rebuild        = false
local current_spec_watchlist = {}
local has_active_watchlist   = false
local spec_retry_count       = 0
local RETRY_DELAY            = 1
local RETRY_MAX              = 10

-- ==============================
-- 가드
-- ==============================
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
-- AuraContainer
-- ==============================
local function destroy_container(unit)
	local container = unit_containers[unit]
	if container then
		container:SetEnabled(false)
		container:Hide()
		unit_containers[unit] = nil
	end
end

local function get_health_texture(frame)
	local hb = frame and frame.healthBar
	if not hb then return nil end
	return hb:GetStatusBarTexture()
end

local function create_container(frame)
	if not frame then return end
	local unit = frame.unit
	if not unit then return end

	destroy_container(unit)

	if not is_unit_enabled(unit) or not has_active_watchlist then return end
	if InCombatLockdown() then pending_rebuild = true; return end

	local healthTexture = get_health_texture(frame)
	if not healthTexture then return end

	local container = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
	container:SetAllPoints(frame)
	container:SetUnit(frame.displayedUnit or unit)

	for spellId, cfg in pairs(current_spec_watchlist) do
		local color = cfg.active
		container:AddAuraSlot("hcslot_" .. spellId, "PLAYER|HELPFUL", {
			candidateFilters = { includeSpellIDs = { [spellId] = true } },
			initializeFrame  = function(btn)
				local hb = frame.healthBar
				if hb then btn:SetFrameLevel(hb:GetFrameLevel()) end
				local tint = btn:CreateTexture(nil, "ARTWORK")
				tint:SetAllPoints(healthTexture)
				local texPath = healthTexture:GetTexture()
				if texPath then tint:SetTexture(texPath) end
				tint:SetVertexColor(color.r, color.g, color.b)
			end
		})
	end

	container:SetEnabled(true)
	unit_containers[unit] = container
end

local function rebuild_all_containers()
	if InCombatLockdown() then pending_rebuild = true; return end
	pending_rebuild = false

	for _, container in pairs(unit_containers) do
		container:SetEnabled(false)
		container:Hide()
	end
	wipe(unit_containers)

	if not has_active_watchlist then return end
	for _, frame in pairs(unit_frame_map) do create_container(frame) end
end

-- ==============================
-- spec watchlist 갱신
-- ==============================
local function refresh_spec_watchlist()
	local specIndex = GetSpecialization()
	local specID = specIndex and GetSpecializationInfo(specIndex)
	if not specID then
		if spec_retry_count < RETRY_MAX then
			spec_retry_count = spec_retry_count + 1
			C_Timer.After(RETRY_DELAY, refresh_spec_watchlist)
		end
		return
	end
	spec_retry_count         = 0
	current_spec_watchlist   = HealthColorWatchlist[specID] or {}
	has_active_watchlist     = next(current_spec_watchlist) ~= nil
	rebuild_all_containers()
end

-- ==============================
-- CompactUnitFrame 후킹
-- ==============================
local function on_frame_unit_updated(frame)
	if not frame then return end
	local old_unit = frame.dodoAurasHealthColorUnit
	local new_unit = frame.unit

	if old_unit and old_unit ~= new_unit then
		destroy_container(old_unit)
		if unit_frame_map[old_unit] == frame then unit_frame_map[old_unit] = nil end
		frame.dodoAurasHealthColorUnit = nil
	end

	if not is_tracked_unit(new_unit) then return end
	unit_frame_map[new_unit]          = frame
	frame.dodoAurasHealthColorUnit    = new_unit
	create_container(frame)
end

hooksecurefunc("CompactUnitFrame_SetUnit", on_frame_unit_updated)

-- ==============================
-- 이벤트
-- ==============================
local event_frame = CreateFrame("Frame")

local function update_visual()
	event_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	event_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	event_frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	rebuild_all_containers()
end

local function on_event(self, event, arg1)
	if event == "PLAYER_SPECIALIZATION_CHANGED" then
		if arg1 == "player" then refresh_spec_watchlist() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending_rebuild then rebuild_all_containers() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		for _, container in pairs(unit_containers) do
			container:SetEnabled(false)
			container:Hide()
		end
		wipe(unit_containers)
		-- unit_frame_map 유지: SetUnit이 재발동 안 할 수 있음
		C_Timer.After(0.2, rebuild_all_containers)
	else -- GROUP_ROSTER_UPDATE
		C_Timer.After(0.2, rebuild_all_containers)
	end
end

event_frame:SetScript("OnEvent", on_event)

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

