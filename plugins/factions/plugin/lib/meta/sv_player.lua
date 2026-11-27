--- Server-side player extensions of the Factions plugin: changing the rank of a player and
-- giving or taking whitelists.

local isnumber = isnumber
local istable = istable
local player_meta = FindMetaTable('Player')

--- Sets the player's rank in their faction and refreshes their membership at once (see
-- `Factions.refresh_membership`), which runs the PlayerRankChanged hook. The membership is
-- resolved at the moment of the call (see `Factions.resolve_membership`), so an item that
-- has left the player is never written to, and the rank is written where that membership
-- comes from: into the data of the item that grants the faction, so that whoever holds the
-- item holds the rank, or into the record of the character for the default faction of its
-- species. A bot, which has no items, has the rank written into the membership kept for it.
-- The rank of any other player cannot be set while their membership is provisional, before
-- the items of their character have been loaded, since it is not known yet where the
-- membership comes from. Server only.
-- @param rank [Number rank index, 1 being the lowest]
-- @return [Boolean true when the rank has been set; false when the player is in no faction,
--   the faction has no such rank or the items of the player have not been loaded yet]
function player_meta:set_rank(rank)
  if !isnumber(rank) or (!self:IsBot() and !Factions.has_items_loaded(self)) then return false end

  local faction_table, _, item_obj = Factions.resolve_membership(self)

  if !faction_table or !faction_table:get_rank(rank) then return false end

  if self:IsBot() then
    Factions.set_provisional_membership(self:get_character(), faction_table, rank)
  elseif item_obj then
    item_obj:set_data('rank', rank)
  else
    Factions.set_record(self:get_character(), faction_table.faction_id, 'rank', rank)
  end

  Factions.refresh_membership(self)

  return true
end

--- Moves the player one rank up unless they already hold the highest rank, on the membership
-- resolved at the moment of the call (see `Player:set_rank`). Server only.
-- @return [Boolean true when the player was promoted]
function player_meta:promote_rank()
  local faction_table, rank = Factions.resolve_membership(self)

  if faction_table and isnumber(rank) and faction_table:get_rank(rank + 1) then
    return self:set_rank(rank + 1)
  end

  return false
end

--- Moves the player one rank down unless they already hold the lowest rank, on the
-- membership resolved at the moment of the call (see `Player:set_rank`). Server only.
-- @return [Boolean true when the player was demoted]
function player_meta:demote_rank()
  local faction_table, rank = Factions.resolve_membership(self)

  if faction_table and isnumber(rank) and rank > 1 and faction_table:get_rank(rank - 1) then
    return self:set_rank(rank - 1)
  end

  return false
end

--- Whitelists the player for a faction, which lets them create characters that start as
-- members of it: adds a Whitelist record to their user record, saves it at once when the user
-- record is in the database already, and networks the updated list to the player. Does
-- nothing if they already have it or have no user record, as is the case for bots. Server
-- only.
-- @param faction_id [String]
-- @return [Boolean true when the player has been given the whitelist]
function player_meta:give_whitelist(faction_id)
  if !istable(self.record) or !istable(self.record.whitelists) or self:has_whitelist(faction_id) then
    return false
  end

  local whitelist = Whitelist.new()
    whitelist.faction_id = faction_id
  table.insert(self.record.whitelists, whitelist)

  if self.record.id then
    whitelist.user_id = self.record.id
    whitelist:save()
  end

  local whitelist_table = self:get_nv('whitelists', {})
    table.insert(whitelist_table, faction_id)
  self:set_private_nv('whitelists', whitelist_table)

  return true
end

--- Removes the player's whitelist for a faction, destroying its Whitelist record and
-- networking the updated list to the player. The characters they have already created are
-- not affected. Server only.
-- @param faction_id [String]
-- @return [Boolean true when the player had the whitelist and has lost it]
function player_meta:take_whitelist(faction_id)
  if !self:has_whitelist(faction_id) then return false end

  for index, whitelist in pairs(self.record.whitelists) do
    if whitelist.faction_id == faction_id then
      whitelist:destroy()
      table.remove(self.record.whitelists, index)

      break
    end
  end

  local whitelist_table = self:get_nv('whitelists', {})
    table.RemoveByValue(whitelist_table, faction_id)
  self:set_private_nv('whitelists', whitelist_table)

  return true
end
