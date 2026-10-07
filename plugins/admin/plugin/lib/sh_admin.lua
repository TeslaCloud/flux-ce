if !Bolt then
  PLUGIN:set_global('Bolt')
end

local roles = Bolt.roles or {}
local permissions = Bolt.permissions or {}
local players = Bolt.players or {}
local bans = Bolt.bans or {}
Bolt.roles = roles
Bolt.permissions = permissions
Bolt.players = players
Bolt.bans = bans

--- Returns every registered permission, grouped by category.
-- @return [Map permission data tables keyed by category, then by permission ID]
function Bolt:get_permissions()
  return permissions
end

--- Returns every registered permission in one flat table, ignoring categories.
-- @return [Map permission data tables keyed by permission ID]
function Bolt:get_all_permissions()
  local perm_table = {}

  for k, v in pairs(permissions) do
    for k1, v1 in pairs(v) do
      perm_table[k1] = v1
    end
  end

  return perm_table
end

--- Returns every registered role.
-- @return [Map Role objects keyed by role ID]
function Bolt:get_roles()
  return roles
end

--- Returns the admin system's player table. Nothing in this plugin currently writes to it.
-- @return [Map]
function Bolt:get_players()
  return players
end

--- Returns the ban cache. It is only filled on the server, once the database is ready.
-- @return [Map Ban records keyed by SteamID]
function Bolt:get_bans()
  return bans
end

