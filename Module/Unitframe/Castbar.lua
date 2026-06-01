-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local Enum = Enum
local issecretvalue = issecretvalue or function() return false end
local NineSliceUtil = NineSliceUtil

-- ==============================
-- 캐스팅바 공통 빌더
-- ==============================
function dodo.UnitframeCreateCastbar(self, uWidth)
	local castbar = self.Castbar
	if not castbar then
		castbar = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
		castbar:SetSize(uWidth - 22, 16)
		castbar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		castbar:SetStatusBarColor(1, 0.7, 0)

		castbar.timeToHold = 0.5
		castbar.hideTradeSkills = true
		castbar.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut

		-- 배경
		castbar.bg = castbar:CreateTexture(nil, 'BACKGROUND')
		castbar.bg:SetAllPoints()
		castbar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

		-- 테두리 (NineSlice)
		castbar.NineSlice = CreateFrame('Frame', nil, castbar, 'NineSliceCodeTemplate')
		castbar.NineSlice:SetPoint('TOPLEFT',     castbar, 'TOPLEFT',     -4,  3)
		castbar.NineSlice:SetPoint('BOTTOMRIGHT', castbar, 'BOTTOMRIGHT',  7, -6)
		castbar.NineSlice:SetFrameLevel(castbar:GetFrameLevel() + 3)
		castbar.NineSlice:SetScale(0.6)
		NineSliceUtil.ApplyUniqueCornersLayout(castbar.NineSlice, 'UI-HUD-ActionBar-Frame')

		-- 아이콘 (Icon)
		local icon = castbar:CreateTexture(nil, 'ARTWORK')
		icon:SetSize(16, 16)
		icon:SetPoint('LEFT', self.Health, 'BOTTOMLEFT', 0, -22)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		castbar.Icon = icon

		-- 아이콘 테두리
		local iconFrame = CreateFrame('Frame', nil, castbar)
		iconFrame:SetAllPoints(icon)
		iconFrame.NineSlice = CreateFrame('Frame', nil, iconFrame, 'NineSliceCodeTemplate')
		iconFrame.NineSlice:SetPoint('TOPLEFT',     iconFrame, 'TOPLEFT',     -4,  3)
		iconFrame.NineSlice:SetPoint('BOTTOMRIGHT', iconFrame, 'BOTTOMRIGHT',  7, -6)
		iconFrame.NineSlice:SetFrameLevel(iconFrame:GetFrameLevel() + 3)
		iconFrame.NineSlice:SetScale(0.6)
		NineSliceUtil.ApplyUniqueCornersLayout(iconFrame.NineSlice, 'UI-HUD-ActionBar-Frame')

		-- 스킬 이름 텍스트
		local text = castbar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
		text:SetPoint('LEFT', castbar, 'LEFT', 5, 0)
		text:SetPoint('RIGHT', castbar, 'RIGHT', -40, 0)
		text:SetJustifyH('LEFT')
		local fontPath, _, fontFlags = text:GetFont()
		text:SetFont(fontPath, 9, fontFlags)
		castbar.Text = text

		-- 캐스팅 시간 텍스트
		local time = castbar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
		time:SetPoint('RIGHT', castbar, 'RIGHT', -5, 0)
		time:SetJustifyH('RIGHT')
		castbar.Time = time

		castbar:SetPoint('LEFT', icon, 'RIGHT', 6, 0)

		-- oUF UpdatePips 안전한 오버라이드 (비밀값 및 nil stages 에러 우회)
		castbar.Pips = castbar.Pips or {}
		castbar.UpdatePips = function(element, stages)
			if not stages then return end

			local isHoriz = element:GetOrientation() == 'HORIZONTAL'
			local elementSize = isHoriz and element:GetWidth() or element:GetHeight()

			if issecretvalue and issecretvalue(elementSize) then
				elementSize = isHoriz and (uWidth - 22) or 16
			end

			local lastOffset = 0
			for stage, stageSection in ipairs(stages) do
				local offset = lastOffset + (elementSize * stageSection)
				lastOffset = offset

				local pip = element.Pips[stage]
				if not pip then
					pip = CreateFrame('Frame', nil, element, 'CastingBarFrameStagePipTemplate')
					element.Pips[stage] = pip
				end

				pip:ClearAllPoints()
				pip:Show()

				if isHoriz then
					if pip.RotateTextures then
						pip:RotateTextures(0)
					end

					if element:GetReverseFill() then
						pip:SetPoint('TOP', element, 'TOPRIGHT', -offset, 0)
						pip:SetPoint('BOTTOM', element, 'BOTTOMRIGHT', -offset, 0)
					else
						pip:SetPoint('TOP', element, 'TOPLEFT', offset, 0)
						pip:SetPoint('BOTTOM', element, 'BOTTOMLEFT', offset, 0)
					end
				else
					if pip.RotateTextures then
						pip:RotateTextures(1.5708)
					end

					if element:GetReverseFill() then
						pip:SetPoint('LEFT', element, 'TOPLEFT', 0, -offset)
						pip:SetPoint('RIGHT', element, 'TOPRIGHT', 0, -offset)
					else
						pip:SetPoint('LEFT', element, 'BOTTOMLEFT', 0, offset)
						pip:SetPoint('RIGHT', element, 'BOTTOMRIGHT', 0, offset)
					end
				end
			end
		end

		-- 차단 속성 훅
		castbar.PostCastStart = function(element, unit)
			local isNotInterruptible = element.notInterruptible
			if issecretvalue and issecretvalue(isNotInterruptible) then
				isNotInterruptible = true
			end
			if isNotInterruptible then
				element:SetStatusBarColor(0.6, 0.6, 0.6)
			else
				element:SetStatusBarColor(1, 0.7, 0)
			end
		end

		castbar.PostChannelStart = function(element, unit)
			local isNotInterruptible = element.notInterruptible
			if issecretvalue and issecretvalue(isNotInterruptible) then
				isNotInterruptible = true
			end
			if isNotInterruptible then
				element:SetStatusBarColor(0.6, 0.6, 0.6)
			else
				element:SetStatusBarColor(1, 0.7, 0)
			end
		end

		castbar.PostCastNotInterruptible = function(element, unit)
			element:SetStatusBarColor(0.6, 0.6, 0.6)
		end

		castbar.PostCastInterruptible = function(element, unit)
			element:SetStatusBarColor(1, 0.7, 0)
		end

		castbar.PostCastFailed = function(element, unit)
			if element.Text then element.Text:SetText("실패") end
		end

		castbar.PostCastInterrupted = function(element, unit)
			if element.Text then element.Text:SetText("차단됨") end
		end

		self.Castbar = castbar
	end
end
