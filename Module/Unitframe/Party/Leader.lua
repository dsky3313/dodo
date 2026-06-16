-- ==============================
-- Inspired
-- ==============================
-- GroupLeaderAssistantIcons (https://www.curseforge.com/wow/addons/glai)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Config = {
	defaultSize = 16,
	defaultX = 4,
	defaultY = 8,
	defaultIconAnchor = "TOPLEFT",
	defaultFrameAnchor = "TOPLEFT",
}

-- WoW 에디트모드 유닛프레임 특수 고유 ID 빌드 (안전 가드 적용)
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Raid = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

local raid_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)
local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)

local TEX_LEADER    = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local TEX_ASSISTANT = "Interface\\GroupFrame\\UI-Group-AssistantIcon"

local icon_by_frame = {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local ipairs = ipairs
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local pairs = pairs
local table_remove = table.remove
local type = type
local UnitExists = UnitExists
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local _G = _G

-- 단일 프레임에 아이콘 적용
local function apply_icon(frame)
	if not frame or frame:IsForbidden() then return end

	local unit = frame.unit
	if not unit or not UnitExists(unit) then
		local tex = icon_by_frame[frame]
		if tex then tex:Hide() end
		return
	end

	local texture
	if UnitIsGroupLeader(unit) then
		texture = TEX_LEADER
	elseif IsInRaid() and UnitIsGroupAssistant(unit) then
		texture = TEX_ASSISTANT
	end

	local tex = icon_by_frame[frame]

	if texture then
		if not tex then
			tex = frame:CreateTexture(nil, "OVERLAY")
			icon_by_frame[frame] = tex
		end

		local size = Config.defaultSize
		local x = Config.defaultX
		local y = Config.defaultY
		local icon_anchor = Config.defaultIconAnchor
		local frame_anchor = Config.defaultFrameAnchor

		tex:ClearAllPoints()
		tex:SetSize(size, size)
		tex:SetPoint(icon_anchor, frame, frame_anchor, x, y)
		tex:SetTexture(texture)
		tex:Show()

		-- 순정 아이콘 숨김
		if frame.leaderIcon then frame.leaderIcon:SetAlpha(0) end
		if frame.assistantIcon then frame.assistantIcon:SetAlpha(0) end
		if frame.LeaderIcon then frame.LeaderIcon:SetAlpha(0) end
		if frame.AssistantIcon then frame.AssistantIcon:SetAlpha(0) end
	else
		if tex then tex:Hide() end
		-- 순정 아이콘 복원
		if frame.leaderIcon then frame.leaderIcon:SetAlpha(1) end
		if frame.assistantIcon then frame.assistantIcon:SetAlpha(1) end
		if frame.LeaderIcon then frame.LeaderIcon:SetAlpha(1) end
		if frame.AssistantIcon then frame.AssistantIcon:SetAlpha(1) end
	end
end

local function clear_all_icons()
	for _, tex in pairs(icon_by_frame) do
		tex:Hide()
	end
end

-- ==============================
-- 프레임 열거 (원본 방식)
-- ==============================

local function enumerate_from_pool(pool)
	local frames = {}
	if pool and pool.EnumerateActive then
		for frame in pool:EnumerateActive() do
			frames[#frames + 1] = frame
		end
	end
	return frames
end

local function enumerate_party_frames()
	-- CompactPartyFrame (레이드스타일 파티)
	if CompactPartyFrame then
		if CompactPartyFrame.memberFramePool and CompactPartyFrame.memberFramePool.EnumerateActive then
			return enumerate_from_pool(CompactPartyFrame.memberFramePool)
		end
		local frames = {}
		for i = 1, 5 do
			local f = _G["CompactPartyFrameMember" .. i]
			if f then frames[#frames + 1] = f end
		end
		if #frames > 0 then return frames end
	end

	-- 순정 PartyFrame BFS
	local root = _G.PartyFrame
	if not root then return {} end

	local frames = {}
	local seen = {}
	local queue = { root }
	local MAX_DEPTH = 6
	local depths = { [root] = 0 }

	while #queue > 0 do
		local obj = table_remove(queue, 1)
		if obj and not seen[obj] then
			seen[obj] = true
			local depth = depths[obj] or 0

			if obj.unit and type(obj.unit) == "string" then
				local u = obj.unit
				if u == "player" or u:match("^party%d$") then
					frames[#frames + 1] = obj
				end
			end

			if depth < MAX_DEPTH and obj.GetChildren then
				for _, child in ipairs({ obj:GetChildren() }) do
					depths[child] = depth + 1
					queue[#queue + 1] = child
				end
			end
		end
	end
	return frames
end

local function enumerate_raid_frames()
	if not CompactRaidFrameContainer then return {} end

	if CompactRaidFrameContainer.memberFramePool and CompactRaidFrameContainer.memberFramePool.EnumerateActive then
		return enumerate_from_pool(CompactRaidFrameContainer.memberFramePool)
	end
	if CompactRaidFrameContainer.framePool and CompactRaidFrameContainer.framePool.EnumerateActive then
		return enumerate_from_pool(CompactRaidFrameContainer.framePool)
	end

	-- fallback BFS
	local frames = {}
	local seen = {}
	local seenUnit = {}
	local queue = { CompactRaidFrameContainer }
	local MAX_DEPTH = 8
	local depths = { [CompactRaidFrameContainer] = 0 }

	while #queue > 0 do
		local obj = table_remove(queue, 1)
		if obj and not seen[obj] then
			seen[obj] = true
			local depth = depths[obj] or 0
			local unit = obj.unit

			if type(unit) == "string" and unit:match("^raid%d+$") and not seenUnit[unit] then
				seenUnit[unit] = true
				frames[#frames + 1] = obj
			end

			if depth < MAX_DEPTH and obj.GetChildren then
				for _, child in ipairs({ obj:GetChildren() }) do
					depths[child] = depth + 1
					queue[#queue + 1] = child
				end
			end
		end
	end
	return frames
end

-- ==============================
-- 전체 업데이트
-- ==============================

local function update_all()
	local is_enabled = (dodoDB and dodoDB.enablePartyframeLeader ~= false)
	if not is_enabled then
		clear_all_icons()
		return
	end

	if not IsInGroup() then
		clear_all_icons()
		return
	end

	clear_all_icons()

	local frames
	if IsInRaid() then
		frames = enumerate_raid_frames()
	else
		frames = enumerate_party_frames()
	end

	for _, frame in ipairs(frames) do
		apply_icon(frame)
	end
end

-- ==============================
-- 초기화 및 이벤트 등록
-- ==============================

local function on_event(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			dodoDB = dodoDB or {}
			if dodoDB.enablePartyframeLeader == nil then dodoDB.enablePartyframeLeader = true end
		end
	elseif event == "PLAYER_LOGIN" then
		update_all()
	else
		update_all()
	end
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
init_frame:RegisterEvent("PARTY_LEADER_CHANGED")
init_frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
	dodo.RegisterEditModeSystemSetting(raid_system_id, {
		{
			name = "파티장/지원 아이콘 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeLeader ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeLeader = checked end
				update_all()
			end
		}
	})

	dodo.RegisterEditModeSystemSetting(party_system_id, {
		{
			name = "파티장/지원 아이콘 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeLeader ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeLeader = checked end
				update_all()
			end
		}
	})
end
