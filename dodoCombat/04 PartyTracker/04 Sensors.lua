local _, ns = ...
local _G = _G
local CreateFrame = CreateFrame

function ns.HasTemplate(name)
	local X = _G.C_XMLUtil
	if not (X and X.GetTemplateInfo) then return false end
	local ok, info = pcall(X.GetTemplateInfo, name)
	return ok and info ~= nil
end

ns.TAIL_TEMPLATE = 'DisableUntrustedLayoutScriptsTemplate'

ns.SATED_IDS = { 57723, 57724, 80354, 95809, 160455, 264689, 390435 }

do
	local function InitSensorButton(b)
		pcall(b.SetSize, b, 1, 1)
		pcall(b.SetMouseClickEnabled, b, false)
		pcall(b.SetMouseMotionEnabled, b, false)
	end

	function ns.AddSensorGroup(container, key, filter, include, stride)
		return pcall(container.AddAuraGroup, container, key, filter, {
			maxFrameCount = 1,
			candidateFilters = { includeSpellIDs = include },
			initializeFrame = InitSensorButton,
			layout = { elementWidth = stride, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
		})
	end

	function ns.NewUnitSensor(host, unit, key, include, filter)
		local ok, c = pcall(CreateFrame, 'AuraContainer', nil, host, 'CustomAuraContainerTemplate')
		if not ok or not c then return nil, 'the client refused the AuraContainer frame' end
		c:SetSize(1, 1)
		c:SetPoint('TOPLEFT', _G.UIParent, 'TOPLEFT', -11, 0)
		pcall(c.EnableMouse, c, false)
		local okG, err = ns.AddSensorGroup(c, key, filter or 'HELPFUL', include, 50000)
		if not okG then return nil, tostring(err) end
		pcall(c.SetUnit, c, unit)
		pcall(c.SetEnabled, c, false)
		return c
	end

	function ns.SensorLit(c) return c:IsMouseOver(1e5, -1e5, 0, 0) end
end

