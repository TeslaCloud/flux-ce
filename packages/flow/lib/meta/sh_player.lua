--- Extensions of the `Player` metatable that the gamemode package adds to every player.
-- Names go through the `GetPlayerName` hook so that plugins can replace them,
-- `Player:SetModel` announces model changes with the `PlayerModelChanged` hook, and the
-- permission checks (`Player:can`, `Player:is_root`) are answered by hooks that an admin
-- plugin implements. The rest covers the initialization state, the networked data table,
-- client-side notifications, freezing, and actions: every player has one current action,
-- registered with `Flux.register_action`, which the gamemode runs on each `PlayerThink`.
-- The server-only half adds saving and restoring of the player's database record.

local player_meta = FindMetaTable('Player')

--- Checks whether the player has finished loading in and has been initialized by Flux.
-- @return [Boolean]
function player_meta:has_initialized()
  return self:GetDTBool(BOOL_INITIALIZED) or false
end

--- Returns the networked data table of the player.
-- @return [Map]
function player_meta:get_data()
  return self:get_nv('fl_data', {})
end

player_meta.fl_name = player_meta.fl_name or player_meta.Name

--- Returns the name of the player. Overrides the engine function, so that plugins can provide
-- their own names (e.g. character names) with the 'GetPlayerName' hook. Also available
-- as Player#name.
-- @param force_true_name=false [Boolean ignore the 'GetPlayerName' hook]
-- @return [String]
function player_meta:Name(force_true_name)
  --- Lets plugins replace the name a player is shown under, for example with the name of
  -- their character. Called on both realms whenever the name of a player is requested
  -- with `Player:Name` (unless the true name is forced) or `Entity:get_name`, and on the
  -- client for players passed as arguments of a notification. Inside a handler, use
  -- `target:name(true)` to get the unmodified name: `target:name()` would run the hook
  -- again.
  -- @param target [Player The player whose name is requested]
  -- @return [String Name to show; when nothing is returned, the player's `name` networked
  --   variable or else their Steam name is used]
  return (!force_true_name and hook.Run('GetPlayerName', self)) or self:get_nv('name', self:fl_name())
end

player_meta.name = player_meta.Name

--- Returns the Steam name of the player.
-- @return [String]
function player_meta:steam_name()
  return self:fl_name()
end

--- Sets the model of the player. Overrides the engine function to run the 'PlayerModelChanged'
-- hook and, on the server, to tell the clients about the change.
-- @param path [String path to the model]
function player_meta:SetModel(path)
  local old_model = self:GetModel()

  --- Called when the model of a player changes, right before the new model is applied.
  -- `Player:SetModel` runs it on the realm it is called on, and the server also announces
  -- the change to every client, which runs the hook once the player's entity is valid
  -- there. In addition, the client runs it for every player when the map's entities have
  -- been created, with the current model as both the new and the old one. The gamemode's
  -- handler assigns the animation table of the new model to the player.
  -- @param target [Player The player whose model changes]
  -- @param new_model [String Path of the new model]
  -- @param old_model [String Path of the previous model]
  hook.Run('PlayerModelChanged', self, path, old_model)

  if SERVER then
    Cable.send(nil, 'fl_player_model_changed', self:EntIndex(), path, old_model)
  end

  return self:flSetModel(path)
end

--- Returns the classes of all of the weapons the player has.
-- @return [List<String> weapon classes]
function player_meta:get_weapons_list()
  local weapons_table = {}

  for k, v in pairs(self:GetWeapons()) do
    table.insert(weapons_table, v:GetClass())
  end

  return weapons_table
end

if CLIENT then
  --- Displays a notification to the local player, both as a popup and in the chat.
  -- Clientside variant.
  -- @param message [String text or language phrase]
  -- @param arguments=nil [Map values to substitute into the phrase; strings are translated,
  --   entities are replaced with their names]
  -- @param color=color_white [Color]
  function player_meta:notify(message, arguments, color)
    if istable(arguments) then
      for k, v in pairs(arguments) do
        if isstring(v) then
          arguments[k] = t(v)
        elseif isentity(v) and IsValid(v) then
          if v:IsPlayer() then
            arguments[k] = hook.Run('GetPlayerName', v) or v:name()
          else
            --- Lets plugins give a display name to an entity that is not a player. Called on
            -- both realms by `Entity:get_name`, and on the client for entities passed as
            -- arguments of a notification.
            -- @param entity [Entity The entity whose name is requested]
            -- @return [String Name to show; when nothing is returned, the string
            --   representation of the entity is used]
            arguments[k] = hook.Run('GetEntityName', v) or tostring(v) or v:GetClass()
          end
        end
      end
    end

    color = color and Color(color.r, color.g, color.b) or color_white
    message = t(message, arguments)

    Flux.Notification:add(message, 8, color:darken(50))

    chat.AddText(color, message)
  end
