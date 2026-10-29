--- Server-side player extensions of Bolt: setting and saving the player's role and their
-- individual and temporary permissions and those of their active character, running commands
-- as the player and teleporting.

local player_meta = FindMetaTable('Player')

player_meta.engine_set_user_group = player_meta.engine_set_user_group or player_meta.SetUserGroup

--- Sets the player's role, overriding the engine method. Networks the role, sets the
-- engine's usergroup to it as well, calls on_role_taken / on_role_set on the roles involved,
-- saves the role to the database unless one of them returns a value, and runs the
-- PlayerUserGroupChanged hook. While Bolt is the admin mod that CAMI hears from, a change
-- that another addon makes this way is signaled to CAMI as coming from 'Bolt', unless it is
-- silent. Bolt's own changes go through `Bolt:set_role`, which signals them in both modes.
-- @param group='user' [String role ID]
-- @param silent=false [Boolean keep CAMI from hearing of the change]
function player_meta:SetUserGroup(group, silent)
  group = group or 'user'

  local old_id = self:GetUserGroup()
  local group_obj = Bolt:find_group(group)
  local old_group_obj = Bolt:find_group(old_id)

  self:set_nv('role', group)
  self:engine_set_user_group(group)

  if old_group_obj and group_obj and old_group_obj:on_role_taken(self, group_obj) == nil then
    if group_obj:on_role_set(self, old_group_obj) == nil then
      self:save_usergroup()
    end
  end

  --- Called on the server after a player's role has been set with `Player:SetUserGroup`.
  -- Either role is nil when its ID does not belong to a registered role.
  -- @param target [Player The player whose role has changed]
  -- @param group [Role The player's new role]
  -- @param old_group [Role The role the player had before]
  hook.Run('PlayerUserGroupChanged', self, group_obj, old_group_obj)

  if !silent and old_id != group and Bolt:is_cami_provider() then
    CAMI.SignalUserGroupChanged(self, old_id, group, 'Bolt')
  end
end

--- Writes the player's current name and role to their database record, if they have one.
-- The blank record of a bot is never saved.
function player_meta:save_usergroup()
  if self.record and !self:IsBot() then
    self.record.name = self:name()
    self.record.role = self:GetUserGroup()
    self.record:save()
  end
end

--- Replaces the player's networked table of individual permissions. Does not touch the
-- database.
-- @param perm_table [Map PERM_ values keyed by permission ID]
function player_meta:set_permissions(perm_table)
  self:set_nv('permissions', perm_table)
end

--- Sets one of the player's individual permissions: updates the Permission records on the
-- player's database record (PERM_NO destroys the record and takes it off the list) and the
-- networked table, then runs the PlayerPermissionChanged hook.
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ALLOW or PERM_NEVER, or PERM_NO to remove the permission]
function player_meta:set_permission(perm_id, value)
  local create = true

  if self.record.permissions then
    for index, perm_row in pairs(self.record.permissions) do
      if perm_row.permission_id == perm_id then
        create = false

        if value != PERM_NO then
          if value != perm_row.object then
            perm_row.object = value
          end
        else
          perm_row:destroy()
          table.remove(self.record.permissions, index)
        end

        break
      end
    end
  end

  if create and value != PERM_NO then
    local perm = Permission.new()
      perm.permission_id = perm_id
      perm.object = value
    table.insert(self.record.permissions, perm)
  end

  local perm_table = self:get_permissions()

  perm_table[perm_id] = value != PERM_NO and value or nil

  self:set_permissions(perm_table)

  --- Called on the server after a permission of a player has changed in one of the layers
  -- that `Bolt:get_permission_layer` consults: when one of the player's individual
  -- permissions has been set with `Player:set_permission`, and when the value that the
  -- player's active character sets for a permission has changed, which happens when a
  -- character is loaded, switched or dropped, when a lasting or temporary permission of the
  -- loaded character is set or removed, and when a temporary one expires. The temporary
  -- permissions of the player themselves run PlayerTempPermissionChanged instead. Use
  -- `Player:can` to learn what the player may do now.
  -- @param target [Player The player whose permission has changed]
  -- @param perm_id [String Permission ID]
  -- @param value [Number New value in the layer that has changed: PERM_ALLOW, PERM_NEVER, or
  --   PERM_NO when it was unset]
  hook.Run('PlayerPermissionChanged', self, perm_id, value)
