--- ActiveNetwork keeps variables in sync between the server and its clients.
-- The server sets global variables with `ActiveNetwork.set_nv` and the variables of an entity
-- with `Entity:set_nv`. Every change is sent to clients over Cable, where
-- `ActiveNetwork.get_nv` and `Entity:get_nv` return the last value received. Values only
-- travel from the server to clients, and anything can be networked except for a function
-- and a table that has a function anywhere inside of it.
-- `Player:sync_nv` sends everything that is currently set to a single player, which Flux does
-- for every player once their client has created its local player.
--
-- A variable is public until a setter is given recipients, which makes it private: from then
-- on its value is only ever sent to those players, whether by a later update, by
-- `Entity:send_net_var` or by `Player:sync_nv`, until `Entity:set_nv_recipients` or
-- `ActiveNetwork.set_nv_recipients` changes that. `Player:set_private_nv` sets a variable of a
-- player that nobody but that player receives. Recipients are player entities, so a player
-- who reconnects is not a recipient any more.
-- @module [ActiveNetwork]

if ActiveNetwork then return end

mod 'ActiveNetwork'

local stored = ActiveNetwork.stored or {}
local globals = ActiveNetwork.globals or {}
local recipients = ActiveNetwork.recipients or {}
local global_recipients = ActiveNetwork.global_recipients or {}
ActiveNetwork.stored = stored
ActiveNetwork.globals = globals
ActiveNetwork.recipients = recipients
ActiveNetwork.global_recipients = global_recipients

local ent_meta = FindMetaTable('Entity')
local player_meta = FindMetaTable('Player')

--- Checks whether a value is a function or a table that has a function anywhere inside of
-- it, as a key or as a value at any depth.
-- @param value [Any value to check]
-- @param seen=nil [Map<Table, Boolean> tables that have been checked already, which keeps a
--   table that contains itself from being walked forever]
-- @return [Boolean true if there is a function in the value]
local function contains_function(value, seen)
  if isfunction(value) then return true end
  if !istable(value) then return false end

  seen = seen or {}

  if seen[value] then return false end

  seen[value] = true

  for k, v in pairs(value) do
    if contains_function(k, seen) or contains_function(v, seen) then
      return true
    end
  end

  return false
end

--- Checks whether a value cannot be networked and prints an error with a traceback if so.
-- @param key [String name of the variable the value is meant for]
-- @param value [Any value to check]
-- @return [Boolean true if the value is a function or a table that contains one]
local function is_bad_type(key, value)
  if isfunction(value) then
    error_with_traceback('Cannot network functions! ('..tostring(key)..')')
    return true
  end

  if istable(value) and contains_function(value) then
    error_with_traceback('Cannot network tables that contain functions! ('..tostring(key)..')')
    return true
  end

  return false
end

--- Turns the recipients given to a setter into a set of players. Anything that is not a
-- valid player is left out, so the set of an invalid recipient is empty.
-- @param send [Player/List<Player> recipients]
-- @return [Map<Player, Boolean> set of the valid players among the recipients]
local function to_recipient_set(send)
  local allowed = {}

  if istable(send) then
    for k, v in pairs(send) do
      if isentity(v) and v:IsValid() and v:IsPlayer() then
        allowed[v] = true
      end
    end
  elseif isentity(send) and send:IsValid() and send:IsPlayer() then
    allowed[send] = true
  end

  return allowed
end

--- Lists the players of a recipient set who are still on the server and removes the others
-- from the set.
-- @param allowed [Map<Player, Boolean> recipient set]
-- @return [List<Player> valid players of the set]
local function list_recipients(allowed)
  local targets = {}

  for target in pairs(allowed) do
    if target:IsValid() then
      table.insert(targets, target)
    else
      allowed[target] = nil
    end
  end

  return targets
end

--- Checks whether two recipient sets let the same players receive a variable.
-- @param first [Map<Player, Boolean> recipient set, nil if the variable is public]
-- @param second [Map<Player, Boolean> recipient set, nil if the variable is public]
-- @return [Boolean true if both are public or both hold the same players]
local function same_recipients(first, second)
  if first == second then return true end
  if !first or !second then return false end

  for target in pairs(first) do
    if !second[target] then return false end
  end

  for target in pairs(second) do
    if !first[target] then return false end
  end

  return true
end

--- Sends a Cable message about a variable without letting it reach a player who is not
-- among the recipients of that variable. Nothing is sent if no player is left to send to.
-- @param allowed [Map<Player, Boolean> recipient set of the variable, nil if it is public]
-- @param recv [Player/List<Player> who to send the message to; every player who may
--   receive the variable if nil]
-- @param id [String message name]
-- @param ... [Vararg values to send]
local function send_restricted(allowed, recv, id, ...)
  if !allowed then
    Cable.send(recv, id, ...)

    return
  end

  local targets

  if recv == nil then
    targets = list_recipients(allowed)
  else
    targets = {}

    for target in pairs(to_recipient_set(recv)) do
      if allowed[target] then
        table.insert(targets, target)
      end
    end
  end

  if #targets > 0 then
    Cable.send(targets, id, ...)
  end