--- Stores a role under the given ID, inheriting the permissions and unset fields of the role
-- named in data.base if that role is already registered. Does nothing unless id is a string,
-- and never replaces an existing role.
-- @param id [String role ID]
-- @param data [Role role object (a plain table of role fields also works), modified in place]
-- @see [Role#register]
function Bolt:create_role(id, data)
  if !isstring(id) then return end

  data.id = id

  if data.base then
    local parent = roles[data.base]

    if parent then
      local copy = table.Copy(parent)

      table.safe_merge(copy.permissions, data.permissions)

      data.permissions = copy.permissions

      for k, v in pairs(copy) do
        if k == 'permissions' then continue end

        if !data[k] then
          data[k] = v
        end
      end
    end
  end

  if !roles[id] then
    roles[id] = data
  end
end

--- Allows a permission for a role and, recursively, for every role based on it.
-- @param role [Role]
-- @param perm_id [String permission ID]
function Bolt:allow_children(role, perm_id)
  role:allow(perm_id)

  for k, v in pairs(self:get_roles()) do
    if v.base == role.role_id then
      self:allow_children(v, perm_id)
    end
  end
end

--- Stores a permission data table under a category. A permission that already exists there
-- is kept unless force is set.
-- @param id [String permission ID; nothing happens without one]
-- @param category='general' [String category name or language phrase]
-- @param data [Map permission data (name, description, category, role); id is written into it]
-- @param force=false [Boolean replace an existing permission with the same ID]
-- @see [Bolt#register_permission]
function Bolt:add_permission(id, category, data, force)
  if !id then return end

  category = category or 'general'
  data.id = id
  permissions[category] = permissions[category] or {}

  if !permissions[category][id] or force then
    permissions[category][id] = data
  end
end

--- Registers a permission that can then be checked with actor:can(id). Permissions registered
-- before plugins finish loading (normally from a RegisterPermissions hook) are then allowed
-- for the given role and for every role based on it.
-- ```
-- function Doors:RegisterPermissions()
--   Bolt:register_permission('manage_doors', 'Doors settings access',
--     'Grants access to customize doors.', 'permission.categories.level_design', 'assistant')
-- end
-- ```
-- @param id [String permission ID; nothing happens if it is empty or not a string]
-- @param name=id [String display name]
-- @param description='No description provided.' [String]
-- @param category='general' [String category name or language phrase]
-- @param role=nil [String ID of the role that is allowed this permission by default]
function Bolt:register_permission(id, name, description, category, role)
  if !isstring(id) or id == '' then return end

  local data = {}
    data.id = id:to_id()
    data.description = description or 'No description provided.'
    data.category = category or 'general'
    data.name = name or id
    data.role = role
  self:add_permission(id, category, data, true)
end

--- Registers a permission for a command, built from the command's id, name, description,
-- category and permission (the role it is granted to) fields.
-- @param cmd [Command command table; nothing happens if it is nil]
function Bolt:permission_from_command(cmd)
  if !cmd then return end

  self:register_permission(cmd.id, cmd.name, cmd.description, cmd.category, cmd.permission)
end

--- Checks whether a player may perform an action. Unexpired temporary permissions are consulted
-- first, then the player's own permissions, then the player's role; invalid players (such as
-- the server console) and root players are always allowed.
-- @param actor [Player]
-- @param action [String permission ID; an empty string is always allowed]
-- @param object=nil [String object name the permission was allowed for, passed on to Role#can]
-- @return [Boolean whether the action is allowed (a role permission callback's return value
--   is passed through as is)]
function Bolt:can(actor, action, object)
  if !IsValid(actor) or actor:is_root() or action == '' then
    return true
  end

  local temp_perm = actor:get_temp_permission(action)

  if temp_perm then
    if time_from_timestamp(temp_perm.expires) > os.time() then
      local value = temp_perm.value

      if value == PERM_ALLOW then
        return true
      elseif value == PERM_NEVER then
        return false
      end
    end
  end

  local perm = actor:get_permission(action)

  if perm == PERM_ALLOW then
    return true
  elseif perm == PERM_NEVER then
    return false
  end

  local role = roles[actor:GetUserGroup()]

  if istable(role) and isfunction(role.can) then
    return role:can(actor, action, object)
  end

  return false
end

--- Returns the role registered under the given ID.
-- @param id [String role ID]
-- @return [Role the role, or nil if there is none]
function Bolt:find_group(id)
  if roles[id] then
    return roles[id]
  end

  return nil
end

--- Checks whether a role with the given ID is registered. The role itself is returned rather
-- than a strict boolean.
-- @param id [String role ID]
-- @return [Role the role (truthy), or nil if it does not exist]
function Bolt:group_exists(id)
  return self:find_group(id)
end

--- Checks whether a player's role has enough immunity to act on another player. Passes when
-- either player is invalid or either role has no numeric immunity.
-- @param actor [Player the player performing the action]
-- @param target [Player the player being acted on]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean true if the player may act on the target]
function Bolt:check_immunity(actor, target, can_equal)
  if !IsValid(actor) or !IsValid(target) then
    return true
  end

  local group1 = self:find_group(actor:GetUserGroup())
  local group2 = self:find_group(target:GetUserGroup())

  if !isnumber(group1.immunity) or !isnumber(group2.immunity) then
    return true
  end

  if group1.immunity > group2.immunity then
    return true
  end

  if can_equal and group1.immunity == group2.immunity then
    return true
  end

  return false
end

--- Loads every role file in a folder through the 'role' pipeline. Each file fills in the ROLE
-- global and is registered under its file name without the sh_/cl_/sv_ prefix.
-- @param directory [String folder path, as taken by Pipeline.include_folder]
-- @see [Role#register]
function Bolt:include_roles(directory)
  Pipeline.include_folder('role', directory)
end

if SERVER then
  --- Checks whether the player held in the current_player global may perform an action.
  -- Server-side variant; returns false when that global is not a valid player.
  -- @param action [String permission ID]
  -- @param object=nil [String object name the permission was allowed for]
  -- @return [Boolean]
  function can(action, object)
    if IsValid(current_player) then
      return current_player:can(action, object)
    end

    return false
  end

  --- Creates or updates the ban record for a SteamID, saves it to the database and caches it.
  -- @warning [Internal] Use Bolt:ban to ban somebody.
  -- @param steam_id [String SteamID of the banned player]
  -- @param name [String name stored with the ban]
  -- @param unban_time [Number unix timestamp at which the ban ends]
  -- @param duration [Number ban length in seconds, 0 for a permanent ban]
  -- @param reason [String]
  function Bolt:add_ban(steam_id, name, unban_time, duration, reason)
    local obj = bans[steam_id] or Ban.new()
      obj.name = name
      obj.steam_id = steam_id
      obj.reason = reason
      obj.duration = duration
      obj.unban_time = to_datetime(unban_time)
    self:record_ban(steam_id, obj:save())
  end

  --- Puts a ban record into the ban cache without touching the database.
  -- @param id [String SteamID the ban belongs to]
  -- @param obj [Ban]
  function Bolt:record_ban(id, obj)
    bans[id] = obj
  end

  --- Bans a player or a SteamID and saves the ban to the database. A player entity is also
  -- kicked, unless prevent_kick is set.
  -- ```
  -- -- Ban an online player for a day.
  -- Bolt:ban(target, 60 * 60 * 24, 'Prop spam')
  -- -- Permanently ban somebody by SteamID.
  -- Bolt:ban('STEAM_0:1:12345', 0, 'Cheating')
  -- ```
  -- @param target [Player/String the player to ban, or a SteamID]
  -- @param duration=0 [Number ban length in seconds, 0 for a permanent ban]
  -- @param reason='N/A' [String]
  -- @param prevent_kick=false [Boolean do not kick the banned player]
  function Bolt:ban(target, duration, reason, prevent_kick)
    if !isstring(target) and !IsValid(target) then return end

    duration = duration or 0
    reason = reason or 'N/A'

    local steam_id = target
    local name = steam_id

    if !isstring(target) and IsValid(target) then
      name = target:steam_name()
      steam_id = target:SteamID()

      if !prevent_kick then
        target:Kick('You have been banned: '..tostring(reason))
      end
    end

    self:add_ban(steam_id, name, os.time() + duration, duration, reason)
  end

  --- Deletes the ban record of a SteamID from the database.
  -- @param steam_id [String]
  -- @return [Boolean whether a ban record was found and deleted, Map the deleted record's
  --   column values (only when found)]
  function Bolt:remove_ban(steam_id)
    local obj = bans[steam_id]
    if obj then
      local dump = obj:dump()
      obj:destroy()

      return true, dump
    end

    return false
  end
else
  --- Checks whether the local player may perform an action. Client-side variant.
  -- @param action [String permission ID]
  -- @param object=nil [String object name the permission was allowed for]
  -- @return [Boolean]
  function can(action, object)
    return PLAYER:can(action, object)
  end
end

do
  -- Translations of words into seconds.
  local tokens = {
    second = 1,
    sec = 1,
    minute = 60,
    min = 60,
    hour = 60 * 60,
    day = 60 * 60 * 24,
    week = 60 * 60 * 24 * 7,
    month = 60 * 60 * 24 * 30,
    mon = 60 * 60 * 24 * 30,
    year = 60 * 60 * 24 * 365,
    yr = 60 * 60 * 24 * 365,
    permanently = 0,
    perma = 0,
    perm = 0,
    pb = 0,
    forever = 0,
    moment = 1
  }

  local num_tokens = {
    one = 1,
    two = 2,
    three = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
    eight = 8,
    nine = 9,
    ten = 10,
    few = 5,
    couple = 2,
    bunch = 120,
    lot = 1000000,
    dozen = 12,
    noscope = 420
  }

  --- Converts a human-readable duration into seconds. Bare numbers are taken as minutes, and
  -- words such as 'perma' or 'forever' (as well as text with no recognizable duration) give 0,
  -- which bans treat as permanent.
  -- ```
  -- Bolt:interpret_ban_time(30)                  -- 1800
  -- Bolt:interpret_ban_time('15')                -- 900
  -- Bolt:interpret_ban_time('2 hours')           -- 7200
  -- Bolt:interpret_ban_time('1 week 3 days')     -- 864000
  -- Bolt:interpret_ban_time('couple of minutes') -- 120
  -- Bolt:interpret_ban_time('perma')             -- 0
  -- ```
  -- @param str [String/Number duration text, or a number of minutes]
  -- @return [Number/Boolean duration in seconds, or false if str is neither a string nor a number]
  function Bolt:interpret_ban_time(str)
    if isnumber(str) then return str * 60 end
    if !isstring(str) then return false end

    str = str:trim_end(' ')
    str = str:trim_start(' ')
    str = str:Replace("'", '')
    str = str:lower()

    -- A regular number was entered?
    if tonumber(str) then
      return tonumber(str) * 60
    end

    str = str:Replace('-', '')

    local pieces = str:split(' ')
    local result = 0
    local token, num = '', 0

    for k, v in ipairs(pieces) do
      local n = tonumber(v)

      if isstring(v) then
        v = v:trim_end('s')
      end

      if !n and !tokens[v] and !num_tokens[v] then continue end

      if n then
        num = n
      elseif isstring(v) then
        v = v:trim_end('s')

        local ntok = num_tokens[v]

        if ntok then
          num = ntok

          continue
        end

        local tok = tokens[v]

        if tok then
          if tok == 0 then
            return 0
          else
            result = result + (tok * num)
          end
        end

        token, num = '', 0
      else
        token, num = '', 0
      end
    end

    return result
  end
end

Pipeline.register('role', function(id, file_name, pipe)
  ROLE = Role.new(id)

  require_relative(file_name)

  ROLE:register()
  ROLE = nil
end)
