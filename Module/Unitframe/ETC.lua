-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 기타(ETC) 프레임 스타일 주입
-- ==============================
dodo.UnitframeStyles['targettarget'] = function(self, unit)
	self.uWidth = 100
	self.uHeight = 16
	self.showPower = false
	self.showHealthText = false
end

dodo.UnitframeStyles['pet'] = function(self, unit)
	self.uWidth = 100
	self.uHeight = 16
	self.showPower = false
	self.showHealthText = false
end

dodo.UnitframeStyles['focus'] = function(self, unit)
	self.uWidth = 120
	self.uHeight = 16
	self.showPower = false
	self.showHealthText = false
end

dodo.UnitframeStyles['etc'] = function(self, unit)
	self.uWidth = 120
	self.uHeight = 16
	self.showPower = false
	self.showHealthText = false
end
