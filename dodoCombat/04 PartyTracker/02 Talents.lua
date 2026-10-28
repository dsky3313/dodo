local _, ns = ...
local _G = _G
local IsSecret = ns.IsSecret
local GetTime, hooksecurefunc = GetTime, hooksecurefunc

do
	local lastInspect = 0
	if _G.NotifyInspect then hooksecurefunc('NotifyInspect', function() lastInspect = GetTime() end) end

	function ns.SendInspect(unit, gap)
		if GetTime() - lastInspect < (gap or 2) then return false, 'wait' end
		local sheet = _G.InspectFrame
		if sheet and sheet:IsShown() then return false, 'wait' end
		if ns.Ask(_G.UnitIsVisible, unit) == false then return false, 'unit' end
		if ns.Ask(_G.CanInspect, unit) ~= true or not _G.NotifyInspect then return false, 'unit' end
		lastInspect = GetTime()
		pcall(_G.NotifyInspect, unit)
		return true
	end
end

do
	local consts = _G.Constants and _G.Constants.TraitConsts
	local INSPECT = (consts and consts.INSPECT_TRAIT_CONFIG_ID) or -1
	local wanted, index = {}, {}

	function ns.TalentWant(state, class, id)
		local list = state.ids[class]
		if not list then
			list = {}
			state.ids[class] = list
		end
		if state.all[id] ~= class then
			state.all[id] = class
			list[#list + 1] = id
		end
		wanted[id] = true
	end

	local function Index(T, tree, config)
		local nodes = T.GetTreeNodes(tree)
		if type(nodes) ~= 'table' then return nil, 0 end
		local idx, found = {}, 0
		for _, nodeID in ipairs(nodes) do
			local node = T.GetNodeInfo(config, nodeID)
			local entries = type(node) == 'table' and node.entryIDs
			if type(entries) == 'table' then
				for _, entryID in ipairs(entries) do
					local e = T.GetEntryInfo(config, entryID)
					local d = type(e) == 'table' and e.definitionID and T.GetDefinitionInfo(e.definitionID)
					local spell = type(d) == 'table' and d.spellID
					if spell and wanted[spell] then
						local spots = idx[spell]
						if not spots then
							spots = {}
							idx[spell] = spots
							found = found + 1
						end
						spots[#spots + 1] = { node = nodeID, entry = entryID }
					end
				end
			end
		end
		return idx, found
	end

	function ns.TalentRanks(state, class, config)
		config = config or INSPECT
		local T = _G.C_Traits
		local want = state.ids[class]
		if not (want and T and T.GetConfigInfo and T.GetTreeNodes and T.GetNodeInfo and T.GetEntryInfo and T.GetDefinitionInfo) then return nil end
		if config == INSPECT and T.HasValidInspectData and T.HasValidInspectData() == false then return nil end
		local info = T.GetConfigInfo(config)
		local trees = type(info) == 'table' and info.treeIDs
		if type(trees) ~= 'table' then return nil end
		local out
		local nodes = {}
		for _, tree in ipairs(trees) do
			local idx = index[tree]
			if not idx and (state.misses[tree] or 0) < 3 then
				local found
				idx, found = Index(T, tree, config)
				if idx and found > 0 then
					index[tree] = idx
				else
					idx = nil
					state.misses[tree] = (state.misses[tree] or 0) + 1
				end
			end
			if idx then
				for _, id in ipairs(want) do
					local spots = idx[id]
					if spots then
						local got = 0
						for _, spot in ipairs(spots) do
							local node = nodes[spot.node]
							if node == nil then
								node = T.GetNodeInfo(config, spot.node)
								nodes[spot.node] = node or false
							end
							if type(node) == 'table' and node.subTreeActive ~= false then
								local act, rank = node.activeEntry, node.activeRank
								if type(act) == 'table' and act.entryID == spot.entry and type(rank) == 'number' and rank > got then got = rank end
							end
						end
						out = out or {}
						out[id] = got
					end
				end
			end
		end
		return out
	end

	function ns.TalentLength(base, mods, ranks, spec, guess)
		local cd, mul = base, 1
		for _, mod in ipairs(mods) do
			local rank = 1
			if mod[1] then
				rank = ranks and ranks[mod[1]]
				if type(rank) ~= 'number' then
					if not guess then return nil end
					rank = mod.likely and 1 or 0
				end
			end
			if mod.spec and mod.spec ~= spec then rank = 0 end
			if rank > 0 then cd, mul = cd + (mod.add or 0) * rank, mul * (1 + (mod.pct or 0) * rank / 100) end
		end
		return math.floor(math.max(5, math.min(900, cd * mul)) + 0.5)
	end

	function ns.TalentConfig()
		local CT = _G.C_ClassTalents
		if not (CT and CT.GetActiveConfigID) then return nil end
		local ok, id = pcall(CT.GetActiveConfigID)
		if ok and type(id) == 'number' and not IsSecret(id) then return id end
		return nil
	end
end

