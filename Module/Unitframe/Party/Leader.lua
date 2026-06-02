-- ==============================
-- Inspired / Heavily Optimised & Rewritten
-- ==============================
-- GroupLeaderAssistantIcons (GLAI)의 아이디어를 바탕으로 
-- 프레임 탐색 루프와 이벤트를 모두 제거하고 Blizzard FrameXML 훅 기반으로 100% 재작성.
-- ==============================

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

local icon_by_frame = {}
local hooked_frames = {}

local function apply_defaults()
	if dodoDB.partyframeLeaderSize == nil then dodoDB.partyframeLeaderSize = Config.defaultSize end
	if dodoDB.partyframeLeaderX == nil then dodoDB.partyframeLeaderX = Config.defaultX end
	if dodoDB.partyframeLeaderY == nil then dodoDB.partyframeLeaderY = Config.defaultY end
	if dodoDB.partyframeLeaderIconAnchor == nil then dodoDB.partyframeLeaderIconAnchor = Config.defaultIconAnchor end
	if dodoDB.partyframeLeaderFrameAnchor == nil then dodoDB.partyframeLeaderFrameAnchor = Config.defaultFrameAnchor end
end

-- 프레임의 커스텀 아이콘 배치 및 갱신
local function update_frame_icon(frame)
	if not frame or frame:IsForbidden() then return end

	local is_enabled = (dodoDB and dodoDB.enablePartyframeLeader ~= false)
	local tex = icon_by_frame[frame]

	if not is_enabled then
		if tex then tex:Hide() end
		if frame.leaderIcon then frame.leaderIcon:SetAlpha(1) end
		if frame.assistantIcon then frame.assistantIcon:SetAlpha(1) end
		if frame.LeaderIcon then frame.LeaderIcon:SetAlpha(1) end
		if frame.AssistantIcon then frame.AssistantIcon:SetAlpha(1) end
		return
	end

	local unit = frame.displayedUnit or frame.unit
	if not unit or not UnitExists(unit) then
		if tex then tex:Hide() end
		return
	end

	local texture
	if UnitIsGroupLeader(unit) then
		texture = TEX_LEADER
	elseif IsInRaid() and UnitIsGroupAssistant(unit) then
		texture = TEX_ASSISTANT
	end

	if texture then
		if not tex then
			tex = frame:CreateTexture(nil, "OVERLAY")
			icon_by_frame[frame] = tex
		end

		local size = dodoDB.partyframeLeaderSize or Config.defaultSize
		local x = dodoDB.partyframeLeaderX or Config.defaultX
		local y = dodoDB.partyframeLeaderY or Config.defaultY
		local icon_anchor = dodoDB.partyframeLeaderIconAnchor or Config.defaultIconAnchor
		local frame_anchor = dodoDB.partyframeLeaderFrameAnchor or Config.defaultFrameAnchor

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
	end
end

-- 설정이 바뀔 때 모든 활성 프레임의 크기/위치 리셋용
local function update_visual()
	for frame in pairs(icon_by_frame) do
		update_frame_icon(frame)
	end
end

-- 새 프레임 셋업 시 호출되는 훅 함수
local function on_compact_frame_setup(frame)
	if not frame or frame:IsForbidden() then return end
	if hooked_frames[frame] then return end
	hooked_frames[frame] = true

	-- 프레임의 이벤트가 실행될 때 우리 아이콘도 업데이트
	frame:HookScript("OnEvent", function(self, event, ...)
		if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "PLAYER_ROLES_ASSIGNED" then
			update_frame_icon(self)
		end
	end)

	-- 프레임이 보여지거나 유닛이 설정될 때 업데이트 연동을 위해 OnShow 훅
	frame:HookScript("OnShow", function(self)
		update_frame_icon(self)
	end)

	update_frame_icon(frame)
end

-- 순정 파티 프레임 (PartyMemberFrame)에 직접 훅
local function hook_default_party_frames()
	for i = 1, 4 do
		local frame = _G["PartyMemberFrame" .. i]
		if frame and not hooked_frames[frame] then
			hooked_frames[frame] = true
			
			frame:HookScript("OnEvent", function(self, event, ...)
				if event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
					update_frame_icon(self)
				end
			end)
			frame:HookScript("OnShow", function(self)
				update_frame_icon(self)
			end)
			update_frame_icon(frame)
		end
	end
end

-- ==============================
-- Blizzard FrameXML 훅 바인딩 및 동적 지연 탐지
-- ==============================
local is_compact_hooked = false

local function try_hooks()
	if not is_compact_hooked and _G["DefaultCompactUnitFrameSetup"] then
		hooksecurefunc("DefaultCompactUnitFrameSetup", on_compact_frame_setup)
		is_compact_hooked = true
	end

	hook_default_party_frames()
end

-- ==============================
-- 초기화 및 이벤트 등록
-- ==============================
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("ADDON_LOADED")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			dodoDB = dodoDB or {}
			if dodoDB.enablePartyframeLeader == nil then dodoDB.enablePartyframeLeader = true end
			apply_defaults()
			try_hooks()
		elseif arg1 == "Blizzard_CompactRaidFrames" then
			try_hooks()
		end
	elseif event == "PLAYER_LOGIN" then
		try_hooks()
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
