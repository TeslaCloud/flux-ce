--- Prop Protection makes every entity a player spawns the property of the character that
-- spawned it, and builds the sandbox rules on that ownership.
-- Without the plugin the physics gun, the tool gun and the context menu are checked against
-- permissions only: whoever holds the permission may pick up or change anything. With it
-- a player may pick up, freeze, unfreeze, drive and use tools and properties on the entities
-- of their own character, whether or not they hold the `physgun_pickup` and `physgun_freeze`
-- permissions, and on nothing else. What stands in the way is one of the rules listed below,
-- each of which is switched by a config of its own and is waived for staff with the
-- `bypass_prop_protection` permission (`physgun_pickup` waives the rules for the physics gun
-- as well, and `physgun_freeze` those for freezing). Plugins overrule a single decision
-- with the `PlayerCanManipulateEntity` hook.
--
-- An entity is owned under a key made of the SteamID64 of the player and the ID of their
-- active character, which is networked to everyone in the `fl_prop_owner` variable of the
-- entity. When the owner disconnects or switches characters, their entities stay protected
-- and are removed after the `prop_removal_delay` config, unless the owner comes back on
-- that character in time. Static entities are never removed that way; they are released
-- instead. The entities of staff who are exempt from the rules stay where they are, unless
-- the `remove_staff_entities` config says otherwise.
--
-- The plugin also keeps players from being hurt by props that are held with the physics
-- gun, have just been dropped by it or have just been spawned (`prop_kill_protection`).
-- Addons that speak the Common Prop Protection Interface find the `CPPI` table and the
-- `CPPI` entity and player methods in lib/meta/sh_entity.lua.
--
-- Rules and the configs that switch them:
-- ```
-- players  - physgun_protect_players  - players cannot be picked up with the physics gun
-- vehicles - physgun_protect_vehicles - neither can vehicles that have a driver
-- ragdolls - physgun_protect_ragdolls - nor the ragdolls of players
-- owned    - prop_protection          - the entity belongs to another character
-- map      - protect_map_entities     - the entity was created by the map
-- world    - protect_world_entities   - the entity belongs to nobody (items, players, ...)
-- ```
-- The first three concern the physics gun only and are checked first. Switching one of them
-- off does not hand the entity over: the last three, which are about ownership, still apply
-- to it.
-- @module [PropProtection]

PLUGIN:set_global('PropProtection')

local rules = {
  players = 'physgun_protect_players',
  vehicles = 'physgun_protect_vehicles',
  ragdolls = 'physgun_protect_ragdolls',
  owned = 'prop_protection',
  map = 'protect_map_entities',
  world = 'protect_world_entities'
}

local action_permissions = {
  physgun = 'physgun_pickup',
  freeze = 'physgun_freeze'
}

PropProtection.rules = rules

--- Owners that the client has looked up lately, by ownership key: the player and the
-- RealTime() until which the answer is trusted. The lookup walks every player, and the
-- target ID asks for it every frame, so the client keeps the answer for a moment.
local owner_cache = {}

--- Seconds for which the client trusts a cached owner lookup.
local owner_cache_time = 0.5

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Returns the key that entities are owned under by the active character of a player: the
-- SteamID64 of the player and the ID of the character, which is 0 when the Characters plugin
-- is not loaded or no character is active.
-- @param target [Player]
-- @return [String ownership key, such as '76561198000000000:12'; nil if the SteamID64 of the
--   player is not known, which is the case for bots on the client]
function PropProtection:get_key(target)
  local steam_id = target:SteamID64()

  if !steam_id then return end

  local character_id = Characters and tonumber(target:get_character_id()) or 0

  return steam_id..':'..character_id
end

--- Finds the connected player who currently plays the character behind an ownership key.
-- On the client the answer is kept for half a second, as the lookup walks every player and
-- is asked for every frame while an owned entity is looked at; the server always looks.
-- @param key [String ownership key, see PropProtection:get_key]
-- @return [Player the owner, or nil if they are not connected or play another character]
function PropProtection:find_owner(key)
  if !isstring(key) then return end

  if CLIENT then
    local cached = owner_cache[key]

    if cached and cached.expires > RealTime() then
      return IsValid(cached.owner) and cached.owner or nil
    end
  end

  local owner

  for k, v in player.Iterator() do
    if self:get_key(v) == key then
      owner = v

      break
    end
  end

  if CLIENT then
    owner_cache[key] = { owner = owner or false, expires = RealTime() + owner_cache_time }
  end

  return owner
end

