--- Server side of the `Factions` functions: who may be moved into a faction, the default
-- description of its members, the character counts that character creation shows, and what
-- the members of a faction get from the faction and their rank: weapons, maximum health and
-- armor, a model and the feelings of NPCs.

local IsValid = IsValid
local isnumber = isnumber
local isstring = isstring
local istable = istable

local relation_priority = 1
local default_max_health = 100
local default_max_armor = 100

local function set_model(target, model)
  if !isstring(model) or model == '' then return end

  if string.lower(target:GetModel() or '') != string.lower(model) then
    target:SetModel(model)
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
  return t(faction_table.phys_desc or '', nil, Flux.Lang:get_player_lang(target))
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
    for _, char in ipairs(target.record.characters) do
      if char != except and isstring(char.faction) then
        counts[char.faction] = (counts[char.faction] or 0) + 1
      end
    end
  end

  target:set_private_nv('faction_characters', counts)
end

--- Brings the weapons of a player in line with the loadout of their faction and rank:
-- gives the weapons of the loadout that they do not have, and takes back the weapons it
-- gave earlier that are not in the loadout any more. Which weapons it gave is remembered
-- in the faction_weapons field of the player, so a weapon they hold for another reason,
-- such as the default loadout, is left alone. Server only.
-- @param target [Player a living player]
-- @see [Faction#get_loadout]
function Factions.give_loadout(target)
  local faction_table, rank = Factions.get_membership(target)
  local loadout = faction_table and faction_table:get_loadout(rank) or {}
  local given = target.faction_weapons or {}

  target.faction_weapons = given

  for weapon_class in pairs(given) do
    if !table.HasValue(loadout, weapon_class) then
      target:StripWeapon(weapon_class)

      given[weapon_class] = nil
    end
  end

  for _, weapon_class in ipairs(loadout) do
    if !target:HasWeapon(weapon_class) then
      target:Give(weapon_class)

      given[weapon_class] = true
    end
  end
end

--- Sets the maximum health and armor of a player to those of their faction and rank. A
-- player whose faction and rank set none gets the defaults of 100 back if a faction had
-- changed them before, and is left alone otherwise. A maximum health returned by the
-- GetPlayerMaxHealth hook takes the place of the one of the faction and rank. Server only.
-- @param target [Player]
-- @param refill=false [Boolean also set the health and armor of the player to these
--   maximums, as is done when they spawn]
-- @see [Faction#get_max_health]
function Factions.apply_vitals(target, refill)
  local faction_table, rank = Factions.get_membership(target)
  local max_health = faction_table and faction_table:get_max_health(rank)
  local max_armor = faction_table and faction_table:get_max_armor(rank)

  --- Lets plugins decide the maximum health of a player. Called on the server by
  -- `Factions.apply_vitals` when a player spawns and when their faction or rank changes,
  -- after the maximum health of the faction and rank has been looked up. The Levels plugin
  -- answers it with the maximum health of the player's level.
  -- @param target [Player The player whose vitals are being applied]
  -- @param max_health [Number Maximum health of the faction and rank; nil when they set
  --   none]
  -- @return [Number Return a maximum health to use instead, rounded down and never lower
  --   than 1. It is applied, and filled up on spawn, the way the maximum health of a
  --   faction is. Return nothing to keep the one of the faction and rank]
  local hook_max_health = hook.Run('GetPlayerMaxHealth', target, max_health)

  if isnumber(hook_max_health) and hook_max_health == hook_max_health then
    max_health = math.max(math.floor(hook_max_health), 1)
  end

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
-- Server only.
-- @param target [Player]
-- @see [Factions.get_rank_model]
function Factions.apply_model(target)
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

  local faction_table = Factions.get_membership(target)

  if !faction_table or !istable(faction_table.npc_relations) then return end

  for npc_class in pairs(faction_table.npc_relations) do
    local disposition = faction_table:get_npc_disposition(npc_class)

    if disposition then
      for _, npc in ipairs(ents.FindByClass(npc_class)) do
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

  for _, client in player.Iterator() do
    local faction_table = Factions.get_membership(client)
    local disposition = faction_table and faction_table:get_npc_disposition(npc_class)

    if disposition then
      set_npc_relation(client, npc, disposition)
    end
  end
end
