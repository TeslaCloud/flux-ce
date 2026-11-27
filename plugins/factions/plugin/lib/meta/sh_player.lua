--- Player extensions of the Factions plugin: the faction, rank and whitelists of a player,
-- and whether they may promote and demote other members. The faction and the rank are those
-- of the membership resolved last (see `Factions.refresh_membership`), which the server
-- networks to everyone.

local istable = istable
local stored = Factions.stored
local player_meta = FindMetaTable('Player')

--- Returns the ID of the player's faction.
-- @return [String faction ID, nil when the player is in no faction]
function player_meta:get_faction_id()
  return self:get_nv('faction')
end

--- Returns the faction the player belongs to.
-- @return [Faction the faction, or nil if the player's faction ID is not registered]
function player_meta:get_faction()
  return stored[self:get_faction_id()]
end

--- Returns the player's rank in their faction as an index into the faction's rank list.
-- @return [Number rank index; -1 when the player is in no faction]
function player_meta:get_rank()
  return self:get_nv('rank', -1)
end

--- Returns the ID of the player's current rank. Errors if the player has no faction or rank.
-- @return [String rank ID]
function player_meta:get_rank_name()
  return self:get_faction():get_rank_name(self:get_rank())
end

--- Returns the table of the rank the player holds in their faction.
-- @return [Map rank table with id and name fields and the optional fields described at
--   `Faction:add_rank`; nil if the player is not a member of a faction or has no rank]
function player_meta:get_rank_table()
  local faction_table, rank = Factions.get_membership(self)

  return faction_table and rank != nil and faction_table:get_rank(rank) or nil
end

--- Checks whether the player holds the given rank of their faction or any rank above it.
-- @param str_rank [String rank ID, letter case is ignored]
-- @param strict=false [Boolean require exactly that rank, not one above it]
-- @return [Boolean false as well when the player has no rank or the rank does not exist]
function player_meta:is_rank(str_rank, strict)
  local faction_table = self:get_faction()
  local rank = self:get_rank()

  if rank != -1 and faction_table then
    local lowered = string.utf8lower(str_rank)

    for index, rank_table in ipairs(faction_table.rank) do
      if string.utf8lower(rank_table.id) == lowered then
        if strict then
          return index == rank
        end

        return index <= rank
      end
    end
  end

  return false
end

--- Checks whether the rank of the player lets them promote another player.
-- @param target [Player the player who would be promoted]
-- @return [Boolean]
-- @see [Factions.can_promote]
function player_meta:can_promote(target)
  return Factions.can_promote(self, target)
end

--- Checks whether the rank of the player lets them demote another player.
-- @param target [Player the player who would be demoted]
-- @return [Boolean]
-- @see [Factions.can_demote]
function player_meta:can_demote(target)
  return Factions.can_demote(self, target)
end

--- Returns the faction whitelists of the player. A whitelist for a faction lets the player
-- create characters that start as members of it.
-- @return [List Whitelist records on the server, empty for a player without a user record;
--   whitelisted faction IDs on the client, which knows those of the local player alone]
function player_meta:get_whitelists()
  if SERVER then
    return istable(self.record) and self.record.whitelists or {}
  end

  return self:get_nv('whitelists', {})
end

--- Checks whether the player is whitelisted for a faction, which lets them create characters
-- that start as members of it.
-- @param faction_id [String]
-- @return [Boolean]
function player_meta:has_whitelist(faction_id)
  local whitelists = self:get_whitelists()

  if CLIENT then
    return table.HasValue(whitelists, faction_id)
  end

  for _, whitelist in pairs(whitelists) do
    if whitelist.faction_id == faction_id then
      return true
    end
  end

  return false
end
