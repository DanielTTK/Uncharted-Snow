--!strict
--- ============================================================
--- PlayerCharacter.lua  (Shared Class)
--- Represents a player's in-match character state.
--- Holds class, weapon, stats, inventory, and party position.
---
--- Usage:
---   local PlayerCharacter = require(...)
---   local pc = PlayerCharacter.new(userId, "Fighter", "Sword")
---   pc:takeDamage(15)
--- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config            = require(ReplicatedStorage.Shared.Constants.GameConfig)
local Types             = require(ReplicatedStorage.Shared.Types.Types)

-- ──────────────────────────────────────────────
-- Class definition
-- ──────────────────────────────────────────────

--- @class PlayerCharacter
local PlayerCharacter   = {}
PlayerCharacter.__index = PlayerCharacter

-- ──────────────────────────────────────────────
-- Constructor
-- ──────────────────────────────────────────────

--- Create a new PlayerCharacter instance.
---
---@param userId        number              Roblox UserId.
---@param classType     Types.ClassType     "Fighter" or "Ranged".
---@param weaponType    Types.WeaponType    Starting weapon.
---@return PlayerCharacter
function PlayerCharacter.new(
    userId      : number,
    classType   : Types.ClassType,
    weaponType  : Types.WeaponType
): typeof(setmetatable({} :: any, PlayerCharacter))

    local self = setmetatable({}, PlayerCharacter)

    --- Roblox UserId.
    self.userId         = userId

    --- Class (Fighter / Ranged).
    self.classType      = classType

    --- Currently equipped weapon.
    self.weaponType     = weaponType

    --- Live combat statistics.
    self.stats: Types.CombatStats = {
        maxHp           = Config.PLAYER_STATS.BASE_HP,
        currentHp       = Config.PLAYER_STATS.BASE_HP,
        baseAttack      = Config.DAMAGE.BASE,
        heavyHitCount   = 0,
        isVulnerable    = false,
    }

    --- Items held in the session (lost on death, kept on extraction).
    self.sessionInventory: { Types.ItemData } = {}

    --- Party position (1 = leader, nil = not in a party).
    self.partyPosition: number? = nil

    --- Whether this player is alive in the current match.
    self.isAlive = true

    return self
end

-- ──────────────────────────────────────────────
-- HP methods
-- ──────────────────────────────────────────────

--- Apply damage to this character, clamping HP to 0.
---@param amount number  Damage to deal.
function PlayerCharacter:takeDamage(amount: number): ()
    self.stats.currentHp = math.max(0, self.stats.currentHp - amount)
    if self.stats.currentHp <= 0 then
        self.isAlive = false
    end
end

--- Heal this character, clamping to maxHp.
---@param amount number  HP to restore.
function PlayerCharacter:heal(amount: number): ()
    self.stats.currentHp = math.min(self.stats.maxHp, self.stats.currentHp + amount)
end

--- Returns true if the character has more than 0 HP.
---@return boolean
function PlayerCharacter:isLiving(): boolean
    return self.stats.currentHp > 0
end

-- ──────────────────────────────────────────────
-- Inventory methods
-- ──────────────────────────────────────────────

--- Add an item to the session inventory.
---@param item Types.ItemData
function PlayerCharacter:addItem(item: Types.ItemData): ()
    table.insert(self.sessionInventory, item)
end

--- Remove and return all session items (used at extraction).
---@return { Types.ItemData }
function PlayerCharacter:drainInventory(): { Types.ItemData }
    local drained = self.sessionInventory
    self.sessionInventory = {}
    return drained
end

-- ──────────────────────────────────────────────
-- Status helpers
-- ──────────────────────────────────────────────

--- Clear the Vulnerable status (e.g. start of player's new turn).
function PlayerCharacter:clearVulnerable(): ()
    self.stats.isVulnerable = false
end

--- Reset the consecutive heavy-hit counter (called on any missed attack).
function PlayerCharacter:resetHeavyHitCount(): ()
    self.stats.heavyHitCount = 0
end

return PlayerCharacter