--- Checks whether an entity was created by the map. The answer comes from the engine, which
-- always knows it on the server; a client that cannot tell treats the entity as not created
-- by the map.
-- @param entity [Entity]
-- @return [Boolean]
function PropProtection:is_map_entity(entity)
  return isfunction(entity.CreatedByMap) and entity:CreatedByMap() or false
end

--- Checks whether an entity is the ragdoll of a player, as created by the Ragdoll plugin for
-- players who are dead or knocked down. Only the server knows which player a ragdoll
-- belongs to.
-- @param entity [Entity]
-- @return [Boolean]
function PropProtection:is_player_ragdoll(entity)
  return entity:IsRagdoll() and IsValid(entity.player)
end

--- Finds the rule that keeps an entity from being picked up with the physics gun whoever
-- it belongs to, regardless of whether the rule is switched on.
-- @param entity [Entity a valid entity]
-- @return [String rule ID ('players', 'vehicles' or 'ragdolls'); nil if none of them applies]
local function find_physgun_rule(entity)
  if entity:IsPlayer() then
    return 'players'
  elseif entity:IsVehicle() and IsValid(entity:GetDriver()) then
    return 'vehicles'
  elseif PropProtection:is_player_ragdoll(entity) then
    return 'ragdolls'
  end
end

--- Finds the rule that the ownership of an entity puts between it and a player, regardless
-- of whether the rule is switched on.
-- @param actor [Player]
-- @param entity [Entity a valid entity]
-- @return [String rule ID ('owned', 'map' or 'world'); nil if the entity belongs to the
--   active character of the player]
local function find_ownership_rule(actor, entity)
  local key = entity:get_nv('fl_prop_owner')

  if key then
    if key != PropProtection:get_key(actor) then
      return 'owned'
    end

    return
  end

  if PropProtection:is_map_entity(entity) then
    return 'map'
  end

  return 'world'
end

--- Finds the first rule that stands between a player and an entity for an action, regardless
-- of whether the rule is switched on and of the permissions of the player. The rules of the
-- physics gun come before those of ownership; PropProtection:can_manipulate goes on to the
-- ownership rule when the physics gun rule it has found is switched off.
-- @param actor [Player]
-- @param entity [Entity a valid entity]
-- @param action [String 'physgun', 'freeze', 'unfreeze', 'tool', 'property' or 'drive']
-- @return [String rule ID ('players', 'vehicles', 'ragdolls', 'owned', 'map' or 'world'); nil
--   if the entity belongs to the active character of the player and no other rule applies]
function PropProtection:find_rule(actor, entity, action)
  return action == 'physgun' and find_physgun_rule(entity) or find_ownership_rule(actor, entity)
end

--- Checks whether the rules do not apply to a player: they hold the
-- `bypass_prop_protection` permission, or the permission that Flux already ties to the
-- action (`physgun_pickup` for the physics gun, `physgun_freeze` for freezing).
-- @param actor [Player]
-- @param action=nil [String action that is being checked, see PropProtection:find_rule]
-- @return [Boolean]
function PropProtection:can_bypass(actor, action)
  if actor:can('bypass_prop_protection') then
    return true
  end

  local permission = action_permissions[action]

  if permission and actor:can(permission) then
    return true
  end

  return false
end

--- Decides whether a player may do something to an entity. The world and invalid entities
-- are never protected.
-- ```
-- if !PropProtection:can_manipulate(actor, entity, 'tool', 'my_tool') then
--   return false
-- end
-- ```
-- @param actor [Player]
-- @param entity [Entity]
-- @param action [String 'physgun', 'freeze', 'unfreeze', 'tool', 'property' or 'drive';
--   plugins may pass names of their own, which are checked like 'tool']
-- @param detail=nil [String what the action is done with: the tool ID or the property name]
-- @return [Boolean whether the action is allowed, String ID of the rule that refuses it (nil
--   if it is allowed or was refused by the PlayerCanManipulateEntity hook alone)]
function PropProtection:can_manipulate(actor, entity, action, detail)
  if !IsValid(entity) then return true end

  local rule

  if !self:can_bypass(actor, action) then
    local physgun_rule = action == 'physgun' and find_physgun_rule(entity) or nil
    local ownership_rule = find_ownership_rule(actor, entity)

    if physgun_rule and Config.get(rules[physgun_rule]) then
      rule = physgun_rule
    elseif ownership_rule and Config.get(rules[ownership_rule]) then
      rule = ownership_rule
    end
  end

  --- Lets plugins overrule the decision of the Prop Protection plugin on whether a player
  -- may do something to an entity. Called on the server and, for the local player, on the
  -- client, every time the physics gun, a tool, a property or driving is checked against
  -- an entity, which for the physics gun is many times a second.
  -- @param actor [Player the player who acts]
  -- @param entity [Entity the entity that is acted on]
  -- @param action [String 'physgun', 'freeze', 'unfreeze', 'tool', 'property' or 'drive']
  -- @param rule [String ID of the rule that is about to refuse the action ('players',
  --   'vehicles', 'ragdolls', 'owned', 'map' or 'world'); nil if the plugin allows it]
  -- @param detail [String the tool ID or the property name, nil for the other actions]
  -- @return [Boolean return true to allow the action in spite of the rule, false to refuse
  --   it; the decision of the plugin stands when nothing is returned]
  local override = hook.Run('PlayerCanManipulateEntity', actor, entity, action, rule, detail)

  if override == true then
    return true
  elseif override != nil or rule then
    return false, rule
  end

  return true
