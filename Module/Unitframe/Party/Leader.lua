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
	defaultX = 2,
	defaultY = 6,
	defaultIconAnchor = "TOPLEFT",
	defaultFrameAnchor = "TOPLEFT",
}

local TEX_LEADER    = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local TEX_ASSISTANT = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local ICON_LAYER    = "ARTWORK"

-- ==============================
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local CompactPartyFrame = CompactPartyFrame
local CompactRaidFrameContainer = CompactRaidFrameContainer
local CreateFrame = CreateFrame
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UIParentLoadAddOn = UIParentLoadAddOn
local UnitExists = UnitExists
local UnitIsGroupAssistant = UnitIsGroupAssistant
local UnitIsGroupLeader = UnitIsGroupLeader
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local icon_by_frame = {}
local init_frame = CreateFrame("Frame")
local event_frame = nil

local function apply_defaults()
	if dodoDB.partyframeLeaderSize == nil then dodoDB.partyframeLeaderSize = Config.defaultSize end
	if dodoDB.partyframeLeaderX == nil then dodoDB.partyframeLeaderX = Config.defaultX end
	if dodoDB.partyframeLeaderY == nil then dodoDB.partyframeLeaderY = Config.defaultY end
	if dodoDB.partyframeLeaderIconAnchor == nil then dodoDB.partyframeLeaderIconAnchor = Config.defaultIconAnchor end
	if dodoDB.partyframeLeaderFrameAnchor == nil then dodoDB.partyframeLeaderFrameAnchor = Config.defaultFrameAnchor end
end

local function ensure_compact_frames_loaded()
	if CompactPartyFrame or CompactRaidFrameContainer then
		return true
	end

	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_CompactRaidFrames")
	elseif UIParentLoadAddOn then
		pcall(UIParentLoadAddOn, "Blizzard_CompactRaidFrames")
	end

	return (CompactPartyFrame ~= nil) or (CompactRaidFrameContainer ~= nil)
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function ensure_icon(frame)
	if not frame then return end
	if icon_by_frame[frame] then return end

	local size = dodoDB.partyframeLeaderSize or Config.defaultSize
	local x = dodoDB.partyframeLeaderX or Config.defaultX
	local y = dodoDB.partyframeLeaderY or Config.defaultY
	local icon_anchor = dodoDB.partyframeLeaderIconAnchor or Config.defaultIconAnchor
	local frame_anchor = dodoDB.partyframeLeaderFrameAnchor or Config.defaultFrameAnchor

	local tex = frame:CreateTexture(nil, ICON_LAYER)
	tex:SetSize(size, size)
	tex:SetPoint(icon_anchor, frame, frame_anchor, x, y)
	tex:Hide()

	icon_by_frame[frame] = tex
end

local function set_icon(frame, texture_path)
	ensure_icon(frame)
	local tex = icon_by_frame[frame]
	if not tex then return end

	if texture_path then
		-- 실시간 설정 좌표 및 크기 업데이트 적용
		local size = dodoDB.partyframeLeaderSize or Config.defaultSize
		local x = dodoDB.partyframeLeaderX or Config.defaultX
		local y = dodoDB.partyframeLeaderY or Config.defaultY
		local icon_anchor = dodoDB.partyframeLeaderIconAnchor or Config.defaultIconAnchor
		local frame_anchor = dodoDB.partyframeLeaderFrameAnchor or Config.defaultFrameAnchor

		tex:ClearAllPoints()
		tex:SetSize(size, size)
		tex:SetPoint(icon_anchor, frame, frame_anchor, x, y)

		tex:SetTexture(texture_path)
		tex:Show()
	else
		tex:SetTexture(nil)
		tex:Hide()
	end
end

local function clear_all_icons()
	for _, tex in pairs(icon_by_frame) do
		tex:SetTexture(nil)
		tex:Hide()
	end
end

local function apply_leader_assist(frame)
	if not frame then return end

	local unit = frame.unit
	if not unit or not UnitExists(unit) then
		set_icon(frame, nil)
		return
	end

	local texture
	if UnitIsGroupLeader(unit) then
		texture = TEX_LEADER
	elseif IsInRaid() and UnitIsGroupAssistant(unit) then
		texture = TEX_ASSISTANT
	end

	set_icon(frame, texture)
end

