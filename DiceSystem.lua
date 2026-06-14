--!strict
--- ============================================================
--- DiceSystem.lua  (Server System — pure / stateless)
--- Provides D20 dice-rolling utilities used by CombatService
--- and FleeSystem. No state is held; every function is pure.
---
--- Usage:
---   local Dice = require(ServerScriptService.Systems.DiceSystem)
---   local roll = Dice.roll()          -- 1–20
---   local res  = Dice.evaluate(roll, 7)  -- "Hit" | "Miss" | ...
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)

local DiceSystem = {}

--- Roll the D20 and return the raw integer result (1–20).
---@return number  Raw roll value.
function DiceSystem.roll(): number
    return math.random(1, Config.DICE.SIDES)
end

--- Evaluate a raw roll against a required threshold.
---
---@param roll      number  The raw D20 roll.
---@param needed    number  Minimum roll required for a standard hit.
---@return Types.CombatResult
function DiceSystem.evaluate(roll: number, needed: number): Types.CombatResult
    if roll == Config.DICE.CRITICAL_HIT_VALUE then
        return "CriticalHit"
    elseif roll == Config.DICE.CRITICAL_MISS_VALUE then
        return "CriticalMiss"
    elseif roll >= needed then
        return "Hit"
    else
        return "Miss"
    end
end

--- Convenience: roll and immediately evaluate.
---
---@param needed    number  Minimum roll for a hit.
---@return number, Types.CombatResult  (rawRoll, result)
function DiceSystem.rollAndEvaluate(needed: number): (number, Types.CombatResult)
    local roll   = DiceSystem.roll()
    local result = DiceSystem.evaluate(roll, needed)
    return roll, result
end

return DiceSystem