end

--- Refuses to let a player pick up an entity that the rules protect from them. Nothing is
-- returned for everything else, so that the handlers of other plugins may still refuse.
-- @param actor [Player]
-- @param entity [Entity the entity that is being picked up]
-- @return [Boolean false to refuse, nothing otherwise]
function PropProtection:PhysgunPickup(actor, entity)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !self:can_manipulate(actor, entity, 'physgun') then
    return false
  end
end

--- Lets a player without the `physgun_pickup` permission pick up an entity that the rules
-- allow them, which is what makes their own entities movable. Entities that forbid the
-- physics gun themselves are left alone.
-- @param actor [Player]
-- @param entity [Entity the entity that is being picked up]
-- @return [Boolean true to allow the pickup, nothing otherwise]
function PropProtection:PlayerCanPhysgunPickup(actor, entity)
  if !IsValid(actor) or !IsValid(entity) or entity.PhysgunDisabled then return end

  if self:can_manipulate(actor, entity, 'physgun') then
    return true
  end
end

--- Refuses the use of a Sandbox tool on an entity that the rules protect from the player,
-- and of the right click of the remover when anything constrained to the entity is
-- protected. The Flux tools that are tied to a permission of their own are not checked:
-- that permission is what guards them.
-- @param actor [Player]
-- @param trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @param tool [Map tool object]
-- @param button [Number 1 for the primary attack, 2 for the secondary one, 3 for reload]
-- @return [Boolean false to block the tool, nothing otherwise]
function PropProtection:CanTool(actor, trace, tool_name, tool, button)
  if !IsValid(actor) or !istable(trace) then return end

  local flux_tool = Flux.Tool:get(tool_name)

  if flux_tool and flux_tool.permission then return end

  local entity = trace.Entity

  if !IsValid(entity) then return end

  local allowed, rule = self:can_manipulate(actor, entity, 'tool', tool_name)

  if allowed and SERVER and tool_name == 'remover' and button == 2 then
    allowed, rule = self:can_manipulate_constrained(actor, entity, 'tool', tool_name)
  end

  if !allowed then
    if SERVER then
      self:notify_refusal(actor, rule)
    end

    return false
  end
end

--- Refuses the properties of the context menu to players without the `context_menu`
-- permission, which the gamemode only checks when the menu is opened on the client, and
-- on entities that the rules protect from the player.
-- @param actor [Player]
-- @param property [String property name]
-- @param entity [Entity the entity the property is used on]
-- @return [Boolean false to refuse the property, nothing otherwise]
function PropProtection:CanProperty(actor, property, entity)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !actor:can('context_menu') then
    return false
  end

  local allowed, rule = self:can_manipulate(actor, entity, 'property', property)

  if !allowed then
    if SERVER then
      self:notify_refusal(actor, rule)
    end

    return false
  end
end

--- Refuses to let a player drive an entity without the `context_menu` permission, or an
-- entity that the rules protect from them.
-- @param actor [Player]
-- @param entity [Entity the entity the player wants to drive]
-- @return [Boolean false to refuse, nothing otherwise]
function PropProtection:CanDrive(actor, entity)
  if !IsValid(actor) or !IsValid(entity) then return end

  if !actor:can('context_menu') then
    return false
  end

  local allowed, rule = self:can_manipulate(actor, entity, 'drive')

  if !allowed then
    if SERVER then
      self:notify_refusal(actor, rule)
    end

    return false
  end
end

--- Registers the 'bypass_prop_protection' permission.
function PropProtection:RegisterPermissions()
  Bolt:register_permission(
    'bypass_prop_protection',
    'Bypass Prop Protection',
    'Grants access to the entities of other players, of the map and of nobody.',
    'permission.categories.tools',
    'moderator'
  )
end
