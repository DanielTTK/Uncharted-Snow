--!strict
--- ============================================================
--- FactionService.lua  (Server Service — singleton)
--- Assigns factions to players at matchmaking and manages
--- party formation within each faction.
---
--- Faction = a team colour/group for the entire match.
--- Party   = a sub-group within a faction (leader + followers).
---           Multiple parties can exist within one faction.
---
--- Usage:
---   FactionService.init()
---   FactionService.assignFaction(userId)
---   FactionService.requestJoinParty(followerId, leaderId)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)
local Party             = require(ReplicatedStorage.Shared.Classes.Party)

-- Internal player-character type (minimal interface needed here).
type PlayerCharacterLike = {
    userId          : number,
    partyPosition   : number?,
    isAlive         : boolean,
}

-- ──────────────────────────────────────────────
-- State (per-match; reset via init())
-- ──────────────────────────────────────────────

--- Map: factionId → list of userIds in that faction.
local factionMembers: { [string]: { number } } = {}

--- Map: userId → factionId.
local playerFaction: { [number]: string } = {}

--- Map: partyId → Party instance.
local parties: { [string]: typeof(Party.new({} :: any, "")) } = {}

--- Map: userId → partyId (if in a party).
local playerParty: { [number]: string } = {}

--- Monotonic counter for generating unique party IDs.
local partyCounter = 0

-- ──────────────────────────────────────────────
-- Private helpers
-- ──────────────────────────────────────────────

--- Generate a unique party ID string.
---@return string
local function newPartyId(): string
    partyCounter += 1
    return "Party_" .. tostring(partyCounter)
end

--- Find the faction with the fewest members (simple round-robin balancing).
---@return string factionId
local function leastPopulatedFaction(): string
    local best: string? = nil
    local bestCount     = math.huge
    for fId, members in pairs(factionMembers) do
        if #members < bestCount then
            bestCount = #members
            best      = fId
        end
    end
    return best :: string
end

-- ──────────────────────────────────────────────
-- Service singleton table
-- ──────────────────────────────────────────────

--- @class FactionService
local FactionService = {}

-- ──────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────

--- Bootstrap the service and set up faction slots for a new match.
--- Must be called before any player joins.
function FactionService.init(): ()
    factionMembers  = {}
    playerFaction   = {}
    parties         = {}
    playerParty     = {}
    partyCounter    = 0

    -- Pre-create faction buckets.
    for i = 1, Config.FACTION.MAX_FACTIONS do
        local fId = "Faction_" .. tostring(i)
        factionMembers[fId] = {}
    end

    print("[FactionService] Initialised with", Config.FACTION.MAX_FACTIONS, "factions.")
end

--- Assign a player to the least-populated faction.
---@param userId number
---@return string  The faction ID assigned.
function FactionService.assignFaction(userId: number): string
    local fId = leastPopulatedFaction()
    table.insert(factionMembers[fId], userId)
    playerFaction[userId] = fId
    print(string.format("[FactionService] User %d → %s", userId, fId))
    return fId
end

--- Get the faction of a player.
---@param userId number
---@return string?
function FactionService.getFaction(userId: number): string?
    return playerFaction[userId]
end

--- Return true if two players are in the same faction.
---@param userIdA number
---@param userIdB number
---@return boolean
function FactionService.sameFaction(userIdA: number, userIdB: number): boolean
    return playerFaction[userIdA] == playerFaction[userIdB]
        and playerFaction[userIdA] ~= nil
end

--- Create a solo "party" for a player (they become their own leader).
--- Every player starts as a solo party at spawn.
---
---@param character PlayerCharacterLike
---@return string  The new partyId.
function FactionService.createSoloParty(character: PlayerCharacterLike): string
    local partyId   = newPartyId()
    local newParty  = Party.new(character, partyId)
    parties[partyId]                 = newParty
    playerParty[character.userId]    = partyId
    return partyId
end

--- A follower requests to join a leader's party.
--- The leader must confirm via confirmJoinRequest().
--- For now this auto-approves if they share a faction.
---
---@param follower  PlayerCharacterLike
---@param leader    PlayerCharacterLike
---@return boolean  True if the join was accepted.
function FactionService.requestJoinParty(
    follower    : PlayerCharacterLike,
    leader      : PlayerCharacterLike
): boolean

    if not FactionService.sameFaction(follower.userId, leader.userId) then
        warn(string.format(
            "[FactionService] User %d cannot join user %d — different factions.",
            follower.userId, leader.userId
        ))
        return false
    end

    local leaderPartyId = playerParty[leader.userId]
    if not leaderPartyId then
        warn("[FactionService] Leader", leader.userId, "has no party.")
        return false
    end

    local targetParty = parties[leaderPartyId]
    if not targetParty then
        warn("[FactionService] Party", leaderPartyId, "not found.")
        return false
    end

    local success = targetParty:addMember(follower)
    if success then
        -- Remove follower from their old solo party (clean up).
        local oldPartyId = playerParty[follower.userId]
        if oldPartyId and oldPartyId ~= leaderPartyId then
            parties[oldPartyId] = nil
        end
        playerParty[follower.userId] = leaderPartyId
        print(string.format(
            "[FactionService] User %d joined party '%s' (leader: %d).",
            follower.userId, leaderPartyId, leader.userId
        ))
    end

    return success
end

--- Get the Party object for a given player.
---@param userId number
---@return Party?
function FactionService.getParty(userId: number): typeof(Party.new({} :: any, ""))?
    local partyId = playerParty[userId]
    if not partyId then return nil end
    return parties[partyId]
end

return FactionService
