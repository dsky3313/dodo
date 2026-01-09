------------------------------
-- 테이블
------------------------------


-- 행동 단축바
SetCVar("enableMultiActionBars", 0) -- 행동 단축바 1
SetCVar("enableMultiActionBars", 1) -- 행동 단축바 2
SetCVar("enableMultiActionBars", 2) -- 행동 단축바 3
SetCVar("enableMultiActionBars", 4) -- 행동 단축바 4
SetCVar("enableMultiActionBars", 8) -- 행동 단축바 5
SetCVar("enableMultiActionBars", 16) -- 행동 단축바 6
SetCVar("enableMultiActionBars", 32) -- 행동 단축바 7
SetCVar("enableMultiActionBars", 64) -- 행동 단축바 8
SetCVar("enableMultiActionBars", 127) -- 행동 단축바 all
SetCVar("lockActionBars", 1) -- 행동 단축바 잠그기 0 풀림 / 1 잠금
SetCVar("countdownForCooldowns", 1) -- 재사용 대기시간 숫자 보기

/console ShowClassColorInFriendlyNameplate 1
/console ShowClassColorInNameplate 1
/run SetCVar("NameplatePersonalShowAlways", 1)
/console floatingCombatTextCombatDamage 1
/console WorldTextScale 0.6
/console floatingCombatTextCombatDamageDirectionalScale 1
/console alwaysCompareItems 1
/console worldPreloadNonCritical 0
/console AutoPushSpellToActionBar 0
