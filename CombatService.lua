--!strict
--- ============================================================
--- CombatService.lua  (Server Service — singleton)
--- Orchestrates full turn-based combat encounters between:
---   • Player party vs Player party (PvP)
---   • Player party vs NPC mob group (PvE)
---
--- Turn order: leader → party members → NPCs (each round).
--- On a player's turn they may: Attack, UseItem, or Flee.
--- Loot is distributed at encounter end via LootService.
---
--- This service is a singleton. Boot via CombatService.init().
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config         = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types          = require(ReplicatedStorage.Shared.Types.Types)
local CombatSystem   = require(ServerScriptService.Systems.CombatSystem)
local FleeSystem     = require(ServerScriptService.Systems.FleeSystem)

-- Lazy-loaded to avoid circular deps at module load time.
local LootService: any = nil

-- ──────────────────────────────────────────────
-- Internal types
-- ──────────────────────────────────────────────

type PlayerCharacter = {
    userId          : number,
    classType       : Types.ClassType,
    weaponType      : Types.WeaponType,
    stats           : Types.CombatStats,
    partyPosition   : number?,
    isAlive         : boolean,
    takeDamage      : (self: any, amount: number) -> (),
}

type NpcMob = {
    mobType     : Types.MobType,
    displayName : string,
    hitRoll     : number,
    lootTier    : string,
    stats       : Types.CombatStats,
    isAlive     : boolean,
    takeDamage  : (self: any, amount: number) -> (),
}

type Party = {
    partyId         : string,
    members         : { PlayerCharacter },
    lootShareMode   : string,
    getCombatOrder  : (self: any) -> { PlayerCharacter },
    livingCount     : (self: any) -> number,
    getLeader       : (self: any) -> PlayerCharacter,
}

export type EncounterType = "PvP" | "PvE"

export type EncounterResult = {
    encounterType   : EncounterType,
    winnerPartyId   : string?,
    allFled         : boolean,
    rounds          : number,
    lootAwarded     : boolean,
}

-- ──────────────────────────────────────────────
-- Service singleton table
-- ──────────────────────────────────────────────

--- @class CombatService
local CombatService = {}

-- ──────────────────────────────────────────────
-- Private helpers
-- ──────────────────────────────────────────────

--- Collect all living NPCs from a group.
---@param mobs { NpcMob }
---@return { NpcMob }
local function livingMobs(mobs: { NpcMob }): { NpcMob }
    local alive: { NpcMob } = {}
    for _, mob in ipairs(mobs) do
        if mob.isAlive then
            table.insert(alive, mob)
        end
    end
    return alive
end

--- Pick a random living target from a list.
---@param targets { any }
---@return any?
local function pickRandomTarget(targets: { any }): any?
    if #targets == 0 then return nil end
    return targets[math.random(1, #targets)]
end

--- Execute a single player's attack turn (auto-selects a random enemy target
--- in this basic implementation; in production this would be driven by a
--- RemoteEvent awaiting the client's action choice).
---@param attacker  PlayerCharacter
---@param targets   { any }   List of enemy units (PlayerCharacter or NpcMob).
---@return string   Log line describing the outcome.
local function executePlayerAttack(attacker: PlayerCharacter, targets: { any }): string
    local target = pickRandomTarget(targets)
    if not target then return attacker.userId .. " has no targets." end

    -- Determine attack type from class.
    local attackType: Types.AttackType
    if attacker.classType == "Fighter" then
        -- Auto-choose light vs heavy (heavy if heavyHitCount > 0 for momentum).
        attackType = (attacker.stats.heavyHitCount > 0) and "HeavyAttack" or "LightAttack"
    else
        -- Ranged/Magic defaults to base attack.
        attackType = "Arrow"
    end

    local result = CombatSystem.resolveAttack(attacker, target, attackType)
    local targetName = (target :: any).displayName or tostring((target :: any).userId)

    return string.format(
        "User %d attacked %s with %s → roll %d → %s (dmg: %d)",
        attacker.userId, targetName, attackType,
        result.roll, result.result, result.damage
    )
end

--- Execute all NPC turns in a round.
---@param mobs      { NpcMob }
---@param party     Party
---@return { string }   Log lines.
local function executeNpcTurns(mobs: { NpcMob }, party: Party): { string }
    local logs: { string } = {}
    local partyOrder = party:getCombatOrder()

    for _, mob in ipairs(livingMobs(mobs)) do
        local target = pickRandomTarget(partyOrder)
        if not target then break end

        local result = CombatSystem.resolveNpcAttack(mob.stats, mob.hitRoll, target)
        table.insert(logs, string.format(
            "%s attacked user %d → roll %d → %s (dmg: %d)",
            mob.displayName, target.userId,
            result.roll, result.result, result.damage
        ))
    end

    return logs
end

-- ──────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────

--- Bootstrap the service. Call once from the server init script.
function CombatService.init(): ()
    -- Lazy-load LootService here to break any circular dependency.
    LootService = require(ServerScriptService.Services.LootService)
    print("[CombatService] Initialised.")
end

--- Run a full PvE encounter between a player party and a mob group.
--- Loops rounds until one side is eliminated or all players flee.
---
---@param party     Party           The player party.
---@param mobs      { NpcMob }      The NPC mob group.
---@return EncounterResult
function CombatService.runPvEEncounter(party: Party, mobs: { NpcMob }): EncounterResult
    local rounds        = 0
    local allFled       = false
    local MAX_ROUNDS    = 50 -- Safety cap to prevent infinite loops.

    print(string.format(
        "[CombatService] PvE encounter: party '%s' (%d members) vs %d mobs.",
        party.partyId, #party.members, #mobs
    ))

    while party:livingCount() > 0 and #livingMobs(mobs) > 0 and rounds < MAX_ROUNDS do
        rounds += 1
        print(string.format("[CombatService] Round %d ——", rounds))

        local partyOrder = party:getCombatOrder()
        local aliveMobs  = livingMobs(mobs)

        -- ── Player turns ──
        for _, player in ipairs(partyOrder) do
            if not player.isAlive then continue end
            if #livingMobs(mobs) == 0 then break end

            -- Simulate player choosing to attack (no Flee in this basic loop).
            local log = executePlayerAttack(player, aliveMobs)
            print("  " .. log)
        end

        -- ── NPC turns ──
        local npcLogs = executeNpcTurns(livingMobs(mobs), party)
        for _, log in ipairs(npcLogs) do
            print("  " .. log)
        end
    end

    local partyWon = party:livingCount() > 0 and #livingMobs(mobs) == 0

    if partyWon and LootService then
        LootService.awardMobLoot(party, mobs)
    end

    return {
        encounterType   = "PvE",
        winnerPartyId   = partyWon and party.partyId or nil,
        allFled         = allFled,
        rounds          = rounds,
        lootAwarded     = partyWon,
    }
end

--- Attempt a flee action for a specific party member during their turn.
---
---@param player        PlayerCharacter     The fleeing player.
---@param party         Party               Their party.
---@param enemyCount    number              How many enemies are in the opposing group.
---@return Types.FleeAttempt
function CombatService.attemptFlee(
    player      : PlayerCharacter,
    party       : Party,
    enemyCount  : number
): Types.FleeAttempt

    local position  = player.partyPosition or 1
    local partySize = party:livingCount()

    local result = FleeSystem.attempt(position, partySize, enemyCount)

    print(string.format(
        "[CombatService] User %d flee attempt: pos=%d, partySize=%d, enemies=%d → roll=%d, needed=%d → %s",
        player.userId, position, partySize, enemyCount,
        result.roll, result.effectiveNeeded, result.result
    ))

    return result
end

return CombatService