end

--- Replaces the player's networked table of temporary permissions. Does not touch the
-- database.
-- @param perm_table [Map tables with value and expires (unix timestamp) fields, keyed by
--   permission ID]
function player_meta:set_temp_permissions(perm_table)
  self:set_nv('temp_permissions', perm_table)
end

--- Gives the player a temporary permission value that takes precedence over their regular
-- permissions until it expires. Updates the TempPermission records and the networked table.
-- Giving the value the player already has temporarily adds the duration to the time that is
-- left, up to `Bolt.max_temp_duration` from now; any other value starts counting from now.
-- The config is sent to the player again if that has changed their right to edit configs,
-- and the PlayerTempPermissionChanged hook runs.
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ value, normally PERM_ALLOW or PERM_NEVER]
-- @param duration [Number seconds until the permission expires]
function player_meta:set_temp_permission(perm_id, value, duration)
  local expires = os.time() + duration
  local create = true

  if self.record.temp_permissions then
    for _, perm_row in pairs(self.record.temp_permissions) do
      if perm_row.permission_id == perm_id then
        create = false

        if perm_row.object == value then
          expires = math.min(math.max(time_from_timestamp(perm_row.expires) or 0, os.time()) + duration,
            os.time() + Bolt.max_temp_duration)
        else
          perm_row.object = value
        end

        perm_row.expires = to_datetime(expires)

        break
      end
    end

    if create then
      local temp_perm = TempPermission.new()
        temp_perm.permission_id = perm_id
        temp_perm.object = value
        temp_perm.expires = to_datetime(expires)
      table.insert(self.record.temp_permissions, temp_perm)
    end
  end

  local perm_table = self:get_temp_permissions()

  perm_table[perm_id] = {
    value = value,
    expires = expires
  }

  self:set_temp_permissions(perm_table)

  Bolt:update_config_access(self)

  --- Called on the server after a temporary permission of a player has been given with
  -- `Player:set_temp_permission` or removed with `Bolt:delete_temp_permission`, which also
  -- happens when it expires. Use `Player:can` to learn what the player may do now.
  -- @param target [Player The player whose temporary permission has changed]
  -- @param perm_id [String Permission ID]
  -- @param value [Number The temporary value: PERM_ALLOW or PERM_NEVER, or PERM_NO when it
  --   was removed]
  hook.Run('PlayerTempPermissionChanged', self, perm_id, value)
end

--- Sets one of the permissions of the player's active character, which apply together with
-- the player's own permissions while that character is loaded, see
-- `Bolt:get_permission_layer`. Writes it to the database and runs the PlayerPermissionChanged
-- hook if the character's value has changed.
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ALLOW or PERM_NEVER, or PERM_NO to remove the permission]
-- @return [Boolean false if no character is loaded or an argument is not valid]
-- @see [Bolt#set_character_permission]
function player_meta:set_character_permission(perm_id, value)
  return Bolt:set_character_permission(Bolt:get_active_character(self), perm_id, value)
end

--- Gives the player's active character a temporary permission value that takes precedence
-- over its lasting permissions until it expires.
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ALLOW or PERM_NEVER]
-- @param duration [Number seconds until the permission expires]
-- @return [Boolean false if no character is loaded or an argument is not valid]
-- @see [Bolt#set_character_temp_permission]
function player_meta:set_character_temp_permission(perm_id, value, duration)
  return Bolt:set_character_temp_permission(Bolt:get_active_character(self), perm_id, value, duration)
end

--- Runs a command as this player, with the usual permission checks.
-- @param cmd [String command name and arguments without the leading slash, e.g. 'getup 5']
function player_meta:run_command(cmd)
  Flux.Command:interpret(self, cmd)
end

--- Moves the player to a position and unsticks them. The previous position is kept in
-- prev_pos, which the Return command uses.
-- @param pos [Vector]
function player_meta:teleport(pos)
  self.prev_pos = self:GetPos()
  self:SetPos(pos)
  self:unstuck()
end
