--!strict
--- ============================================================
--- CombatSystem.lua  (Server System — pure / stateless)
--- Resolves individual attack calculations for both player classes
--- (Fighter and Ranged) and NPC mobs.
---
--- Rules implemented:
---  Fighter:
---   • Light attack  → needs 7+ vs Fighter, 4+ vs Ranged.
---   • Heavy attack  → needs 12+ (−2 per prior consecutive hit; resets on miss).
---   • Crit (20)     → +CRITICAL_BONUS damage.
---   • Heavy crit    → also sets target.isVulnerable = true.
---   • Vulnerable target → VULNERABLE_MULTIPLIER on heavy damage.
---
---  Ranged (Bow / Magic Staff):
---   • All abilities → same hit roll and base damage.
---   • Crit (20)     → +CRITICAL_BONUS damage.
---
---  NPC:
---   • Simple roll vs NPC.HIT_ROLL threshold.
---
--- Usage:
---   local result = CombatSystem.resolveAttack(attacker, target, attackType)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)
local DiceSystem        = require(script.Parent.DiceSystem)

-- Forward declarations for the local unit type used internally.
-- A "unit" is any table with CombatStats and ClassType (or MobType).
type Unit = {
    classType       : Types.ClassType?,
    mobType         : Types.MobType?,
    stats           : Types.CombatStats,
}

local CombatSystem = {}

-- ──────────────────────────────────────────────
-- Private helpers
-- ──────────────────────────────────────────────

--- Determine the required hit-roll threshold for a Fighter attack.
---@param attackType    Types.AttackType
---@param target        Unit
---@return number  Required minimum D20 roll.
local function getFighterHitThreshold(attackType: Types.AttackType, target: Unit): number
    if attackType == "HeavyAttack" then
        -- Heavy attack threshold decreases with consecutive hits, resets on miss.
        local reduction = target.stats.heavyHitCount * Config.HIT.HEAVY_HIT_REDUCTION
        return math.max(1, Config.HIT.HEAVY_BASE - reduction)
    else
        -- Light attack: threshold depends on target class.
        if target.classType == "Ranged" then
            return Config.HIT.FIGHTER_VS_RANGED
        else
            -- vs Fighter or any NPC (treated as Fighter tier).
            return Config.HIT.FIGHTER_VS_FIGHTER
        end
    end
end

--- Apply damage to a target unit, clamping HP to zero.
---@param target    Unit
---@param damage    number
local function applyDamage(target: Unit, damage: number): ()
    target.stats.currentHp = math.max(0, target.stats.currentHp - damage)
end

-- ──────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────

--- Resolve a single attack from `attacker` against `target`.
--- Mutates `target.stats` (HP, vulnerability, heavyHitCount on the ATTACKER).
---
---@param attacker      Unit            The attacking unit.
---@param target        Unit            The defending unit.
---@param attackType    Types.AttackType  The chosen attack action.
---@return Types.AttackResult           Full result record.
function CombatSystem.resolveAttack(
    attacker    : Unit,
    target      : Unit,
    attackType  : Types.AttackType
): Types.AttackResult

    local dc = Config.DAMAGE
    local needed: number
    local baseDamage: number

    -- ── Determine hit threshold & base damage ──
    if attacker.classType == "Fighter" then
        needed     = getFighterHitThreshold(attackType, target)
        baseDamage = dc.BASE * (attackType == "HeavyAttack" and dc.HEAVY_MULTIPLIER or dc.LIGHT_MULTIPLIER)
    else
        -- Ranged / Magic: uniform threshold and damage.
        needed     = Config.HIT.RANGED_BASE
        baseDamage = dc.BASE
    end

    local roll, combatResult = DiceSystem.rollAndEvaluate(needed)
    local finalDamage        = 0

    if combatResult == "Hit" or combatResult == "CriticalHit" then
        finalDamage = baseDamage

        -- Critical hit bonus.
        if combatResult == "CriticalHit" then
            finalDamage = finalDamage * (1 + dc.CRITICAL_BONUS)
        end

        -- Heavy attack + vulnerable target bonus.
        if attackType == "HeavyAttack" and target.stats.isVulnerable then
            finalDamage = finalDamage * dc.VULNERABLE_MULTIPLIER
        end

        finalDamage = math.floor(finalDamage)
        applyDamage(target, finalDamage)

        -- Heavy attack bookkeeping on attacker side.
        if attackType == "HeavyAttack" then
            attacker.stats.heavyHitCount += 1

            -- Critical heavy attack → target becomes Vulnerable.
            if combatResult == "CriticalHit" then
                target.stats.isVulnerable = true
            end
        end

    else
        -- Miss or CriticalMiss: reset heavy hit streak on attacker.
        if attackType == "HeavyAttack" then
            attacker.stats.heavyHitCount = 0
        end
    end

    return {
        roll        = roll,
        result      = combatResult,
        damage      = finalDamage,
        attackType  = attackType,
    }
end

--- Resolve a simple NPC attack using the mob's hit roll threshold.
---
---@param mobStats      Types.CombatStats   The mob's combat stats.
---@param npcHitRoll    number              Minimum D20 roll for the mob to hit.
---@param target        Unit                The player being attacked.
---@return Types.AttackResult
function CombatSystem.resolveNpcAttack(
    mobStats    : Types.CombatStats,
    npcHitRoll  : number,
    target      : Unit
): Types.AttackResult

    local roll, combatResult = DiceSystem.rollAndEvaluate(npcHitRoll)
    local damage = 0

    if combatResult == "Hit" or combatResult == "CriticalHit" then
        damage = mobStats.baseAttack
        if combatResult == "CriticalHit" then
            damage = math.floor(damage * (1 + Config.DAMAGE.CRITICAL_BONUS))
        end
        applyDamage(target, damage)
    end

    return {
        roll       = roll,
        result     = combatResult,
        damage     = damage,
        attackType = "LightAttack", -- NPCs always use a generic "light" attack.
    }
end

return CombatSystem
