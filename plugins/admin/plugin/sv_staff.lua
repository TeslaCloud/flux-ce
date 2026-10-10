--- Server side of what the admin plugin does to players who are not on the server: looking
-- up the stored user of a SteamID, checking the immunity of whoever acts on them, changing
-- their stored role, and finding the targets of the commands that also take a SteamID (Ban
-- and Demote).
-- Also holds the network receivers behind the staff page of the admin panel, which send the
-- list of everybody whose role is not `user`, connected or not, and demote a member of it.
--
-- The lookups query the `users` table directly instead of loading `User` models, so that
-- listing the staff does not load the characters and inventories of every staff member.

local staff_limit = 256
local request_interval = 0.5

Cable.check_networked_string('fl_bolt_staff')

--- Looks up the stored user of a SteamID. The query is asynchronous on most databases: the
-- callback runs once the answer has arrived, and not at all if the query fails.
-- @param steam_id [String]
-- @param callback [Function called with a table that has the id, steam_id, name and role
--   fields of the user, or with nil if nobody with that SteamID has ever joined]
function Bolt:find_user(steam_id, callback)
  local query = ActiveRecord.Database:select('users')
    query:where('steam_id', steam_id)
    query:limit(1)
    query:callback(function(results)
      local row = istable(results) and results[1]

      if !row then
        callback(nil)

        return
      end

      callback({
        id = tonumber(row.id),
        steam_id = tostring(row.steam_id),
        name = tostring(row.name or row.steam_id),
        role = row.role and tostring(row.role) or 'user'
      })
    end)
  query:execute()
end

--- Changes the role that is stored for a SteamID, which its owner gets the next time they
-- join. Use `Player:SetUserGroup` for a player who is on the server. Does not check
-- permissions or immunity.
-- @param steam_id [String]
-- @param role_id [String role ID]
-- @param callback=nil [Function called without arguments once the role has been stored]
function Bolt:set_stored_role(steam_id, role_id, callback)
  local query = ActiveRecord.Database:update('users')
    query:where('steam_id', steam_id)
    query:update('role', role_id)
    query:update('updated_at', to_datetime(os.time()))
    query:callback(function()
      if callback then
        callback()
      end
    end)
  query:execute()
end

--- Checks whether a player may act on somebody who is not on the server. The server console
-- and root players may act on anyone; nobody else may act on a SteamID from the
-- root_steamid config, or on a holder of a role whose immunity is not lower than their own.
-- @param actor [Player the player performing the action, an invalid entity for the server
--   console]
-- @param steam_id [String SteamID of whoever is acted on]
-- @param role_id='user' [String ID of the role stored for that SteamID]
-- @return [Boolean]
function Bolt:can_target_offline(actor, steam_id, role_id)
  if !IsValid(actor) or actor:is_root() then
    return true
  end

  if self:is_root_steam_id(steam_id) then
    return false
  end

  return self:check_role_immunity(actor, role_id or 'user')
end

--- Looks up the stored user of a SteamID on behalf of a player and runs the callback if the
-- player may act on them. A player who may not is told that the target has a higher
-- immunity. Nothing happens if the player has left by the time the answer arrives.
-- @param actor [Player the player performing the action, an invalid entity for the server
--   console]
-- @param steam_id [String SteamID of whoever is acted on]
-- @param callback [Function called with the user table of Bolt:find_user, or with nil if
--   nobody with that SteamID has ever joined]
function Bolt:with_offline_target(actor, steam_id, callback)
  local from_console = !IsValid(actor)

  self:find_user(steam_id, function(user)
    if !from_console and !IsValid(actor) then return end

    if !self:can_target_offline(actor, steam_id, user and user.role) then
      Flux.Player:notify(actor, 'error.command.higher_immunity', {
        target = user and user.name or steam_id
      })

      return
    end

    callback(user)
  end)
end

--- Finds whom a command argument targets, for the commands that work on players who are
-- not on the server as well. Players are found and checked for immunity the way the command
-- interpreter does it for a command with `immunity` set: by name or by one of the selectors
-- of `Flux.Command:str_to_player`. An argument that matches nobody but has the form of a
-- SteamID is handed back as such; the caller then checks immunity with
-- `Bolt:with_offline_target`. The caller of the command is notified when nothing comes of it.
-- @param actor [Player the player who runs the command, an invalid entity for the server
--   console]
-- @param argument [String player name, target selector or SteamID]
-- @param can_equal=false [Boolean let the command affect players of the same immunity]
-- @return [List<Player> the targets, or nil if there are none or one of them is immune,
--   String the SteamID if the argument is the SteamID of somebody who is not on the server]
function Bolt:find_command_targets(actor, argument, can_equal)
  local found = isstring(argument) and Flux.Command:str_to_player(actor, argument)
  local targets, listed = {}, {}

  if istable(found) then
    for k, v in ipairs(found) do
      if IsValid(v) and !listed[v] then
        listed[v] = true

        table.insert(targets, v)
      end
    end
  end

  if #targets == 0 then
    if self:is_steam_id(argument) then
      return nil, argument
    end

    Flux.Player:notify(actor, 'error.command.player_invalid', { player = tostring(argument) })

    return
  end

  if IsValid(actor) then
    for k, v in ipairs(targets) do
      --- Run by the commands that find their targets themselves (Ban and Demote), for every
      -- player they are about to affect, the same way the command interpreter runs it for a
      -- command with `immunity` set.
      -- @param actor [Player Player who runs the command]
      -- @param target [Player Player the command targets]
      -- @param can_equal [Boolean Whether a target of the same standing may be affected]
      -- @return [Boolean Return false if the target is immune to the actor]
      if hook.Run('CommandCheckImmunity', actor, v, can_equal) == false then
        actor:notify('error.command.higher_immunity', { target = get_player_name(v) })

        return
      end
    end
  end

  return targets
