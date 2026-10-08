if !Factions then
  PLUGIN:set_global 'Factions'
end

local stored = Factions.stored or {}
local count = Factions.count or 0
Factions.stored = stored
Factions.count = count

--- Registers a faction: fills in the default name, description and color, sets up its team
-- and assigns the animation class of each of its models.
-- ```
-- local faction = Faction.new('citizen')
-- faction.name = 'Citizen'
-- faction.models.male = { 'models/humans/group01/male_02.mdl' }
-- faction.models.female = { 'models/humans/group01/female_01.mdl' }
--
-- -- Same as faction:register()
-- Factions.add_faction(faction.faction_id, faction)
-- ```
-- @param id [String faction ID, normalized with to_id]
-- @param data [Faction the faction to register; receives faction_id and team_id]
-- @see [Faction#register]
function Factions.add_faction(id, data)
  if !id or !data then return end

  data.faction_id = id:to_id() or (data.name and data.name:to_id())
  data.name = data.name or 'Unknown Faction'
  data.description = data.description or 'This faction has no description!'
  data.color = data.color or Color(255, 255, 255)

  team.SetUp(count + 1, data.name, data.color)

  data.team_id = count + 1

  stored[data.faction_id] = data
  count = count + 1

  for k, v in pairs(data.model_classes) do
    local gender_models = data:get_gender_models(k)

    if gender_models then
      for k1, v1 in pairs(gender_models) do
        Flux.Anim:set_model_class(v1, v)
      end
    end
  end
end

--- Returns the faction registered under the exact ID.
-- @param id [String faction ID]
-- @return [Faction the faction, or nil if it is not registered]
function Factions.find_by_id(id)
  return stored[id]
end

--- Returns every connected player whose faction is the given one.
-- @param id [String faction ID]
-- @return [List<Player>]
function Factions.get_players(id)
  local players = {}

  for k, v in player.Iterator() do
    if v:get_faction_id() == id then
      table.insert(players, v)
    end
  end

  return players
end

--- Finds a faction by its ID or name, ignoring letter case.
-- @param name [String faction ID or name, or a part of either]
-- @param strict=false [Boolean require the whole ID or name to match]
-- @return [Faction/Boolean the first matching faction, or false if nothing matched]
function Factions.find(name, strict)
  for k, v in pairs(stored) do
    if strict then
      if k:utf8lower() == name:utf8lower() or v.name:utf8lower() == name:utf8lower() then
        return v
      end
    else
      if k:utf8lower():find(name:utf8lower()) or v.name:utf8lower():find(name:utf8lower()) then
        return v
      end
    end
  end

  return false
end

--- Returns every registered faction.
-- @return [Map factions keyed by faction ID]
function Factions.all()
  return stored
end

--- Includes every file of a folder as a faction definition. Each file gets a fresh FACTION
-- global, a Faction named after the file, that is registered once the file has run.
-- ```
-- -- factions/sh_police.lua, registered as 'police'
-- FACTION.name = 'Police'
-- FACTION.description = 'Keeps order in the city.'
-- FACTION.color = Color(60, 100, 200)
-- FACTION.whitelisted = true
-- FACTION.models.universal = { 'models/police.mdl' }
-- FACTION:add_rank('recruit', 'Rct.')
-- FACTION:add_rank('officer', 'Ofc.')
-- ```
-- @param directory [String folder to include files from]
function Factions.include_factions(directory)
  return Pipeline.include_folder('faction', directory)
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the ID of the player's faction.
  -- @return [String faction ID, 'player' when no faction has been networked]
  function player_meta:get_faction_id()
    return self:get_nv('faction', 'player')
  end

  --- Returns the faction the player belongs to.
  -- @return [Faction the faction, or nil if the player's faction ID is not registered]
  function player_meta:get_faction()
    return Factions.find_by_id(self:get_faction_id())
  end

  --- Returns the player's rank in their faction as an index into the faction's rank list.
  -- @return [Number rank index; on the client -1 when no rank has been networked]
  function player_meta:get_rank()
    return SERVER and self:get_character().rank or self:get_nv('rank', -1)
  end

  --- Returns the ID of the player's current rank. Errors if the player has no faction or rank.
  -- @return [String rank ID]
  function player_meta:get_rank_name()
    return self:get_faction():get_rank_name(self:get_rank())
  end

  --- Checks whether the player holds the given rank of their faction or any rank above it.
  -- @param str_rank [String rank ID, letter case is ignored]
  -- @param strict=false [Boolean meant to require exactly that rank; currently has no effect]
  -- @return [Boolean false as well when the player has no rank or the rank does not exist]
  function player_meta:is_rank(str_rank, strict)
    local faction_table = self:get_faction()
    local rank = self:get_rank()

    if rank != -1 and faction_table then
      for k, v in ipairs(faction_table.rank) do
        if string.utf8lower(v.id) == string.utf8lower(str_rank) then
          return (strict and k == rank) or k <= rank
        end
      end
    end

    return false
  end

  --- Returns the faction whitelists of the player.
  -- @return [List Whitelist records on the server, whitelisted faction IDs on the client]
  function player_meta:get_whitelists()
    return SERVER and self.record.whitelists or self:get_nv('whitelists', {})
  end

  --- Checks whether the player is whitelisted for a faction.
  -- @param faction_id [String]
  -- @return [Boolean]
  function player_meta:has_whitelist(faction_id)
    local whitelists = self:get_whitelists()

    if CLIENT then
      return table.HasValue(whitelists, faction_id)
    end

    for k, v in pairs(whitelists) do
      if v.faction_id == faction_id then
        return true
      end
    end

    return false
  end

  if SERVER then
    --- Moves the player into a faction: resets the rank to 1, regenerates the name, sets the team,
    -- adjusts gender and model, and runs both factions' leave and join callbacks. Server only.
    -- @param id [String ID of a registered faction]
    function player_meta:set_faction(id)
      local old_faction = self:get_faction()
      local faction_table = Factions.find_by_id(id)
      local char = self:get_character()

      Characters.set_name(self, faction_table:generate_name(self, 1))

      self:set_nv('faction', id)
      self:set_rank(1)
      self:SetTeam(faction_table.team_id)

      if char then
        char.faction = id
      end

      if !faction_table.has_gender then
        Characters.set_gender(self, CHAR_GENDER_NONE)
      elseif !old_faction or old_faction and !old_faction.has_gender then
        Characters.set_gender(self, math.random(CHAR_GENDER_MALE, CHAR_GENDER_FEMALE))
      end

      Characters.set_model(self, faction_table:get_random_model(self))

      if old_faction then
        old_faction:on_player_leave(self)
      end

      faction_table:on_player_join(self)

      hook.Run('OnPlayerFactionChanged', self, faction_table, old_faction)
    end

    --- Sets the player's rank in their current faction, networks it and regenerates their name
    -- from the faction's name template. Server only.
    -- @param rank [Number rank index, 1 being the lowest; ignored if the faction has no such rank]
    function player_meta:set_rank(rank)
      local faction_table = self:get_faction()

      if !rank or !faction_table:get_rank(rank) then return end

      local old_rank = self:get_rank()

      if isstring(rank) then
        for k, v in ipairs(faction_table.rank) do
          if string.utf8lower(v.id) == string.utf8lower(rank) then
            rank = v.id

            break
          end
        end
      end

      self:get_character().rank = rank
      self:set_nv('rank', rank)

      Characters.set_name(self, faction_table:generate_name(self, rank))

      hook.Run('OnRankChanged', self, rank, old_rank)
    end

    --- Moves the player one rank up unless they already hold the highest rank. Server only.
    function player_meta:promote_rank()
      local rank = self:get_rank()

      if rank < #self:get_faction():get_ranks() then
        self:set_rank(rank + 1)
      end
    end

    --- Moves the player one rank down unless they already hold the lowest rank. Server only.
    function player_meta:demote_rank()
      local rank = self:get_rank()

      if rank > 1 then
        self:set_rank(rank - 1)
      end
    end

    --- Whitelists the player for a faction by adding a Whitelist record to their user record
    -- and networking the updated list. Does nothing if they already have it. Server only.
    -- @param faction_id [String]
    function player_meta:give_whitelist(faction_id)
      if !self:has_whitelist(faction_id) then
        local whitelist = Whitelist.new()
          whitelist.faction_id = faction_id
        table.insert(self.record.whitelists, whitelist)

        local whitelist_table = self:get_nv('whitelists', {})
          table.insert(whitelist_table, faction_id)
        self:set_nv('whitelists', whitelist_table)
      end
    end

    --- Removes the player's whitelist for a faction, destroying its Whitelist record and
    -- networking the updated list. Server only.
    -- @param faction_id [String]
    function player_meta:take_whitelist(faction_id)
      if self:has_whitelist(faction_id) then
        for k, v in pairs(self.record.whitelists) do
          if v.faction_id == faction_id then
            v:destroy()
            table.remove(self.record.whitelists, k)

            break
          end
        end

        local whitelist_table = self:get_nv('whitelists', {})
          table.RemoveByValue(whitelist_table, faction_id)
        self:set_nv('whitelists', whitelist_table)
      end
    end
  end
end

Pipeline.register('faction', function(id, file_name, pipe)
  FACTION = Faction.new(id)

  require_relative(file_name)

  FACTION:register() FACTION = nil
end)
