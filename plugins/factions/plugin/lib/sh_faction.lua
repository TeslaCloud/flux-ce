--- Player extensions of the Factions plugin: the faction, rank and whitelists of a player.
-- Every player is in a faction and holds a rank in it, and has a list of the factions they are
-- whitelisted for. The player methods read these on the server and the client; on the server
-- they also move the player to another faction, change their rank and give or take whitelists.
--
-- This file also holds the `Factions` functions that register and look up factions, count
-- their members against the limits of the factions and their ranks, tell who may promote and
-- demote whom, and, on the server, give the members of a faction what the faction and their
-- rank grant them: weapons, maximum health and armor, a model and the feelings of NPCs. The
-- loader of faction definition files is here as well.
-- @module [Player]

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
local function get_membership(target)
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
  count = count + 1

  for k, v in pairs(data.model_classes) do
    local gender_models = data:get_gender_models(k)

    if gender_models then
      for k1, v1 in pairs(gender_models) do
        Flux.Anim:set_model_class(v1, v)
      end
    end
  end

  for k, v in ipairs(data.rank) do
    if isstring(v.model) then
      if v.model_class then
        Flux.Anim:set_model_class(v.model, v.model_class)
      end
    elseif istable(v.model) then
      for gender, model in pairs(v.model) do
        local model_class = v.model_class or data.model_classes[gender]

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

  for k, v in player.Iterator() do
    if v != except then
      local faction_table, member_rank = get_membership(v)

      if faction_table and faction_table.faction_id == id and (rank == nil or member_rank == rank) then
        members = members + 1
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
    for k, v in ipairs(target.record.characters) do
      if v.faction == faction_id then
        amount = amount + 1
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

