--- The shared `Factions` functions: they register and look up factions, count their members
-- against the limits of the factions and their ranks and tell who may promote and demote
-- whom. The loader of faction definition files is here as well. What the members of a
-- faction get from it on the server is in `sv_faction.lua`, and the player methods that read
-- and change the faction, rank and whitelists of a player are in `lib/meta`.
-- @module [Factions]

local IsValid = IsValid
local isnumber = isnumber
local isstring = isstring
local istable = istable
local tonumber = tonumber

if !Factions then
  PLUGIN:set_global 'Factions'
end

local stored = Factions.stored or {}
local count = Factions.count or 0
Factions.stored = stored
Factions.count = count

--- Returns the faction of a player and their rank in it, if the player counts as a member:
-- bots always do, other players only while they have an active character.
-- @param target [Player]
-- @return [Faction the faction and Number the rank index (nil for a bot that has no rank
--   yet, -1 on the client when no rank has been networked); nothing for anyone who is not a
--   member of a registered faction]
function Factions.get_membership(target)
  if !IsValid(target) or !target:IsPlayer() then return end
  if !target:IsBot() and !target:is_character_loaded() then return end

  local faction_table = target:get_faction()

  if !faction_table then return end

  return faction_table, target:get_rank()
end

--- Turns the can_promote or can_demote field of a rank into a rank index.
-- @param faction_table [Faction the faction of the rank]
-- @param rank [Number index of the rank that has the field]
-- @param value [Number/String/Boolean rank index, rank ID, or true for the rank below]
-- @return [Number rank index, or nil if the field grants nothing]
local function get_authority(faction_table, rank, value)
  if value == true then
    return rank - 1
  elseif isnumber(value) then
    return value
  elseif isstring(value) then
    return (faction_table:find_rank(value))
  end
end

