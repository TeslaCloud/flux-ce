--- Core of the Bolt library: the registries of roles and permissions, the permission and
-- immunity checks, bans (server side) and the parsing of human-readable ban durations.
-- Also defines the `can` global and the `role` pipeline that loads role files.
-- The checks come in two kinds: `Bolt:check_immunity` compares two players who are on the
-- server, and `Bolt:check_role_immunity` together with `Bolt:is_root_steam_id` does the same
-- for somebody who is not, going by the role that is stored for them.

if !Bolt then
  PLUGIN:set_global('Bolt')
end

local IsValid = IsValid
local isstring = isstring
local isnumber = isnumber
local pairs = pairs
local os_time = os.time
local negative_huge = -math.huge

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

  for k, v in pairs(roles) do
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
    if temp_perm.expires > os_time() then
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
  return roles[id]
end

--- Checks whether a role with the given ID is registered. The role itself is returned rather
-- than a strict boolean.
-- @param id [String role ID]
-- @return [Role the role (truthy), or nil if it does not exist]
function Bolt:group_exists(id)
  return self:find_group(id)
end

--- Compares the immunity of two roles, either of which may be missing. A missing role counts
-- as lower than every registered role, and a role without a numeric immunity always passes.
-- @param actor_role [Role the role of the player performing the action, or nil]
-- @param target_role [Role the role of whoever is acted on, or nil]
-- @param can_equal [Boolean also pass when both roles have the same immunity]
-- @return [Boolean]
local function compare_immunity(actor_role, target_role, can_equal)
  local immunity1 = !actor_role and negative_huge or actor_role.immunity
  local immunity2 = !target_role and negative_huge or target_role.immunity

  if !isnumber(immunity1) or !isnumber(immunity2) then
    return true
  end

  if immunity1 > immunity2 then
    return true
  end

  if can_equal and immunity1 == immunity2 then
    return true
  end

  return false
end

--- Checks whether a player's role has enough immunity to act on another player. A player may
-- always act on themselves, and a root player on anyone. Also passes when either player is
-- invalid or a registered role has no numeric immunity. A role ID that is not registered
-- counts as lower than every registered role.
-- @param actor [Player the player performing the action]
-- @param target [Player the player being acted on]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean true if the player may act on the target]
function Bolt:check_immunity(actor, target, can_equal)
  if !IsValid(actor) or !IsValid(target) then
    return true
  end

  if actor == target or actor:is_root() then
    return true
  end

  return compare_immunity(roles[actor:GetUserGroup()], roles[target:GetUserGroup()], can_equal)
end