end

--- Stops the player from moving by setting their move type to MOVETYPE_NONE.
-- @see [Entity#freeze]
function player_meta:freeze_move()
  self:SetMoveType(MOVETYPE_NONE)
end

--- Lets the player move again by setting their move type to MOVETYPE_WALK.
-- @see [Entity#unfreeze]
function player_meta:unfreeze_move()
  self:SetMoveType(MOVETYPE_WALK)
end

--- Stops the player from firing their active weapon for an hour and freezes the weapon.
-- @see [Entity#freeze]
function player_meta:freeze_gun()
  local weapon = self:GetActiveWeapon()
  local cur_time = CurTime()

  if IsValid(weapon) then
    weapon:SetNextPrimaryFire(cur_time + 3600)
    weapon:SetNextSecondaryFire(cur_time + 3600)

    weapon:freeze()
  end
end

--- Lets the player fire their active weapon again and unfreezes the weapon.
-- @see [Entity#unfreeze]
function player_meta:unfreeze_gun()
  local weapon = self:GetActiveWeapon()
  local cur_time = CurTime()

  if IsValid(weapon) then
    weapon:SetNextPrimaryFire(cur_time + 0.1)
    weapon:SetNextSecondaryFire(cur_time + 0.1)

    weapon:unfreeze()
  end
end

--[[
  Actions system
--]]

--- Sets the action the player is currently doing. Does nothing if the player is already
-- doing something, unless forced.
-- @param id [String action ID]
-- @param force=false [Boolean replace the current action]
-- @return [Boolean true if the action was set, nil otherwise]
function player_meta:set_action(id, force)
  if force or self:get_action() == 'none' then
    self:set_nv('action', id)

    return true
  end
end

--- Returns the action the player is currently doing.
-- @return [String action ID, 'none' if the player is not doing anything]
function player_meta:get_action()
  return self:get_nv('action', 'none')
end

--- Checks whether the player is currently doing the specified action.
-- @param id [String action ID]
-- @return [Boolean]
function player_meta:is_doing_action(id)
  return (self:get_action() == id)
end

--- Resets the action of the player to 'none'.
function player_meta:reset_action()
  self:set_action('none', true)
end

--- Runs the callback of an action registered with Flux.register_action.
-- @param id=nil [String action ID, the current action of the player if omitted]
function player_meta:do_action(id)
  local act = self:get_action()

  if isstring(id) then
    act = id
  end

  if act and act != 'none' then
    local action_table = Flux.get_action(act)

    if istable(action_table) and isfunction(action_table.callback) then
      local success, result = pcall(action_table.callback, self, act)

      if !success then
        error_with_traceback("Player action '"..tostring(act).."' has failed to run!\n"..result)
      end
    end
  end
end

--- Checks whether the player is alive and moving on foot faster than the walk speed.
-- @return [Boolean]
function player_meta:running()
  if self:Alive() and !self:Crouching() and self:GetMoveType() == MOVETYPE_WALK
  and self:GetVelocity():Length2DSqr() > (Config.get('walk_speed', 100) + 20) ^ 2 then
    return true
  end

  return false
end

--[[
  Admin system

  Hook your admin mods to these functions, they're universally used
  throughout the Flux framework.
--]]

--- Checks whether the player has a permission. The decision is made by the
-- 'PlayerHasPermission' hook, which admin plugins implement.
-- ```
-- if !actor:can('spawn_props') then
--   return false
-- end
-- ```
-- @param action [String permission ID]
-- @param object=nil [Any object the permission is checked against, passed to the hook]
-- @return [Boolean nil if nothing handles the hook]
function player_meta:can(action, object)
  --- Decides whether a player has a permission. Called on both realms by `Player:can`,
  -- which returns whatever the hook returns. Flux has no handler of its own: an admin
  -- plugin is expected to implement it.
  -- @param actor [Player The player being checked]
  -- @param action [String Permission ID, such as 'spawn_props']
  -- @param object [Any Object the permission is checked against; nil if none was given]
  -- @return [Boolean Whether the player has the permission]
  return hook.Run('PlayerHasPermission', self, action, object)
end

--- Checks whether the player has root access, that is can do anything. The decision
-- is made by the 'PlayerIsRoot' hook.
-- @return [Boolean nil if nothing handles the hook]
function player_meta:is_root()
  --- Decides whether a player has root access, that is can do anything. Called on both
  -- realms by `Player:is_root`, which returns whatever the hook returns. Flux has no
  -- handler of its own: an admin plugin is expected to implement it.
  -- @param target [Player The player being checked]
  -- @return [Boolean Whether the player is root]
  return hook.Run('PlayerIsRoot', self)
end
