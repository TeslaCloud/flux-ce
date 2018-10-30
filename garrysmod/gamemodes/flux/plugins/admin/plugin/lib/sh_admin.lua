library.new('admin', fl)

local roles = fl.admin.roles or {}
fl.admin.roles = roles

local permissions = fl.admin.permissions or {}
fl.admin.permissions = permissions

local players = fl.admin.players or {}
fl.admin.players = players

local bans = fl.admin.bans or {}
fl.admin.bans = bans

function fl.admin:GetPermissions()
  return permissions
end

function fl.admin:GetRoles()
  return roles
end

function fl.admin:GetPlayers()
  return players
end

function fl.admin:get_bans()
  return bans
end

function fl.admin:create_group(id, data)
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

function fl.admin:AddPermission(id, category, data, force)
  if !id then return end

  category = category or 'general'
  data.id = id
  permissions[category] = permissions[category] or {}

  if !permissions[category][id] or force then
    permissions[category][id] = data
  end
end

function fl.admin:RegisterPermission(id, name, description, category)
  if !isstring(id) or id == '' then return end

  local data = {}
    data.id = id:to_id()
    data.description = description or 'No description provided.'
    data.category = category or 'general'
    data.name = name or id
  self:AddPermission(id, category, data, true)
end

function fl.admin:PermissionFromCommand(cmd)
  if !cmd then return end

  self:RegisterPermission(cmd.id, cmd.name, cmd.description, cmd.category)
end

function fl.admin:can(player, action, object)
  if !IsValid(player) then return true end
  if player:is_root() then return true end

  local role = roles[player:GetUserGroup()]

  if istable(role) and isfunction(role.can) then
    return role:can(player, action, object)
  end

  return false
end

function fl.admin:FindGroup(id)
  if roles[id] then
    return roles[id]
  end

  return nil
end

function fl.admin:GroupExists(id)
  return self:FindGroup(id)
end

function fl.admin:CheckImmunity(player, target, can_equal)
  if !IsValid(player) or !IsValid(target) then
    return true
  end

  local group1 = self:FindGroup(player:GetUserGroup())
  local group2 = self:FindGroup(target:GetUserGroup())

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

pipeline.register('role', function(id, file_name, pipe)
  ROLE = Role.new(id)

  util.include(file_name)

  ROLE:register() ROLE = nil
end)

function fl.admin:include_roles(directory)
  pipeline.include_folder('role', directory)
end

if SERVER then
  function can(action, object)
    if IsValid(current_player) then
      return current_player:can(action, object)
    end

    return false
  end

  -- INTERNAL
  function fl.admin:AddBan(steam_id, name, unban_time, duration, reason)
    local obj = bans[steam_id] or Ban.new()
      obj.name = name
      obj.steam_id = steam_id
      obj.reason = reason
      obj.duration = duration
      obj.unban_time = unban_time
    self:record_ban(steam_id, obj:save())
  end

  function fl.admin:record_ban(id, obj)
    bans[id] = obj
  end

  function fl.admin:ban(player, duration, reason, prevent_kick)
    if !isstring(player) and !IsValid(player) then return end

    duration = duration or 0
    reason = reason or 'N/A'

    local steam_id = player
    local name = steam_id

    if !isstring(player) and IsValid(player) then
      name = player:SteamName()
      steam_id = player:SteamID()

      if !prevent_kick then
        player:Kick('You have been banned: '..tostring(reason))
      end
    end

    self:AddBan(steam_id, name, os.time() + duration, duration, reason)
  end

  function fl.admin:remove_ban(steam_id)
    local obj = bans[steam_id]
    if obj then
      local dump = obj:dump()
      obj:destroy()

      return true, dump
    end

    return false
  end
else
  function can(action, object)
    return fl.client:can(action, object)
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

  local numTokens = {
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

  function fl.admin:InterpretBanTime(str)
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

      if !n and !tokens[v] and !numTokens[v] then continue end

      if n then
        num = n
      elseif isstring(v) then
        v = v:trim_end('s')

        local ntok = numTokens[v]

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

do
  -- Flags
  fl.admin:RegisterPermission('physgun', 'Access Physgun', 'Grants access to the physics gun.', 'flags')
  fl.admin:RegisterPermission('toolgun', 'Access Tool Gun', 'Grants access to the tool gun.', 'flags')
  fl.admin:RegisterPermission('spawn_props', 'Spawn Props', 'Grants access to spawn props.', 'flags')
  fl.admin:RegisterPermission('spawn_chairs', 'Spawn Chairs', 'Grants access to spawn chairs.', 'flags')
  fl.admin:RegisterPermission('spawn_vehicles', 'Spawn Vehicles', 'Grants access to spawn vehicles.', 'flags')
  fl.admin:RegisterPermission('spawn_entities', 'Spawn All Entities', 'Grants access to spawn any entity.', 'flags')
  fl.admin:RegisterPermission('spawn_npcs', 'Spawn NPCs', 'Grants access to spawn NPCs.', 'flags')
  fl.admin:RegisterPermission('spawn_ragdolls', 'Spawn Ragdolls', 'Grants access to spawn ragdolls.', 'flags')
  fl.admin:RegisterPermission('spawn_sweps', 'Spawn SWEPs', 'Grants access to spawn scripted weapons.', 'flags')
  fl.admin:RegisterPermission('physgun_freeze', 'Freeze Protected Entities', 'Grants access to freeze protected entities.', 'flags')
  fl.admin:RegisterPermission('physgun_pickup', 'Unlimited Physgun', 'Grants access to pick up any entity with the physics gun.', 'flags')
  fl.admin:RegisterPermission('voice', 'Voice chat access', 'Grants access to voice chat.', 'flags')

  -- General permissions
  fl.admin:RegisterPermission('context_menu', 'Access Context Menu', 'Grants access to the context menu.', 'general')
end
