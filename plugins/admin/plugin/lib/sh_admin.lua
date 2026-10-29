--- Core of the Bolt library: the registries of roles and permissions, the permission and
-- immunity checks, bans (server side) and the parsing of human-readable ban durations.
-- Also defines the `can` global and the `role` pipeline that loads role files.
-- Permissions are decided in layers, see `Bolt:get_permission_layer`: the player's and the
-- active character's own permissions, where a denial wins, then the role.
-- The immunity checks come in two kinds: `Bolt:check_immunity` compares two players who are on
-- the server, and `Bolt:check_role_immunity` together with `Bolt:is_root_steam_id` does the
-- same for somebody who is not, going by the role that is stored for them.

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

  for _, category in pairs(permissions) do
    for id, permission in pairs(category) do
      perm_table[id] = permission
    end
  end

  return perm_table
end

--- Returns every registered role.
-- @return [Map Role objects keyed by role ID]
function Bolt:get_roles()
  return roles
end

--- Returns the admin system's player table. Nothing in this plugin writes to it.
-- @return [Map]
function Bolt:get_players()
  return players
end

--- Returns the ban cache. It is only filled on the server, once the database is ready.
-- @return [Map Ban records keyed by SteamID]
function Bolt:get_bans()
  return bans
end

--- Builds the own_permissions table of a role given as a plain table, which counts every entry
-- it has as decided by the role itself.
-- @param perms [Map permission entries keyed by object name, then by action]
-- @return [Map true keyed by object name, then by action]
local function own_entries(perms)
  local own = {}

  for object, actions in pairs(perms) do
    local entries = {}

    for action in pairs(actions) do
      entries[action] = true
    end

    own[object] = entries
  end

  return own
end

