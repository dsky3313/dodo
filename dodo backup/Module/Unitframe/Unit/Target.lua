-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 대상 스타일 주입
-- ==============================
dodo.UnitframeStyles['target'] = function(self, unit)
	self.uWidth = 190
	self.uHeight = 30
end