--- Registers a faction: fills in the default name, description and color, sets up its team
-- and assigns the animation class of each of its models and of the models of its ranks.
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
  data.limit = tonumber(data.limit) or 0
  data.max_characters = tonumber(data.max_characters) or 0
  data.loadout = istable(data.loadout) and data.loadout or {}
  data.npc_relations = istable(data.npc_relations) and data.npc_relations or {}

  team.SetUp(count + 1, data.name, data.color)

  data.team_id = count + 1

  stored[data.faction_id] = data
  count += 1

  for gender, model_class in pairs(data.model_classes) do
    local gender_models = data:get_gender_models(gender)

    if gender_models then
      for _, model_path in pairs(gender_models) do
        Flux.Anim:set_model_class(model_path, model_class)
      end
    end
  end

  for _, rank_table in ipairs(data.rank) do
    if isstring(rank_table.model) then
      if rank_table.model_class then
        Flux.Anim:set_model_class(rank_table.model, rank_table.model_class)
      end
    elseif istable(rank_table.model) then
      for gender, model in pairs(rank_table.model) do
        local model_class = rank_table.model_class or data.model_classes[gender]

        if isstring(model) and model_class then
          Flux.Anim:set_model_class(model, model_class)
        end
      end
    end
  end

  for npc_class, value in pairs(data.npc_relations) do
    if !data:get_npc_disposition(npc_class) then
      ErrorNoHalt('[Flux:Factions] The \''..data.faction_id..'\' faction has an invalid relation \''..
        tostring(value)..'\' towards \''..tostring(npc_class)..'\'!\n')
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

  for _, client in player.Iterator() do
    if client:get_faction_id() == id then
      players[#players + 1] = client
    end
  end

  return players
end

--- Finds a faction by its whole ID or its whole name, ignoring letter case. The name may be
-- given as the language phrase the faction is registered with or as its translation. An ID
-- is matched before any name.
-- @param name [String faction ID or name]
-- @return [Faction/Boolean the faction, or false if no faction has this ID or name]
function Factions.find(name)
  if !isstring(name) then return false end

  local lowered = name:utf8lower()

  for faction_id, faction_table in pairs(stored) do
    if faction_id:utf8lower() == lowered then
      return faction_table
    end
  end

  for _, faction_table in pairs(stored) do
    local faction_name = tostring(faction_table.name)

    if faction_name:utf8lower() == lowered or t(faction_name):utf8lower() == lowered then
      return faction_table
    end
  end

  return false
end

--- Returns every registered faction.
-- @return [Map factions keyed by faction ID]
function Factions.all()
  return stored
end

--- Returns how many members of a faction, or holders of one of its ranks, may be online at
-- once: the limit field of the faction or of the rank, unless a GetFactionLimit hook returns
-- another number.
-- @param id [String faction ID]
-- @param rank=nil [Number rank index; the limit of the faction is returned without it]
-- @return [Number 0 when there is no limit, and when the faction or the rank does not exist]
function Factions.get_limit(id, rank)
  local faction_table = stored[id]

  if !faction_table then return 0 end

  local rank_table
  local limit

  if rank != nil then
    rank_table = faction_table:get_rank(rank)

    if !rank_table then return 0 end

    limit = tonumber(rank_table.limit) or 0
  else
    limit = tonumber(faction_table.limit) or 0
  end

  --- Lets plugins change how many members of a faction, or holders of one of its ranks, may
  -- be online at once, for example to scale the limit with the amount of players online.
  -- Called on both realms by `Factions.get_limit`.
  -- @param faction_table [Faction the faction]
  -- @param limit [Number the limit set by the definition of the faction or of the rank, 0
  --   for no limit]
  -- @param rank_table [Map the rank whose limit is asked for, nil when it is the limit of
  --   the whole faction]
  -- @return [Number the limit to use instead, 0 for no limit; return nothing to keep the
  --   limit of the definition]
  local override = hook.Run('GetFactionLimit', faction_table, limit, rank_table)

  if isnumber(override) then
    limit = override
  end

  return math.max(0, limit)
end

--- Checks whether a faction, or one of its ranks, has as many members online as its limit
-- allows. Bots and players with an active character count as members.
-- @param id [String faction ID]
-- @param rank=nil [Number rank index; the whole faction is checked without it]
-- @param except=nil [Player player who is not counted, such as the one who wants to join]
-- @return [Boolean false as well when there is no limit]
-- @see [Factions.get_limit]
function Factions.is_full(id, rank, except)
  local limit = Factions.get_limit(id, rank)

  if limit <= 0 then return false end

  local members = 0

  for _, client in player.Iterator() do
    if client != except then
      local faction_table, member_rank = Factions.get_membership(client)

      if faction_table and faction_table.faction_id == id and (rank == nil or member_rank == rank) then
        members += 1
      end
    end
  end

  return members >= limit
end

--- Returns how many characters of a faction a player has. The server counts the characters
-- of the player's record; a client only knows the count of the local player, which the
-- server networks to them.
-- @param target [Player]
-- @param faction_id [String]
-- @return [Number]
function Factions.count_characters(target, faction_id)
  if CLIENT then
    local counts = target:get_nv('faction_characters')

    return istable(counts) and tonumber(counts[faction_id]) or 0
  end

  local amount = 0

  if istable(target.record) and istable(target.record.characters) then
    for _, char in ipairs(target.record.characters) do
      if char.faction == faction_id then
        amount += 1
      end
    end
  end

  return amount
end

--- Checks whether a player has as many characters of a faction as its max_characters field
-- allows, so that they cannot create another one. On the client only the local player can
-- be checked.
-- @param target [Player]
-- @param faction_id [String]
-- @return [Boolean false as well when the faction does not limit the characters]
-- @see [Factions.count_characters]
function Factions.character_limit_reached(target, faction_id)
  local faction_table = stored[faction_id]
  local maximum = faction_table and tonumber(faction_table.max_characters) or 0

  return maximum > 0 and Factions.count_characters(target, faction_id) >= maximum
end

--- Checks whether a player may create a character in a faction without being whitelisted
-- for it and beyond the amount of characters the faction allows them, which is what a
-- PlayerCanBypassFactionCreationLimits handler decides.
-- @param target [Player]
-- @param data [Map creation data on the server; on the client the extra data of the creation
--   screen, nil when it has none]
-- @return [Boolean]
function Factions.can_bypass_creation_limits(target, data)
  --- Decides whether a player may create a character in a faction they are not whitelisted
  -- for, or beyond the amount of characters the faction allows them. Called on the server
  -- when a creation request is checked, and on the client for the local player when the
  -- faction stage of the creation screen lists the factions and checks the chosen one, so
  -- a handler that is meant to be seen in the menu has to be shared.
  -- @param target [Player the player who creates the character]
  -- @param data [Map the creation data on the server; the extra data of the creation screen
  --   on the client, nil when it has none]
  -- @return [Boolean return true to let the player create the character regardless of the
  --   whitelist and the limit]
  return hook.Run('PlayerCanBypassFactionCreationLimits', target, data) == true
end

--- Returns the model that a player uses because of their rank, instead of the model of
-- their character.
-- @param target [Player]
-- @return [String model path, or nil if the rank of the player does not change the model]
-- @see [Faction#get_rank_model]
function Factions.get_rank_model(target)
  local faction_table, rank = Factions.get_membership(target)

  if faction_table then
    return faction_table:get_rank_model(rank, target:get_gender())
  end
end

--- Checks whether the rank of a player lets them promote another player. Both have to be
-- members of the same faction, the rank of the actor has to have the can_promote field, and
-- the rank the target would be promoted to must exist and be no higher than that field
-- allows. Nobody may promote themselves. The permissions of staff are not looked at here:
-- the `/rank promote` command accepts either.
-- ```
-- FACTION:add_rank('recruit')
-- FACTION:add_rank('officer')
-- FACTION:add_rank('sergeant', 'Sgt.', { can_promote = 'officer' })
--
-- -- A sergeant may promote a recruit to officer, but not an officer to sergeant.
-- if Factions.can_promote(sergeant, recruit) then
--   recruit:promote_rank()
-- end
-- ```
-- @param actor [Player the player who wants to promote]
-- @param target [Player the player who would be promoted]
-- @return [Boolean]
-- @see [Factions.can_demote]
function Factions.can_promote(actor, target)
  if actor == target then return false end

  local faction_table, rank = Factions.get_membership(actor)
  local target_faction, target_rank = Factions.get_membership(target)

  if !faction_table or faction_table != target_faction or !isnumber(target_rank) then return false end

  local rank_table = faction_table:get_rank(rank)
  local highest = rank_table and get_authority(faction_table, rank, rank_table.can_promote)

  if !highest or !faction_table:get_rank(target_rank) then return false end

  local new_rank = target_rank + 1

  return faction_table:get_rank(new_rank) != nil and new_rank <= highest
end

--- Checks whether the rank of a player lets them demote another player. Both have to be
-- members of the same faction, the rank of the actor has to have the can_demote field, and
-- the target must hold a rank that is not the lowest one and is no higher than that field
-- allows. Nobody may demote themselves. The permissions of staff are not looked at here:
-- the `/rank demote` command accepts either.
-- @param actor [Player the player who wants to demote]
-- @param target [Player the player who would be demoted]
-- @return [Boolean]
-- @see [Factions.can_promote]
function Factions.can_demote(actor, target)
  if actor == target then return false end

  local faction_table, rank = Factions.get_membership(actor)
  local target_faction, target_rank = Factions.get_membership(target)

  if !faction_table or faction_table != target_faction or !isnumber(target_rank) then return false end

  local rank_table = faction_table:get_rank(rank)
  local highest = rank_table and get_authority(faction_table, rank, rank_table.can_demote)

  if !highest or !faction_table:get_rank(target_rank) then return false end

  return target_rank > 1 and target_rank <= highest
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
  Pipeline.include_folder('faction', directory)
end

Pipeline.register('faction', function(id, file_name, _pipe)
  FACTION = Faction.new(id)

  require_relative(file_name)

  FACTION:register()
  FACTION = nil
end)