end

--- Sets the role of the owner of a SteamID back to `user`, whether they are on the server
-- or not, on behalf of a player. The player needs a higher immunity than the target's (root
-- players and the server console do not) and is notified when the target is immune, has
-- never joined or is a user already. A target who is on the server is notified as well.
-- Does not check permissions.
-- @param actor [Player the player who demotes, an invalid entity for the server console]
-- @param steam_id [String SteamID of the player to demote]
-- @param callback=nil [Function called with the name of the demoted player and the ID of
--   the role they had, once they have been demoted]
function Bolt:demote_steam_id(actor, steam_id, callback)
  local online = player.find(steam_id)

  if IsValid(online) then
    local old_role = online:GetUserGroup()

    if !self:check_immunity(actor, online) then
      Flux.Player:notify(actor, 'error.command.higher_immunity', { target = get_player_name(online) })

      return
    end

    if old_role == 'user' then
      Flux.Player:notify(actor, 'error.already_user', { target = get_player_name(online) })

      return
    end

    online:notify('notification.demote', { group = old_role })
    online:SetUserGroup('user')

    if callback then
      callback(online:steam_name(), old_role)
    end

    return
  end

  self:with_offline_target(actor, steam_id, function(user)
    if !user then
      Flux.Player:notify(actor, 'error.user_not_found', { steam_id = steam_id })

      return
    end

    if user.role == 'user' then
      Flux.Player:notify(actor, 'error.already_user', { target = user.name })

      return
    end

    self:set_stored_role(steam_id, 'user', function()
      local joined = player.find(steam_id)

      if IsValid(joined) and joined:GetUserGroup() != 'user' then
        joined:SetUserGroup('user')
      end

      if callback then
        callback(user.name, user.role)
      end
    end)
  end)
end

--- Sends a player the list of everybody whose role is not `user`: the stored users with such
-- a role, up to 256 of them, together with the players on the server who have one. Each
-- entry has the steam_id, name, role and online fields. Does not check permissions.
-- @param target [Player player to send the list to]
function Bolt:send_staff_list(target)
  if !IsValid(target) then return end

  local query = ActiveRecord.Database:select('users')
    query:where_not_equal('role', 'user')
    query:order('name')
    query:limit(staff_limit)
    query:callback(function(results)
      if !IsValid(target) then return end

      local members, listed = {}, {}

      if istable(results) then
        for k, v in ipairs(results) do
          local steam_id = tostring(v.steam_id)
          local member = {
            steam_id = steam_id,
            name = tostring(v.name or steam_id),
            role = tostring(v.role),
            online = false
          }

          listed[steam_id] = member

          table.insert(members, member)
        end
      end

      for k, v in player.Iterator() do
        if !v:IsBot() then
          local steam_id = v:SteamID()
          local role = v:GetUserGroup()
          local member = listed[steam_id]

          if member then
            member.name = v:steam_name()
            member.role = role
            member.online = true
          elseif role != 'user' then
            members[#members + 1] = {
              steam_id = steam_id,
              name = v:steam_name(),
              role = role,
              online = true
            }
          end
        end
      end

      local staff = {}

      for i = 1, #members do
        local member = members[i]

        if member.role != 'user' then
          staff[#staff + 1] = member
        end
      end

      Cable.send({ target }, 'fl_bolt_staff', staff)
    end)
  query:execute()
end

Cable.receive('fl_bolt_staff_request', function(actor)
  if !actor:can('manage_permissions') then return end

  local cur_time = CurTime()

  if (actor.next_staff_list_request or 0) > cur_time then return end

  actor.next_staff_list_request = cur_time + request_interval

  Bolt:send_staff_list(actor)
end)

Cable.receive('fl_bolt_demote', function(actor, steam_id)
  if !actor:can('manage_permissions') then return end
  if !Bolt:is_steam_id(steam_id) then return end

  Bolt:demote_steam_id(actor, steam_id, function(name)
    Command:notify_staff('command.demote.message', {
      player = get_player_name(actor),
      target = name
    })

    if IsValid(actor) and actor:can('manage_permissions') then
      Bolt:send_staff_list(actor)
    end
  end)
end)