--- Returns the model that a player uses because of their rank, instead of the model of
-- their character.
-- @param target [Player]
-- @return [String model path, or nil if the rank of the player does not change the model]
-- @see [Faction#get_rank_model]
function Factions.get_rank_model(target)
  local faction_table, rank = get_membership(target)

  if faction_table then
    return faction_table:get_rank_model(rank, target:get_gender())
  end
end

--- Checks whether the rank of a player lets them promote another player. Both have to be
-- members of the same faction, the rank of the actor has to have the can_promote field, and
-- the rank the target would be promoted to must exist and be no higher than that field
-- allows. Nobody may promote themselves. The permissions of staff are not looked at here:
-- the PromoteRank command accepts either.
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

  local faction_table, rank = get_membership(actor)
  local target_faction, target_rank = get_membership(target)

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
-- the DemoteRank command accepts either.
-- @param actor [Player the player who wants to demote]
-- @param target [Player the player who would be demoted]
-- @return [Boolean]
-- @see [Factions.can_promote]
function Factions.can_demote(actor, target)
  if actor == target then return false end

  local faction_table, rank = get_membership(actor)
  local target_faction, target_rank = get_membership(target)

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
  return Pipeline.include_folder('faction', directory)
end

if SERVER then
  local relation_priority = 1
  local default_max_health = 100
  local default_max_armor = 100

  --- Sets the model of a player unless they have that model already.
  -- @param target [Player]
  -- @param model [String model path; ignored when it is not a string or is empty]
  local function set_model(target, model)
    if !isstring(model) or model == '' then return end

    if string.lower(target:GetModel() or '') != string.lower(model) then
      target:SetModel(model)
    end
  end

  --- Returns the class of a player, if the Classes plugin is loaded.
  -- @param target [Player]
  -- @return [CharacterClass the class, or nil if the player has none]
  local function get_class(target)
    if Classes then
      return target:get_class()
    end
  end

  --- Makes an NPC feel about a player in a given way, remembering how it felt before so
  -- that `Factions.reset_npc_relations` can undo it.
  -- @param target [Player]
  -- @param npc [NPC]
  -- @param disposition [Number D_* value]
  local function set_npc_relation(target, npc, disposition)
    local previous = target.faction_npc_relations

    if !previous then
      previous = setmetatable({}, { __mode = 'k' })

      target.faction_npc_relations = previous
    end

    if previous[npc] == nil then
      previous[npc] = npc:Disposition(target)
    end

    npc:AddEntityRelationship(target, disposition, relation_priority)
  end

  --- Checks whether a player may be moved into a faction: asks the `Faction:can_transfer`
  -- callback of that faction, then the PlayerCanTransferFaction hook. The SetFaction command
  -- uses it; `Player:set_faction` moves the player without asking. Server only.
  -- ```
  -- local allowed, reason, arguments = Factions.can_transfer(target, faction_table)
  --
  -- if allowed then
  --   target:set_faction(faction_table.faction_id)
  -- else
  --   actor:notify(reason, arguments)
  -- end
  -- ```
  -- @param target [Player the player who is to be moved]
  -- @param faction_table [Faction the faction they are to be moved into]
  -- @return [Boolean true when the transfer is allowed; otherwise false, String the reason
  --   as a language phrase and Map the arguments of the phrase]
  function Factions.can_transfer(target, faction_table)
    local arguments = {
      target = IsValid(target) and target:name() or '',
      faction = faction_table and faction_table.name or ''
    }

    if !IsValid(target) or !faction_table then
      return false, 'error.faction.transfer_refused', arguments
    end

    local old_faction = target:get_faction()
    local allowed, reason, reason_arguments = faction_table:can_transfer(target, old_faction)

    if allowed != false then
      --- Decides whether a player may be moved into a faction. Called on the server by
      -- `Factions.can_transfer`, which the SetFaction command uses, after the can_transfer
      -- callback of the faction has allowed it.
      -- @param target [Player the player who is to be moved]
      -- @param faction_table [Faction the faction they are to be moved into]
      -- @param old_faction [Faction the faction they are in, nil if it is not registered]
      -- @return [Boolean return false to refuse the transfer, String a language phrase that
      --   tells why and Map the arguments of the phrase; a generic text is used when the
      --   reason is omitted]
      allowed, reason, reason_arguments = hook.Run('PlayerCanTransferFaction', target, faction_table, old_faction)
    end

    if allowed == false then
      if isstring(reason) then
        return false, reason, reason_arguments
      end

      return false, 'error.faction.transfer_refused', arguments
    end

    return true
  end

  --- Returns the physical description that a faction gives to the characters of a player,
  -- translated to the language of that player. Server only.
  -- @param faction_table [Faction]
  -- @param target=nil [Player the player whose language is used; English without one]
  -- @return [String]
  function Factions.get_default_description(faction_table, target)
    local description = t(faction_table.phys_desc or '', nil, Flux.Lang:get_player_lang(target))

    return description
  end

  --- Networks to a player how many characters they have in each faction, which lets their
  -- client tell whether they may create another character of a faction. The plugin calls it
  -- whenever the characters of a player or their factions change. Server only.
  -- @param target [Player]
  -- @param except=nil [Character character that is not counted, such as one that is about
  --   to be deleted]
  function Factions.send_character_counts(target, except)
    if !IsValid(target) or target:IsBot() or !istable(target.record) then return end

    local counts = {}

    if istable(target.record.characters) then
      for k, v in ipairs(target.record.characters) do
        if v != except and isstring(v.faction) then
          counts[v.faction] = (counts[v.faction] or 0) + 1
        end
      end
    end

    target:set_private_nv('faction_characters', counts)
  end

  --- Brings the weapons of a player in line with the loadout of their faction and rank:
  -- gives the weapons of the loadout that they do not have, and takes back the weapons it
  -- gave earlier that are not in the loadout any more. Which weapons it gave is remembered
  -- in the faction_weapons field of the player, so a weapon they hold for another reason,
  -- such as the default loadout or the loadout of their class, is left alone. Server only.
  -- @param target [Player a living player]
  -- @see [Faction#get_loadout]
  function Factions.give_loadout(target)
    local faction_table, rank = get_membership(target)
    local loadout = faction_table and faction_table:get_loadout(rank) or {}
    local given = target.faction_weapons or {}
    local class_table = get_class(target)
    local class_loadout = class_table and class_table:get_loadout() or {}

    target.faction_weapons = given

    for weapon_class, v in pairs(given) do
      if !table.HasValue(loadout, weapon_class) then
        if !table.HasValue(class_loadout, weapon_class) then
          target:StripWeapon(weapon_class)
        end

        given[weapon_class] = nil
      end
    end

    for k, v in ipairs(loadout) do
      if !target:HasWeapon(v) then
        target:Give(v)

        given[v] = true
      end
    end
  end

  --- Sets the maximum health and armor of a player to those of their faction and rank. A
  -- player whose faction and rank set none gets the defaults of 100 back if a faction had
  -- changed them before, and is left alone otherwise. Server only.
  -- @param target [Player]
  -- @param refill=false [Boolean also set the health and armor of the player to these
  --   maximums, as is done when they spawn]
  -- @see [Faction#get_max_health]
  function Factions.apply_vitals(target, refill)
    local faction_table, rank = get_membership(target)
    local max_health = faction_table and faction_table:get_max_health(rank)
    local max_armor = faction_table and faction_table:get_max_armor(rank)

    if max_health then
      target:SetMaxHealth(max_health)
    elseif target.faction_max_health then
      target:SetMaxHealth(default_max_health)
    end

    if max_armor then
      target:SetMaxArmor(max_armor)
    elseif target.faction_max_armor then
      target:SetMaxArmor(default_max_armor)
    end

    target.faction_max_health = max_health
    target.faction_max_armor = max_armor

    if refill then
      if max_health then
        target:SetHealth(max_health)
      end

      if max_armor then
        target:SetArmor(max_armor)
      end
    end
  end

  --- Gives a player the model of their rank, if the rank has one, and gives the model of
  -- their character back once it has none. The model of the character itself is not changed.
  -- A class of the Classes plugin that has a model of its own takes precedence. Server only.
  -- @param target [Player]
  -- @see [Factions.get_rank_model]
  function Factions.apply_model(target)
    local class_table = get_class(target)

    if class_table and class_table:get_model(target) then
      target.faction_model = nil

      return
    end

    local model = Factions.get_rank_model(target)

    if model then
      target.faction_model = model

      set_model(target, model)
    elseif target.faction_model then
      target.faction_model = nil

      set_model(target, target:get_nv('model'))
    end
  end

  --- Gives a player everything their faction and rank grant to someone who is already in
  -- the world: the maximum health and armor, the model of the rank and, if they are alive,
  -- the weapons. The plugin calls it when the faction or the rank of a player changes.
  -- Server only.
  -- @param target [Player]
  function Factions.apply_membership(target)
    Factions.apply_vitals(target)
    Factions.apply_model(target)

    if target:Alive() then
      Factions.give_loadout(target)
    end
  end

  --- Makes NPCs feel about a player the way they did before the faction of the player
  -- changed it. Server only.
  -- @param target [Player]
  function Factions.reset_npc_relations(target)
    local previous = target.faction_npc_relations

    if !previous then return end

    for npc, disposition in pairs(previous) do
      if IsValid(npc) then
        npc:AddEntityRelationship(target, disposition != D_ER and disposition or D_NU, relation_priority)
      end
    end

    target.faction_npc_relations = nil
  end

  --- Makes the NPCs that exist feel about a player the way the npc_relations field of the
  -- faction of the player says, after undoing what an earlier faction has changed. The
  -- plugin calls it when a character is loaded and when the faction of a player changes.
  -- Server only.
  -- @param target [Player]
  -- @see [Factions.setup_npc]
  function Factions.apply_npc_relations(target)
    Factions.reset_npc_relations(target)

    local faction_table = get_membership(target)

    if !faction_table or !istable(faction_table.npc_relations) then return end

    for npc_class, v in pairs(faction_table.npc_relations) do
      local disposition = faction_table:get_npc_disposition(npc_class)

      if disposition then
        for k1, npc in ipairs(ents.FindByClass(npc_class)) do
          if npc:IsNPC() then
            set_npc_relation(target, npc, disposition)
          end
        end
      end
    end
  end

  --- Makes an NPC feel about every player the way the factions of the players say. The
  -- plugin calls it for every NPC right after it has been created. Server only.
  -- @param npc [NPC]
  -- @see [Factions.apply_npc_relations]
  function Factions.setup_npc(npc)
    if !IsValid(npc) or !npc:IsNPC() then return end

    local npc_class = npc:GetClass()

    for k, v in player.Iterator() do
      local faction_table = get_membership(v)
      local disposition = faction_table and faction_table:get_npc_disposition(npc_class)

      if disposition then
        set_npc_relation(v, npc, disposition)
      end
    end
  end
end

do
  local player_meta = FindMetaTable('Player')

  --- Returns the ID of the player's faction. On the server it is read from the active
  -- character, so that it is right as soon as the character is selected.
  -- @return [String faction ID, 'player' when no faction has been networked]
  function player_meta:get_faction_id()
    if SERVER then
      local char = self.current_character

      if char and isstring(char.faction) then
        return char.faction
      end
    end

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

  --- Returns the table of the rank the player holds in their faction.
  -- @return [Map rank table with id and name fields and the optional fields described at
  --   `Faction:add_rank`; nil if the player is not a member of a faction or has no rank]
  function player_meta:get_rank_table()
    local faction_table, rank = get_membership(self)

    return faction_table and rank != nil and faction_table:get_rank(rank) or nil
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
    --- Moves the player into a faction: resets the rank to the default rank of the faction,
    -- regenerates the name, sets the team, adjusts gender and model, gives the default
    -- description of a faction that does not let players write one, and runs both factions'
    -- leave and join callbacks. The player then gets the weapons, the maximum health and
    -- armor and the rank model of the new faction, and NPCs feel about them as that faction
    -- says. Neither the limit of the faction nor its can_transfer callback is checked; see
    -- `Factions.can_transfer`. Server only.
    -- @param id [String ID of a registered faction]
    function player_meta:set_faction(id)
      local old_faction = self:get_faction()
      local faction_table = Factions.find_by_id(id)
      local char = self:get_character()
      local default_rank = faction_table:get_default_rank()

      Characters.set_name(self, faction_table:generate_name(self, default_rank))

      self:set_nv('faction', id)

      if char then
        char.faction = id
      end

      self:set_rank(default_rank)
      self:SetTeam(faction_table.team_id)

      if !faction_table.has_gender then
        Characters.set_gender(self, CHAR_GENDER_NONE)
      elseif !old_faction or old_faction and !old_faction.has_gender then
        Characters.set_gender(self, math.random(CHAR_GENDER_MALE, CHAR_GENDER_FEMALE))
      end

      Characters.set_model(self, faction_table:get_random_model(self))

      if !faction_table.has_description then
        Characters.set_desc(self, Factions.get_default_description(faction_table, self))
      end

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
      hook.Run('OnPlayerFactionChanged', self, faction_table, old_faction)
    end

    --- Sets the player's rank in their current faction, networks it, regenerates their name
    -- from the faction's name template and gives them the model, the weapons and the maximum
    -- health and armor of the rank. The limit of the rank is not checked. Server only.
    -- @param rank [Number rank index, 1 being the lowest; ignored if the faction has no such rank]
    function player_meta:set_rank(rank)
      local faction_table = self:get_faction()

      if !rank or !faction_table:get_rank(rank) then return end

      local old_rank = self:get_rank()

      self:get_character().rank = rank
      self:set_nv('rank', rank)

      Characters.set_name(self, faction_table:generate_name(self, rank))

      Factions.apply_membership(self)

      --- Called on the server after `Player:set_rank` has changed the rank of a player,
      -- networked it, regenerated their name and given them the model, the weapons and the
      -- maximum health and armor of the rank.
      -- @param target [Player]
      -- @param rank [Number the new rank index]
      -- @param old_rank [Number the rank index before the change]
      hook.Run('OnRankChanged', self, rank, old_rank)
    end

    --- Moves the player one rank up unless they already hold the highest rank. Server only.
    -- @return [Boolean true when the player was promoted]
    function player_meta:promote_rank()
      local faction_table, rank = get_membership(self)

      if faction_table and isnumber(rank) and faction_table:get_rank(rank + 1) then
        self:set_rank(rank + 1)

        return true
      end

      return false
    end

    --- Moves the player one rank down unless they already hold the lowest rank. Server only.
    -- @return [Boolean true when the player was demoted]
    function player_meta:demote_rank()
      local faction_table, rank = get_membership(self)

      if faction_table and isnumber(rank) and rank > 1 and faction_table:get_rank(rank - 1) then
        self:set_rank(rank - 1)

        return true
      end

      return false
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
