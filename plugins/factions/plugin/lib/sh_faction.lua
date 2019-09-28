if !Factions then
  PLUGIN:set_global 'Factions'
end

local stored = Factions.stored or {}
local count = Factions.count or 0
Factions.stored = stored
Factions.count = count

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

function Factions.find_by_id(id)
  return stored[id]
end

function Factions.get_players(id)
  local players = {}

  for k, v in ipairs(_player.all()) do
    if v:get_faction_id() == id then
      table.insert(players, v)
    end
  end

  return players
end

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

function Factions.all()
  return stored
end

function Factions.include_factions(directory)
  return Pipeline.include_folder('faction', directory)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_faction_id()
    return self:get_nv('faction', 'player')
  end

  function player_meta:get_faction()
    return Factions.find_by_id(self:get_faction_id())
  end

  function player_meta:get_rank()
    return SERVER and self:get_character().rank or self:get_nv('rank', -1)
  end

  function player_meta:get_rank_name()
    return self:get_faction():get_rank_name(self:get_rank())
  end

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

  function player_meta:get_whitelists()
    return SERVER and self.record.whitelists or self:get_nv('whitelists', {})
  end

  function player_meta:has_whitelist(faction_id)
    local whitelists = self:get_whitelists()

    if CLIENT then
      return table.has_value(whitelists, faction_id)
    end

    for k, v in pairs(whitelists) do
      if v.faction_id == faction_id then
        return true
      end
    end

    return false
  end

  if SERVER then
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

      hook.run('OnPlayerFactionChanged', self, faction_table, old_faction)
    end

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

      hook.run('OnRankChanged', player, rank, old_rank)
    end

    function player_meta:promote_rank()
      local rank = self:get_rank()

      if rank < #self:get_faction():get_ranks() then
        self:set_rank(rank + 1)
      end
    end

    function player_meta:demote_rank()
      local rank = self:get_rank()

      if rank > 1 then
        self:set_rank(rank - 1)
      end
    end

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
          table.remove_by_value(whitelist_table, faction_id)
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