--- Checks whether a player's role has enough immunity to act on the holder of a role. This
-- is `Bolt:check_immunity` for a target who is not on the server and is only known by the
-- role stored for them. An invalid player (the server console) and a root player always
-- pass, and so does everybody when a registered role has no numeric immunity. A role ID that
-- is not registered counts as lower than every registered role.
-- @param actor [Player the player performing the action]
-- @param role_id [String ID of the role of whoever is acted on]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean true if the player may act on the holder of that role]
-- @see [Bolt#check_immunity]
function Bolt:check_role_immunity(actor, role_id, can_equal)
  if !IsValid(actor) or actor:is_root() then
    return true
  end

  return compare_immunity(roles[actor:GetUserGroup()], roles[role_id], can_equal)
end

--- Checks whether a value has the form of a SteamID, such as 'STEAM_0:1:12345'.
-- @param text [Any]
-- @return [Boolean]
function Bolt:is_steam_id(text)
  return isstring(text) and text:match('^STEAM_%d:[01]:%d+$') != nil
end

--- Checks whether a SteamID is listed in the root_steamid config, which makes its owner a
-- root player when they join.
-- @param steam_id [String]
-- @return [Boolean]
function Bolt:is_root_steam_id(steam_id)
  local root_steamid = Config.get('root_steamid')

  if isstring(root_steamid) then
    return root_steamid == steam_id
  elseif istable(root_steamid) then
    return table.HasValue(root_steamid, steam_id)
  end

  return false
end

--- Looks a permission up by its exact ID in every category.
-- @param id [String permission ID]
-- @return [Map permission data, or nil if there is no such permission]
local function lookup_permission(id)
  for _, category in pairs(permissions) do
    local found = category[id]

    if found then
      return found
    end
  end
end

--- Finds a registered permission by what a person would type for it: its ID in any case,
-- or the name or an alias of the command the permission belongs to.
-- ```
-- Bolt:find_permission('spawn_props') -- the 'spawn_props' permission
-- Bolt:find_permission('plyban')      -- the permission of the Ban command
-- ```
-- @param id [String permission ID, command name or command alias]
-- @return [Map permission data (id, name, description, category, role), or nil if there is
--   no such permission]
function Bolt:find_permission(id)
  if !isstring(id) or id == '' then return end

  local found = lookup_permission(id) or lookup_permission(id:utf8lower())

  if found then
    return found
  end

  local cmd = Flux.Command:find_by_id(id)

  if cmd then
    return lookup_permission(cmd.id)
  end
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
  -- Runs the OnBanAdded hook afterwards.
  -- @warning [Internal] Use Bolt:ban to ban somebody.
  -- @param steam_id [String SteamID of the banned player]
  -- @param name [String name stored with the ban]
  -- @param unban_time [Number unix timestamp at which the ban ends]
  -- @param duration [Number ban length in seconds, 0 for a permanent ban]
  -- @param reason [String]
  -- @param admin=nil [Player the player who issued the ban; nothing is stored for the server
  --   console or for a ban made by code]
  -- @return [Ban the saved ban record]
  function Bolt:add_ban(steam_id, name, unban_time, duration, reason, admin)
    local obj = bans[steam_id] or Ban.new()
      obj.name = name
      obj.steam_id = steam_id
      obj.reason = reason
      obj.duration = duration
      obj.unban_time = to_datetime(unban_time)
      obj.admin_name = IsValid(admin) and admin:steam_name() or nil
      obj.admin_steam_id = IsValid(admin) and admin:SteamID() or nil
    self:record_ban(steam_id, obj:save())

    --- Called on the server after a ban has been created or an existing ban of the same
    -- SteamID has been replaced, when the record is in the ban cache and is being saved.
    -- @param steam_id [String SteamID that has been banned]
    -- @param ban [Ban The ban record: name, steam_id, reason, duration (seconds, 0 for a
    --   permanent ban), unban_time, admin_name and admin_steam_id]
    hook.Run('OnBanAdded', steam_id, obj)

    return obj
  end

  --- Puts a ban record into the ban cache without touching the database.
  -- @param id [String SteamID the ban belongs to]
  -- @param obj [Ban]
  function Bolt:record_ban(id, obj)
    bans[id] = obj
  end

  --- Bans a player or a SteamID and saves the ban to the database. The banned player is
  -- kicked if they are on the server, whether they were given as a player or as a SteamID,
  -- unless prevent_kick is set. The owner of the SteamID does not have to be on the server,
  -- or to have ever joined it.
  -- ```
  -- -- Ban an online player for a day.
  -- Bolt:ban(target, 60 * 60 * 24, 'Prop spam')
  -- -- Permanently ban somebody by SteamID, on behalf of an admin.
  -- Bolt:ban('STEAM_0:1:12345', 0, 'Cheating', false, actor)
  -- ```
  -- @param target [Player/String the player to ban, or a SteamID]
  -- @param duration=0 [Number ban length in seconds, 0 for a permanent ban]
  -- @param reason='N/A' [String text or language phrase]
  -- @param prevent_kick=false [Boolean do not kick the banned player]
  -- @param admin=nil [Player the player who issues the ban, stored with it]
  -- @param name=nil [String name to store with the ban of a SteamID whose owner is not on
  --   the server; the name of an earlier ban of that SteamID or else the SteamID itself by
  --   default]
  -- @return [Ban the ban record, or nil if target is neither a valid player nor a string]
  function Bolt:ban(target, duration, reason, prevent_kick, admin, name)
    if !isstring(target) and !IsValid(target) then return end

    duration = duration or 0
    reason = reason or 'N/A'

    local steam_id = target

    if isstring(target) then
      local online = self:is_steam_id(target) and player.find(target)

      if IsValid(online) then
        target = online
      else
        name = name or (bans[steam_id] and bans[steam_id].name) or steam_id
      end
    end

    if !isstring(target) then
      name = target:steam_name()
      steam_id = target:SteamID()
    end

    local obj = self:add_ban(steam_id, name, os_time() + duration, duration, reason, admin)

    if !isstring(target) and !prevent_kick then
      target:Kick(self:get_ban_message(obj, Flux.Lang:get_player_lang(target)))
    end

    return obj
  end

  --- Deletes the ban record of a SteamID from the database and from the ban cache, so that
  -- the player can connect again right away and a later ban gets a record of its own. Runs
  -- the OnBanRemoved hook if there was a ban.
  -- @param steam_id [String]
  -- @return [Boolean whether a ban record was found and deleted, Map the deleted record's
  --   column values (only when found)]
  function Bolt:remove_ban(steam_id)
    local obj = bans[steam_id]

    if obj then
      local dump = obj:dump()
      obj:destroy()

      bans[steam_id] = nil

      --- Called on the server after a ban has been lifted: by the Unban command, from the
      -- ban list of the admin panel, or because it has expired by the time its owner tried
      -- to join.
      -- @param steam_id [String SteamID that is no longer banned]
      -- @param data [Map Column values of the deleted ban record]
      hook.Run('OnBanRemoved', steam_id, dump)

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

    local number = tonumber(str)

    -- A regular number was entered?
    if number then
      return number * 60
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