end

--- Sends a Cable message to every player who could receive a variable before its recipients
-- have changed and cannot receive it any more. The setters use it to make these players
-- forget the value they hold.
-- @param old_allowed [Map<Player, Boolean> previous recipient set, nil if it was public]
-- @param allowed [Map<Player, Boolean> new recipient set, nil if it is public now]
-- @param id [String message name]
-- @param ... [Vararg values to send]
local function send_revoked(old_allowed, allowed, id, ...)
  if !allowed then return end

  local targets = {}

  if old_allowed then
    for k, target in ipairs(list_recipients(old_allowed)) do
      if !allowed[target] then
        table.insert(targets, target)
      end
    end
  else
    for k, target in player.Iterator() do
      if !allowed[target] then
        table.insert(targets, target)
      end
    end
  end

  if #targets > 0 then
    Cable.send(targets, id, ...)
  end
end

--- Returns the value of a networked global variable.
-- @param key [String variable name]
-- @param default=nil [Any value to return if the variable is not set]
-- @return [Any variable value, or default]
function ActiveNetwork.get_nv(key, default)
  if globals[key] != nil then
    return globals[key]
  end

  return default
end

--- Returns the players a networked global variable is sent to.
-- @param key [String variable name]
-- @return [List<Player> recipients who are still on the server, or nil if the variable is
--   public]
function ActiveNetwork.get_nv_recipients(key)
  local allowed = global_recipients[key]

  if allowed then
    return list_recipients(allowed)
  end
end

--- Changes who a networked global variable is sent to without changing its value.
-- Players who stop being recipients are told to forget the value, and the current value is
-- sent to the new recipients. The recipients can be set before the variable itself, which
-- makes sure that its first value does not reach anybody else.
-- ```
-- -- Only this player will ever receive the variable.
-- ActiveNetwork.set_nv_recipients('fl_secret', actor)
-- ActiveNetwork.set_nv('fl_secret', 42)
--
-- -- Make it public again.
-- ActiveNetwork.set_nv_recipients('fl_secret', nil)
-- ```
-- @param key [String variable name]
-- @param send=nil [Player/List<Player> the only players to send the variable to; nil makes
--   it public]
function ActiveNetwork.set_nv_recipients(key, send)
  local old_allowed = global_recipients[key]
  local allowed = nil

  if send != nil then
    allowed = to_recipient_set(send)
  end

  if same_recipients(old_allowed, allowed) then return end

  global_recipients[key] = allowed

  if globals[key] != nil then
    send_revoked(old_allowed, allowed, 'fl_netvar_global_set', key, nil)
    send_restricted(allowed, nil, 'fl_netvar_global_set', key, globals[key])
  end
end

--- Sets a networked global variable and sends it to clients.
-- Does nothing if neither the value nor the recipients have changed. Functions and tables
-- that contain functions cannot be networked.
-- @param key [String variable name]
-- @param value [Any new value, anything but a function or a table that contains one]
-- @param send=nil [Player/List<Player> makes the variable private: these players become
--   its only recipients, and everyone else is told to forget it. If nil, the value goes to
--   the current recipients of the variable, which is everyone unless it is private]
function ActiveNetwork.set_nv(key, value, send)
  if is_bad_type(key, value) then return end

  local old_value = globals[key]
  local old_allowed = global_recipients[key]
  local allowed = old_allowed

  if send != nil then
    allowed = to_recipient_set(send)
  end

  local same_audience = same_recipients(old_allowed, allowed)

  if old_value == value and same_audience then return end

  globals[key] = value

  if !same_audience then
    global_recipients[key] = allowed

    if old_value != nil then
      send_revoked(old_allowed, allowed, 'fl_netvar_global_set', key, nil)
    end
  end

  send_restricted(allowed, nil, 'fl_netvar_global_set', key, value)
end

--- Sends the current value of this entity's networked variable to a player (or players).
-- A private variable is never sent to a player who is not one of its recipients.
-- @param key [String variable name]
-- @param recv=nil [Player/List<Player> who to send the value to; if nil, everyone who may
--   receive the variable]
function ent_meta:send_net_var(key, recv)
  local allowed = recipients[self] and recipients[self][key]
  local value = stored[self] and stored[self][key]

  send_restricted(allowed, recv, 'fl_netvar_set', self:EntIndex(), key, value)
end

