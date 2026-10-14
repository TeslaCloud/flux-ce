--- Server-side player extensions of the admin plugin: setting and saving the player's role
-- and their individual and temporary permissions, running commands as the player,
-- teleporting, vanishing, and keeping hidden players (vanished or observing) from being
-- networked to everyone without the 'moderate' permission.

local player_meta = FindMetaTable('Player')

--- Sets the player's role, overriding the engine method. Networks the role, calls
-- on_role_taken / on_role_set on the roles involved, saves the role to the database unless
-- one of them returns a value, and runs the PlayerUserGroupChanged hook.
-- @param group='user' [String role ID]
function player_meta:SetUserGroup(group)
  group = group or 'user'

  local group_obj = Bolt:find_group(group)
  local old_group_obj = Bolt:find_group(self:GetUserGroup())

  self:set_nv('role', group)

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
end

--- Writes the player's current name and role to their database record, if they have one.
function player_meta:save_usergroup()
  if self.record then
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
    for k, v in pairs(self.record.permissions) do
      if v.permission_id == perm_id then
        create = false

        if value != PERM_NO then
          if value != v.object then
            v.object = value
          end
        else
          v:destroy()
          table.remove(self.record.permissions, k)
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

  --- Called on the server after one of a player's individual permissions has been set with
  -- `Player:set_permission`. Temporary permissions do not run this hook.
  -- @param target [Player The player whose permission has changed]
  -- @param perm_id [String Permission ID]
  -- @param value [Number New value: PERM_ALLOW, PERM_NEVER, or PERM_NO when it was unset]
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
-- left; any other value starts counting from now. The config is sent to the player again if
-- that has changed their right to edit configs.
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ value, normally PERM_ALLOW or PERM_NEVER]
-- @param duration [Number seconds until the permission expires]
function player_meta:set_temp_permission(perm_id, value, duration)
  local expires = os.time() + duration
  local create = true

  if self.record.temp_permissions then
    for k, v in pairs(self.record.temp_permissions) do
      if v.permission_id == perm_id then
        create = false

        if v.object == value then
          expires = math.max(time_from_timestamp(v.expires) or 0, os.time()) + duration
        else
          v.object = value
        end

        v.expires = to_datetime(expires)

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
  self:update_hidden_players()
end

--- Runs a command as this player, with the usual permission checks.
-- @param cmd [String command name and arguments without the leading slash, e.g. 'getup 5']
function player_meta:run_command(cmd)
  return Flux.Command:interpret(self, cmd)
end

--- Moves the player to a position and unsticks them. The previous position is kept in
-- prev_pos, which the Return command uses.
-- @param pos [Vector]
function player_meta:teleport(pos)
  self.prev_pos = self:GetPos()
  self:SetPos(pos)
  self:unstuck()
end

--- Checks whether the player is hidden from other players: vanished, or in observer mode.
-- @return [Boolean]
function player_meta:is_hidden()
  return self.is_vanished == true or self:get_nv('observer') == true
end

--- Starts or stops networking the player, together with everything attached to them such as
-- their weapons, to one other player, going by whether the player is hidden and whether the
-- receiver has the 'moderate' permission, which lets them see hidden players.
-- @param receiver [Player]
function player_meta:update_transmit(receiver)
  if !IsValid(receiver) or receiver == self then return end

  local should_prevent = self:is_hidden() and !receiver:can('moderate')

  self:prevent_transmit(receiver, should_prevent)

  for k, v in ipairs(self:GetWeapons()) do
    v:prevent_transmit(receiver, should_prevent)
  end
end

--- Applies whether the player is hidden to the networking of the player to everyone else and
-- sets their own 'transmission_prevented' net var. Called whenever the player is hidden or
-- shown, and again whenever something new is attached to a hidden player.
function player_meta:update_visibility()
  self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

  for k, v in player.Iterator() do
    self:update_transmit(v)
  end

  self:set_nv('transmission_prevented', self:is_hidden(), self)
end

--- Applies which of the hidden players this player may see to the networking of all of them.
-- Called when the player joins and whenever their permissions change.
function player_meta:update_hidden_players()
  for k, v in player.Iterator() do
    v:update_transmit(self)
  end
end

--- Makes a vanished player invisible and not solid. Also used to hide them again after they
-- have respawned, which makes them visible.
-- @param target [Player]
local function hide_body(target)
  target:DrawWorldModel(false)
  target:DrawShadow(false)
  target:SetNoDraw(true)
  target:SetNotSolid(true)
  target:SetColor(Color(0, 0, 0, 0))
end

--- Makes a vanished player invisible and not solid again after they have respawned, unless
-- they are in observer mode, which hides them in its own way. Server-side only.
function player_meta:hide_vanished_body()
  if self.is_vanished and !self:get_nv('observer') then
    hide_body(self)
  end
end

--- Hides the player from everyone without the 'moderate' permission, or shows them again.
-- A player in observer mode keeps the look the Observer plugin gave them; anyone else is
-- made invisible and not solid, and gets their previous color back when they reappear. The
-- weapon is only drawn again when the player carries nothing, since the engine drops the
-- carried object as soon as the weapon is drawn and draws the weapon by itself once the
-- object is let go of. A player who leaves vanish while in observer mode stays hidden as an
-- observer. Sets the player's is_vanished field and notifies nobody.
-- @param should_vanish [Boolean true to hide the player, false to show them again]
function player_meta:set_vanished(should_vanish)
  if !self:get_nv('observer') then
    if should_vanish then
      self.old_color = self:GetColor()

      hide_body(self)
    else
      if !IsValid(self.holding_object) then
        self:DrawWorldModel(true)
      end

      self:DrawShadow(true)
      self:SetNoDraw(false)
      self:SetNotSolid(false)
      self:SetColor(self.old_color or color_white)
    end
  end

  self.is_vanished = should_vanish

  self:update_visibility()
end
