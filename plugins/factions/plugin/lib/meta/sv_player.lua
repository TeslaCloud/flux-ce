--- Server-side player extensions of the Factions plugin: moving a player into another faction,
-- changing their rank and giving or taking whitelists.

local isnumber = isnumber
local istable = istable
local player_meta = FindMetaTable('Player')

--- Moves the player into a faction: resets the rank to the default rank of the faction,
-- sets the team, adjusts gender, regenerates the name from the base name of the character
-- (see `Factions.apply_name`), adjusts the model, gives the default description of a faction
-- that does not let players write one, sends the character list to the player once and runs
-- both factions' leave and join callbacks. A player who comes from a faction without names
-- of its own (has_name false) into one with them gets a name from `Characters.random_name`
-- as their base name when one is offered, so they do not keep the name the old faction
-- generated. The player then gets the weapons, the maximum health and armor and the rank
-- model of the new faction, and NPCs feel about them as that faction says. The rank is set
-- here rather than with `Player:set_rank`, so only the PlayerFactionChanged hook reports the
-- move. Neither the limit of the faction nor its can_transfer callback is checked; see
-- `Factions.can_transfer`. Server only.
-- @param id [String ID of a registered faction; any other value raises an error]
function player_meta:set_faction(id)
  local old_faction = self:get_faction()
  local faction_table = Factions.find_by_id(id)

  if !faction_table then
    error('set_faction: unknown faction \''..tostring(id)..'\'', 2)
  end

  local char = self:get_character()
  local default_rank = faction_table:get_default_rank()

  self:set_nv('faction', id)
  self:set_nv('rank', default_rank)

  if char then
    char.faction = id
    char.rank = default_rank
  end

  self:SetTeam(faction_table.team_id)

  if !faction_table.has_gender then
    Characters.set_gender(self, CHAR_GENDER_NONE, true)
  elseif !old_faction or !old_faction.has_gender then
    Characters.set_gender(self, math.random(CHAR_GENDER_MALE, CHAR_GENDER_FEMALE), true)
  end

  local base_name

  if old_faction and !old_faction.has_name and faction_table.has_name then
    base_name = Characters.random_name(self, id, self:get_nv('gender', CHAR_GENDER_NONE))
  end

  Factions.apply_name(self, faction_table, default_rank, base_name, true)

  Characters.set_model(self, faction_table:get_random_model(self), true)

  if !faction_table.has_description then
    Characters.set_desc(self, Factions.get_default_description(faction_table, self), true)
  end

  Characters.send_to_client(self)

  if old_faction then
    old_faction:on_player_leave(self)
  end

  faction_table:on_player_join(self)

  Factions.apply_membership(self)
  Factions.apply_npc_relations(self)
  Factions.send_character_counts(self)

  --- Called on the server after `Player:set_faction` has moved a player into a faction:
  -- their name, rank, team, gender and model have been updated, the on_player_leave
  -- and on_player_join callbacks of the factions have run, and the player has been given
  -- the weapons, maximum health and armor and rank model of the new faction.
  -- @param target [Player]
  -- @param faction_table [Faction the faction the player is in now]
  -- @param old_faction [Faction the faction the player was in before, nil if that was not
  --   a registered faction]
  hook.Run('PlayerFactionChanged', self, faction_table, old_faction)
end

--- Sets the player's rank in their current faction, networks it, regenerates their name
-- from the faction's name template and the base name of the character (see
-- `Factions.apply_name`) and gives them the model, the weapons and the maximum health and
-- armor of the rank. The limit of the rank is not checked, and nothing happens to a player
-- who is not a member of a registered faction. Server only.
-- @param rank [Number rank index, 1 being the lowest; ignored if the faction has no such rank]
function player_meta:set_rank(rank)
  local faction_table = Factions.get_membership(self)

  if !faction_table or !rank or !faction_table:get_rank(rank) then return end

  local old_rank = self:get_rank()

  self:get_character().rank = rank
  self:set_nv('rank', rank)

  Factions.apply_name(self, faction_table, rank)

  Factions.apply_membership(self)

  --- Called on the server after `Player:set_rank` has changed the rank of a player,
  -- networked it, regenerated their name and given them the model, the weapons and the
  -- maximum health and armor of the rank.
  -- @param target [Player]
  -- @param rank [Number the new rank index]
  -- @param old_rank [Number the rank index before the change]
  hook.Run('PlayerRankChanged', self, rank, old_rank)
end

--- Moves the player one rank up unless they already hold the highest rank. Server only.
-- @return [Boolean true when the player was promoted]
function player_meta:promote_rank()
  local faction_table, rank = Factions.get_membership(self)

  if faction_table and isnumber(rank) and faction_table:get_rank(rank + 1) then
    self:set_rank(rank + 1)

    return true
  end

  return false
end

--- Moves the player one rank down unless they already hold the lowest rank. Server only.
-- @return [Boolean true when the player was demoted]
function player_meta:demote_rank()
  local faction_table, rank = Factions.get_membership(self)

  if faction_table and isnumber(rank) and rank > 1 and faction_table:get_rank(rank - 1) then
    self:set_rank(rank - 1)

    return true
  end

  return false
end

--- Whitelists the player for a faction: adds a Whitelist record to their user record, saves
-- it at once when the user record is in the database already, and networks the updated list
-- to the player. Does nothing if they already have it or have no user record, as is the case
-- for bots. Server only.
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
-- networking the updated list to the player. A player who is playing a character of that
-- faction and may not load it without the whitelist (see `Factions:PlayerCanUseCharacter`)
-- loses it at once: it is saved and dropped, the player is spawned again and gets the main
-- menu with the reason. Server only.
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

  local character = self.current_character

  if character and character.faction == faction_id then
    local allowed, reason, arguments = Factions:PlayerCanUseCharacter(self, character)

    if allowed == false then
      self:clear_active_character()
      self:Spawn()

      Characters.open_menu(self, reason, arguments)
    end
  end

  return true
end
