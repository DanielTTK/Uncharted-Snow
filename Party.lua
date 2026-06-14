--!strict
--- ============================================================
--- Party.lua  (Shared Class)
--- Represents a party of players within a faction.
--- The leader is always index 1. Members are ordered by join time.
---
--- Key rules:
---  • Leader can accept/reject join requests.
---  • Leader sets loot sharing mode (ShareLoot | KeepLoot).
---  • Leader receives 25% bonus on top of group loot share.
---  • Turn order in combat follows party index (1 → last).
---
--- Usage:
---   local party = Party.new(leaderCharacter, partyId)
---   party:addMember(followerCharacter)
---   local order = party:getCombatOrder()
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)

-- Forward-declare the PlayerCharacter type without a circular require.
-- CombatService will import both and pass real instances.
type PlayerCharacterLike = {
    userId          : number,
    partyPosition   : number?,
    isAlive         : boolean,
}

export type LootShareMode = "ShareLoot" | "KeepLoot"

-- ──────────────────────────────────────────────
-- Class definition
-- ──────────────────────────────────────────────

--- @class Party
local Party   = {}
Party.__index = Party

-- ──────────────────────────────────────────────
-- Constructor
-- ──────────────────────────────────────────────

--- Create a new Party with the given player as leader (position 1).
---
---@param leader    PlayerCharacterLike   The founding leader.
---@param partyId   string                Unique party identifier.
---@return Party
function Party.new(
    leader  : PlayerCharacterLike,
    partyId : string
): typeof(setmetatable({} :: any, Party))

    local self = setmetatable({}, Party)

    --- Unique party ID (e.g. "Party_abc123").
    self.partyId    = partyId

    --- Ordered list of members; index 1 is always the leader.
    self.members: { PlayerCharacterLike } = { leader }
    leader.partyPosition = 1

    --- Whether loot is shared among members or kept by the leader.
    self.lootShareMode: LootShareMode = "ShareLoot"

    return self
end

-- ──────────────────────────────────────────────
-- Member management
-- ──────────────────────────────────────────────

--- Add a new member to the party (appended to the queue).
--- Enforces the maximum party size from config.
---
---@param member    PlayerCharacterLike
---@return boolean  True if added, false if party is full.
function Party:addMember(member: PlayerCharacterLike): boolean
    if #self.members >= Config.FACTION.MAX_PARTY_SIZE then
        warn("[Party] Party", self.partyId, "is full (max:", Config.FACTION.MAX_PARTY_SIZE, ")")
        return false
    end
    table.insert(self.members, member)
    member.partyPosition = #self.members
    return true
end

--- Remove a member by userId (e.g. on death or disconnect).
---@param userId    number
function Party:removeMember(userId: number): ()
    for i, member in ipairs(self.members) do
        if member.userId == userId then
            table.remove(self.members, i)
            break
        end
    end
    -- Re-index party positions.
    for i, member in ipairs(self.members) do
        member.partyPosition = i
    end
end

--- Returns the current leader (index 1).
---@return PlayerCharacterLike
function Party:getLeader(): PlayerCharacterLike
    return self.members[1]
end

--- Returns the number of living members.
---@return number
function Party:livingCount(): number
    local count = 0
    for _, m in ipairs(self.members) do
        if m.isAlive then
            count += 1
        end
    end
    return count
end

--- Returns members in combat turn order (living only, leader first).
---@return { PlayerCharacterLike }
function Party:getCombatOrder(): { PlayerCharacterLike }
    local order: { PlayerCharacterLike } = {}
    for _, m in ipairs(self.members) do
        if m.isAlive then
            table.insert(order, m)
        end
    end
    return order
end

-- ──────────────────────────────────────────────
-- Loot settings
-- ──────────────────────────────────────────────

--- Set how loot is distributed. Only the leader should call this.
---@param mode LootShareMode
function Party:setLootShareMode(mode: LootShareMode): ()
    self.lootShareMode = mode
end

return Party