--- Stores a role under the given ID, inheriting the permissions and unset fields of the role
-- named in data.base if that role is already registered. Roles registered earlier that are
-- based on the new role get its permissions too, except for the actions they set themselves.
-- A role file whose ID is already registered adds its permissions to that role instead: the
-- allowed and denied actions of data, with their callbacks, replace what the registered role
-- had for the same actions and count as its own, `allow_anything` carries over, and the
-- entries are copied into every role based on it, recursively, except where a role decided
-- the same action itself. The other fields of data are ignored then, and an existing role is
-- never replaced. Does nothing unless id is a string.
-- ```
-- -- A schema plugin's roles/sh_user.lua: lets every player run the plugin's Report command.
-- function ROLE:define_permissions()
--   can 'report'
-- end
-- ```
-- @param id [String role ID]
-- @param data [Role role object (a plain table of role fields also works), modified in place]
-- @see [Role#register]
function Bolt:create_role(id, data)
  if !isstring(id) then return end

  local existing = roles[id]

  if existing then
    if data.can_anything then
      existing.can_anything = true
    end

    self:merge_permissions(existing, data.permissions or {}, true)

    return
  end

  data.id = id
  data.permissions = data.permissions or {}
  data.own_permissions = data.own_permissions or own_entries(data.permissions)

  if data.base then
    local parent = roles[data.base]

    if parent then
      local copy = table.Copy(parent)

      table.safe_merge(copy.permissions, data.permissions)

      data.permissions = copy.permissions

      for key, value in pairs(copy) do
        if key == 'permissions' or key == 'own_permissions' then continue end

        if !data[key] then
          data[key] = value
        end
      end
    end
  end

  roles[id] = data

  for _, child_role in pairs(roles) do
    if child_role.base == id and child_role != data then
      self:merge_permissions(child_role, data.permissions)
    end
  end
end

--- Copies permission entries (allowed or denied actions, with their callbacks) into a role
-- and, through it, into every registered role based on it. An entry is skipped for a role
-- whose own role files decided the same action (see `Role:set_own`), and is then not passed
-- on to the roles based on that role either, since they take after it.
-- @param role [Role]
-- @param perms [Map permission entries (allowed, callback) keyed by object name, then by
--   action, as in Role#get_permissions]
-- @param as_own=false [Boolean take the entries as decided by the role itself: they replace
--   what it had for the same actions and are recorded in its own_permissions]
function Bolt:merge_permissions(role, perms, as_own)
  role.permissions = role.permissions or {}
  role.own_permissions = role.own_permissions or own_entries(role.permissions)

  local applied = {}

  for object, actions in pairs(perms) do
    local target = role.permissions[object] or {}
    local own = role.own_permissions[object] or {}
    local copied = {}

    for action, entry in pairs(actions) do
      if as_own or !own[action] then
        target[action] = entry
        copied[action] = entry
      end

      if as_own then
        own[action] = true
      end
    end

    role.permissions[object] = target
    role.own_permissions[object] = own
    applied[object] = copied
  end

  local role_id = role.role_id or role.id

  for _, child_role in pairs(roles) do
    if child_role.base == role_id and child_role != role then
      self:merge_permissions(child_role, applied)
    end
  end
end

local function allow_command_role(cmd)
  local role_id = cmd.permission

  if isstring(role_id) and cmd:has_own_permission() then
    local role = roles[role_id]

    if role then
      Bolt:merge_permissions(role, { anything = { [cmd:get_permission()] = { allowed = true } } })
    else
      ErrorNoHalt("The '"..cmd:get_full_id().."' command names the '"..role_id.."' role, which does not exist!\n")
    end
  end

  for _, subcommand in ipairs(cmd:get_subcommands()) do
    allow_command_role(subcommand)
  end
end

--- Allows every command that names a role in its `permission` field to that role and to the
-- roles based on it, except where a role file decided the command itself: a `cannot` for
-- the command in a role file keeps it from that role and the roles based on it. The same goes
-- for a subcommand with a permission of its own (`permission_id`), which is allowed under
-- that permission; the `permission` field of a subcommand without one is ignored. A command
-- whose role is not registered is reported in the console and stays unallowed.
-- @see [Bolt#merge_permissions]
function Bolt:allow_command_roles()
  for _, cmd in pairs(Flux.Command.stored) do
    allow_command_role(cmd)
  end
end

--- Stores a permission data table under a category. A permission that already exists there
-- is kept unless force is set.
-- @param id [String permission ID; nothing happens without one]
-- @param category='general' [String category name or language phrase]
-- @param data [Map permission data (name, description, category); id is written into it]
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

--- Registers a permission that can then be checked with actor:can(id), and that the
-- permission editor lists under its category. Registering a permission does not allow it for
-- anybody: the role files allow it to roles with `can`, and roles based on those inherit it.
-- ```
-- function Doors:RegisterPermissions()
--   Bolt:register_permission('manage_doors', 'Doors settings access',
--     'Grants access to customize doors.', 'permission.categories.level_design')
-- end
--
-- -- roles/sh_assistant.lua
-- function ROLE:define_permissions()
--   can 'manage_doors'
-- end
-- ```
-- @param id [String permission ID; nothing happens if it is empty or not a string]
-- @param name=id [String display name]
-- @param description='No description provided.' [String]
-- @param category='general' [String category name or language phrase]
function Bolt:register_permission(id, name, description, category)
  if !isstring(id) or id == '' then return end

  local data = {}
    data.id = id:to_id()
    data.description = description or 'No description provided.'
    data.category = category or 'general'
    data.name = name or id
  self:add_permission(id, category, data, true)
end

local function register_permission_ids(cmd, category)
  local perm_id = cmd.permission_id

  category = cmd.category or category

  if isstring(perm_id) and perm_id != '' and !Bolt:get_all_permissions()[perm_id] then
    Bolt:add_permission(perm_id, category, {
      name = cmd:get_full_name(),
      description = cmd.description or 'No description provided.',
      category = category or 'general'
    })
  end

  for _, subcommand in ipairs(cmd:get_subcommands()) do
    register_permission_ids(subcommand, category)
  end
end

--- Registers the permissions of a command: one named after the command's ID, or after its
-- `permission_id` if it sets one, built from the command's name, description and category,
-- and one for every subcommand that names its own `permission_id`, built from the subcommand's
-- full name and description. A `permission_id` that is registered already is kept as it is.
-- Role files allow these permissions under their IDs.
-- @param cmd [Command command table; nothing happens if it is nil]
function Bolt:permission_from_command(cmd)
  if !cmd then return end

  if !cmd.permission_id then
    self:register_permission(cmd.id, cmd.name, cmd.description, cmd.category)
  end

  register_permission_ids(cmd)
end

--- Reads the value that one layer of a player's own permissions (the player's, or their
-- active character's) sets for an action: an unexpired temporary value comes first, then the
-- lasting one. Only `PERM_ALLOW` and `PERM_NEVER` decide anything; `PERM_NO`, a missing value
-- and an expired temporary value leave the action to the next layer.
-- @param temp_entry [Map temporary permission with value and expires (unix timestamp) fields,
--   or nil]
-- @param value [Number lasting PERM_ value, or nil]
-- @param now=os.time() [Number unix timestamp to compare the expiry with]
-- @return [Number PERM_ALLOW or PERM_NEVER, nil if the layer does not decide the action,
--   Boolean true if the temporary value decides it]
function Bolt:get_layer_value(temp_entry, value, now)
  if istable(temp_entry) and (tonumber(temp_entry.expires) or 0) > (now or os_time()) then
    local temp_value = temp_entry.value

    if temp_value == PERM_ALLOW or temp_value == PERM_NEVER then
      return temp_value, true
    end
  end

  if value == PERM_ALLOW or value == PERM_NEVER then
    return value, false
  end
end

--- Decides whether a player may perform an action and names the layer that decides it.
-- A player's own permissions come in two layers, those of the player (`'user'`) and those of
-- the active character (`'character'`), and in each of them an unexpired temporary value
-- comes before the lasting one (`'user_temporary'`, `'character_temporary'`). They are
-- consulted in this order:
--
-- 1. `'root'`: root players are always allowed.
-- 2. If either layer says `PERM_NEVER`, the action is denied, the character's denial being
--    named first. A character cannot undo what the player is denied.
-- 3. Otherwise, if either layer says `PERM_ALLOW`, the action is allowed, the character's
--    permission being named first. A character can be allowed what the role does not allow.
-- 4. `'role'`: the player's role, together with the roles it is based on.
--
-- The character layer only applies while the character is loaded. Invalid players (such as
-- the server console) and an empty action are always allowed, with no layer. Immunity is not
-- a permission: `Bolt:check_immunity` only compares roles, so character permissions never
-- change whom a player may act on.
-- ```
-- local allowed, layer = Bolt:get_permission_layer(target, 'physgun')
-- -- true, 'character' when the active character was granted the physgun
-- ```
-- @param actor [Player]
-- @param action [String permission ID]
-- @param object=nil [String object name the permission was allowed for, passed on to Role#can]
-- @return [Boolean whether the action is allowed (a role permission callback's return value
--   is passed through as is), String the deciding layer, nil when no layer applies]
function Bolt:get_permission_layer(actor, action, object)
  if !IsValid(actor) or action == '' then
    return true
  end

  if actor:is_root() then
    return true, 'root'
  end

  local now = os_time()
  local char_value, char_temporary = self:get_layer_value(actor:get_character_temp_permission(action),
    actor:get_character_permission(action), now)
  local user_value, user_temporary = self:get_layer_value(actor:get_temp_permission(action),
    actor:get_permission(action), now)
  local char_layer = char_temporary ? 'character_temporary' : 'character'
  local user_layer = user_temporary ? 'user_temporary' : 'user'

  if char_value == PERM_NEVER then
    return false, char_layer
  elseif user_value == PERM_NEVER then
    return false, user_layer
  elseif char_value == PERM_ALLOW then
    return true, char_layer
  elseif user_value == PERM_ALLOW then
    return true, user_layer
  end

  local role = roles[actor:GetUserGroup()]

  if istable(role) and isfunction(role.can) then
    return role:can(actor, action, object), 'role'
  end

  return false, 'role'
end

--- Checks whether a player may perform an action. This is what `Player:can` answers with, on
-- both realms; see `Bolt:get_permission_layer` for how it is decided.
-- @param actor [Player]
-- @param action [String permission ID; an empty string is always allowed]
-- @param object=nil [String object name the permission was allowed for, passed on to Role#can]
-- @return [Boolean whether the action is allowed (a role permission callback's return value is
--   passed through as is)]
function Bolt:can(actor, action, object)
  return (self:get_permission_layer(actor, action, object))
end

--- The longest duration of a temporary character permission, in seconds: ten years.
Bolt.max_temp_duration = 60 * 60 * 24 * 365 * 10

--- Checks whether a value can be the duration of a temporary character permission: a number
-- of seconds above 0 and at most `Bolt.max_temp_duration`.
-- @param duration [Any]
-- @return [Boolean]
function Bolt:is_temp_duration(duration)
  return isnumber(duration) and duration > 0 and duration <= self.max_temp_duration
end

--- Returns the role registered under the given ID.
-- @param id [String role ID]
-- @return [Role the role, or nil if there is none]
function Bolt:find_group(id)
  return roles[id]
end

--- Finds a role by what a person would type for it: its ID or its name, matched exactly but
-- in any case.
-- ```
-- Bolt:find_role('Admin')         -- the 'admin' role
-- Bolt:find_role('Administrator') -- the 'admin' role, by its name
-- ```
-- @param text [String role ID or role name]
-- @return [Role the role, or nil if no role has this ID or name]
function Bolt:find_role(text)
  if !isstring(text) or text == '' then return end

  if roles[text] then return roles[text] end

  local lower = text:utf8lower()

  for id, role in pairs(roles) do
    if id:utf8lower() == lower then
      return role
    end
  end

  for _, role in pairs(roles) do
    if isstring(role.name) and role.name:utf8lower() == lower then
      return role
    end
  end
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

local function lookup_permission(id)
  for _, category in pairs(permissions) do
    local found = category[id]

    if found then
      return found
    end
  end

  local lower = id:utf8lower()

  for _, category in pairs(permissions) do
    for perm_id, perm in pairs(category) do
      if perm_id:utf8lower() == lower then
        return perm
      end
    end
  end
end

--- Finds a registered permission by what a person would type for it: its ID, or the ID or
-- an alias of the command the permission belongs to, matched exactly but in any case.
-- ```
-- Bolt:find_permission('spawn_props') -- the 'spawn_props' permission
-- Bolt:find_permission('perms')       -- the permission of the Permission command
-- ```
-- @param id [String permission ID, command ID or command alias]
-- @return [Map permission data (id, name, description, category), or nil if there is no such
--   permission]
function Bolt:find_permission(id)
  if !isstring(id) or id == '' then return end

  local found = lookup_permission(id)

  if found then
    return found
  end

  local cmd = Flux.Command:find_by_id(id)

  if cmd then
    return lookup_permission(cmd:get_permission())
  end
end

--- Loads every role file in a folder through the 'role' pipeline. Each file fills in the ROLE
-- global and is registered under its file name without the sh_/cl_/sv_ prefix. A role file
-- whose ID is already registered adds its permissions to that role, see `Bolt:create_role`.
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
      local online = player.is_steam_id(target) and player.find(target)

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

      --- Called on the server after a ban has been lifted: by the `ban remove` command, from
      -- the ban list of the admin panel, or because it has expired by the time its owner
      -- tried to join.
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
    lot = 1_000_000,
    dozen = 12,
    noscope = 420
  }

  --- Checks whether a duration is one of the words that stand for a permanent one, such as
  -- 'perma', 'permanently' or 'forever'.
  -- @param str [String duration text]
  -- @return [Boolean]
  function Bolt:is_permanent_time(str)
    if !isstring(str) then return false end

    local word = str:Trim():lower()

    return tokens[word] == 0 or tokens[word:trim_end('s')] == 0
  end

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

    if number then
      return number * 60
    end

    str = str:Replace('-', '')

    local result = 0
    local num = 0

    for _, piece in ipairs(str:split(' ')) do
      local n = tonumber(piece)

      piece = piece:trim_end('s')

      if n then
        num = n
      elseif num_tokens[piece] then
        num = num_tokens[piece]
      elseif tokens[piece] then
        local tok = tokens[piece]

        if tok == 0 then
          return 0
        end

        result += tok * num
        num = 0
      end
    end

    return result
  end
end

Pipeline.register('role', function(id, file_name, _pipe)
  ROLE = Role.new(id)

  require_relative(file_name)

  ROLE:register()
  ROLE = nil
end)