--- Returns the value of this entity's networked variable.
-- @param key [String variable name]
-- @param default=nil [Any value to return if the variable is not set]
-- @return [Any variable value, or default]
function ent_meta:get_nv(key, default)
  if stored[self] and stored[self][key] != nil then
    return stored[self][key]
  end

  return default
end

--- Returns the players this entity's networked variable is sent to.
-- @param key [String variable name]
-- @return [List<Player> recipients who are still on the server, or nil if the variable is
--   public]
function ent_meta:get_nv_recipients(key)
  local allowed = recipients[self] and recipients[self][key]

  if allowed then
    return list_recipients(allowed)
  end
end

--- Changes who this entity's networked variable is sent to without changing its value.
-- Players who stop being recipients are told to forget the value, and the current value is
-- sent to the new recipients. The recipients can be set before the variable itself, which
-- makes sure that its first value does not reach anybody else.
-- ```
-- -- Only admins receive the variable from now on.
-- entity:set_nv_recipients('fl_owner_steam_id', admins)
--
-- -- Make it public again.
-- entity:set_nv_recipients('fl_owner_steam_id', nil)
-- ```
-- @param key [String variable name]
-- @param send=nil [Player/List<Player> the only players to send the variable to; nil makes
--   it public]
function ent_meta:set_nv_recipients(key, send)
  local old_allowed = recipients[self] and recipients[self][key]
  local allowed = nil

  if send != nil then
    allowed = to_recipient_set(send)
  end

  if same_recipients(old_allowed, allowed) then return end

  recipients[self] = recipients[self] or {}
  recipients[self][key] = allowed

  if self:get_nv(key) != nil then
    send_revoked(old_allowed, allowed, 'fl_netvar_set', self:EntIndex(), key, nil)
    self:send_net_var(key)
  end
end

--- Flushes all of this entity's networked variables, along with their recipients, and tells
-- clients to do the same.
-- @param recv=nil [Player/List<Player> who to notify; everyone if nil]
function ent_meta:clear_net_vars(recv)
  stored[self] = nil
  recipients[self] = nil
  Cable.send(recv, 'fl_netvar_delete', self:EntIndex())
end

--- Sets this entity's networked variable and sends it to clients.
-- Does nothing if neither a non-table value nor the recipients have changed. Functions and
-- tables that contain functions cannot be networked.
-- ```
-- -- Public: sent to everyone, including the players who join later.
-- entity:set_nv('fl_locked', true)
--
-- -- Private: sent to the listed players only, and so are the later updates.
-- entity:set_nv('fl_combination', '1234', { owner, co_owner })
-- entity:set_nv('fl_combination', '4321')
-- ```
-- @param key [String variable name]
-- @param value [Any new value, anything but a function or a table that contains one]
-- @param send=nil [Player/List<Player> makes the variable private: these players become
--   its only recipients, and everyone else is told to forget it. If nil, the value goes to
--   the current recipients of the variable, which is everyone unless it is private]
function ent_meta:set_nv(key, value, send)
  if is_bad_type(key, value) then return end

  local old_value = self:get_nv(key)
  local old_allowed = recipients[self] and recipients[self][key]
  local allowed = old_allowed

  if send != nil then
    allowed = to_recipient_set(send)
  end

  local same_audience = same_recipients(old_allowed, allowed)

  if !istable(value) and old_value == value and same_audience then return end

  stored[self] = stored[self] or {}
  stored[self][key] = value

  if !same_audience then
    recipients[self] = recipients[self] or {}
    recipients[self][key] = allowed

    if old_value != nil then
      send_revoked(old_allowed, allowed, 'fl_netvar_set', self:EntIndex(), key, nil)
    end
  end

  self:send_net_var(key)
end

--- Sets a networked variable of this player that is sent to nobody but the player.
-- The same as `Entity:set_nv` with the player as the only recipient: the variable stays
-- private when it is updated later, and the client reads it with `Entity:get_nv`.
-- ```
-- actor:set_private_nv('fl_notes', notes)
-- ```
-- @param key [String variable name]
-- @param value [Any new value, anything but a function or a table that contains one]
function player_meta:set_private_nv(key, value)
  self:set_nv(key, value, self)
end

--- Sends the current networked globals and the networked variables of all entities to this
-- player, leaving out the private variables the player is not a recipient of.
function player_meta:sync_nv()
  for k, v in pairs(globals) do
    send_restricted(global_recipients[k], self, 'fl_netvar_global_set', k, v)
  end

  for k, v in pairs(stored) do
    if IsValid(k) then
      local allowed = recipients[k]
      local ent_idx = k:EntIndex()

      for k2, v2 in pairs(v) do
        send_restricted(allowed and allowed[k2], self, 'fl_netvar_set', ent_idx, k2, v2)
      end
    end
  end
end
