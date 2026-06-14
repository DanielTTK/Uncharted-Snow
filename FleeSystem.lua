--!strict
--- ============================================================
--- FleeSystem.lua  (Server System — pure / stateless)
--- Calculates flee success for a unit attempting to escape combat.
---
--- Rules:
---  • Base roll needed = Config.FLEE.BASE_ROLL_NEEDED (12).
---  • Each position behind the leader gives +POSITION_BONUS_PERCENT
---    effective flee chance (reduces the roll needed).
---  • Each enemy beyond the fleeing party's size gives
---    +ENEMY_SURPLUS_BONUS_PERCENT flee chance.
---  • Roll a D20; if roll >= effectiveNeeded → success.
---
--- Usage:
---   local result = FleeSystem.attempt(partyPosition, partySize, enemySize)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)
local DiceSystem        = require(script.Parent.DiceSystem)

local FleeSystem = {}

--- Attempt to flee from combat.
---
---@param partyPosition number  1-indexed position in the party queue (1 = leader).
---@param partySize     number  Total members in the fleeing party.
---@param enemySize     number  Total enemies in the opposing group.
---@return Types.FleeAttempt   Full result record including roll details.
function FleeSystem.attempt(
    partyPosition : number,
    partySize     : number,
    enemySize     : number
): Types.FleeAttempt

    local fc = Config.FLEE

    -- Positions behind the leader (leader = 0 bonus positions).
    local positionsBack  = partyPosition - 1
    local positionBonus  = positionsBack * fc.POSITION_BONUS_PERCENT

    -- Extra enemies beyond our party size.
    local enemySurplus   = math.max(0, enemySize - partySize)
    local sizeBonus      = enemySurplus * fc.ENEMY_SURPLUS_BONUS_PERCENT

    -- Total bonus reduces the required roll (clamped to minimum 1).
    local totalBonusPct  = positionBonus + sizeBonus
    -- Convert percentage bonus to a roll reduction on a 20-sided die.
    -- 100% bonus → need only a 1 (guaranteed). Scale linearly.
    local rollReduction  = math.floor((totalBonusPct / 100) * (Config.DICE.SIDES - 1))
    local effectiveNeeded = math.max(1, fc.BASE_ROLL_NEEDED - rollReduction)

    local roll, combatResult = DiceSystem.rollAndEvaluate(effectiveNeeded)

    local fleeResult: Types.FleeResult =
        (combatResult == "Hit" or combatResult == "CriticalHit") and "Success" or "Failure"

    return {
        roll            = roll,
        result          = fleeResult,
        partyPosition   = partyPosition,
        enemySurplus    = enemySurplus,
        effectiveNeeded = effectiveNeeded,
    }
end

return FleeSystem