-- 프레임 탐색 헬퍼 (UI 계층 구조 분석)
local function enumerate_from_pool(pool)
	local frames = {}
	if pool and pool.EnumerateActive then
		for frame in pool:EnumerateActive() do
			frames[#frames + 1] = frame
		end
	end
	return frames, #frames
end

local function enumerate_raid_frames()
	if not CompactRaidFrameContainer then return {}, 0 end

	if CompactRaidFrameContainer.memberFramePool and CompactRaidFrameContainer.memberFramePool.EnumerateActive then
		return enumerate_from_pool(CompactRaidFrameContainer.memberFramePool)
	end
	if CompactRaidFrameContainer.framePool and CompactRaidFrameContainer.framePool.EnumerateActive then
		return enumerate_from_pool(CompactRaidFrameContainer.framePool)
	end

	local frames = {}
	local seen_obj = {}
	local seen_unit = {}
	local count = 0
	local queue = { { obj = CompactRaidFrameContainer, depth = 0 } }
	local MAX_DEPTH = 8

	while #queue > 0 do
		local node = table.remove(queue, 1)
		local obj, depth = node.obj, node.depth

		if obj and not seen_obj[obj] then
			seen_obj[obj] = true
			local unit = obj.unit
			local name = (obj.GetName and obj:GetName()) or nil
			local is_raid_unit = (type(unit) == "string") and unit:match("^raid%d+$")
			local is_member_frame = (type(name) == "string") and name:match("^CompactRaidGroup%d+Member%d+$")

			if is_raid_unit and not seen_unit[unit] then
				seen_unit[unit] = true
				count = count + 1
				frames[#frames + 1] = obj
			end

			if is_raid_unit and is_member_frame then
				-- prune
			else
				if depth < MAX_DEPTH and obj.GetChildren then
					local children = { obj:GetChildren() }
					for _, child in ipairs(children) do
						queue[#queue + 1] = { obj = child, depth = depth + 1 }
					end
				end
			end
		end
	end

	return frames, count
end

local function enumerate_raid_style_party_frames()
	if not CompactPartyFrame then return {}, 0 end

	if CompactPartyFrame.memberFramePool and CompactPartyFrame.memberFramePool.EnumerateActive then
		return enumerate_from_pool(CompactPartyFrame.memberFramePool)
	end

	local frames = {}
	local n = 0
	for i = 1, 5 do
		local frame = _G["CompactPartyFrameMember" .. i]
		if frame then
			n = n + 1
			frames[#frames + 1] = frame
		end
	end
	return frames, n
end

local function enumerate_default_party_frames()
	local frames = {}
	local seen = {}
	local n = 0
	local root = _G.PartyFrame
	if not root then return frames, 0 end

	local queue = { { obj = root, depth = 0 } }
	local MAX_DEPTH = 6

	while #queue > 0 do
		local node = table.remove(queue, 1)
		local obj, depth = node.obj, node.depth

		if obj and not seen[obj] then
			seen[obj] = true
			if obj.unit and type(obj.unit) == "string" then
				local u = obj.unit
				if u == "player" or u:match("^party%d$") then
					n = n + 1
					frames[#frames + 1] = obj
				end
			end

			if depth < MAX_DEPTH and obj.GetChildren then
				local children = { obj:GetChildren() }
				for _, child in ipairs(children) do
					queue[#queue + 1] = { obj = child, depth = depth + 1 }
				end
			end
		end
	end

	return frames, n
end

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function update_all()
	if not IsInGroup() then
		clear_all_icons()
		return
	end

	ensure_compact_frames_loaded()
	clear_all_icons()

	if IsInRaid() then
		local raid_frames, rn = enumerate_raid_frames()
		if rn > 0 then
			for _, frame in ipairs(raid_frames) do
				apply_leader_assist(frame)
			end
		end
		return
	end

	local rs_frames, rsn = enumerate_raid_style_party_frames()
	if rsn > 0 then
		for _, frame in ipairs(rs_frames) do
			apply_leader_assist(frame)
		end
		return
	end

	local def_frames, dn = enumerate_default_party_frames()
	if dn > 0 then
		for _, frame in ipairs(def_frames) do
			apply_leader_assist(frame)
		end
	end
end

local function update_visual()
	local is_enabled = (dodoDB and dodoDB.enablePartyframeLeader ~= false)
	if is_enabled then
		if not event_frame then
			event_frame = CreateFrame("Frame")
			event_frame:SetScript("OnEvent", on_event)
		end
		event_frame:RegisterEvent("GROUP_ROSTER_UPDATE")
		event_frame:RegisterEvent("PARTY_LEADER_CHANGED")
		event_frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
		update_all()
	else
		if event_frame then
			event_frame:UnregisterAllEvents()
		end
		clear_all_icons()
	end
end

local function initialize()
	if dodoDB and dodoDB.enablePartyframeLeader == nil then dodoDB.enablePartyframeLeader = true end
	apply_defaults()
	ensure_compact_frames_loaded()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, ...)
	if event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" then
		update_all()
	end
end

init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		dodoDB = dodoDB or {}
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		initialize()
		update_visual()
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
	dodo.RegisterEditModeModuleSetting("유닛프레임", {
		{
			name = "파티장/지원 아이콘 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeLeader ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeLeader = checked end
				update_visual()
			end
		}
	})
end
