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
  and self:GetVelocity():Length2DSqr() > (Config.get('walk_speed', 100) + 20)^2 then
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
  return hook.Run('PlayerHasPermission', self, action, object)
end

--- Checks whether the player has root access, that is can do anything. The decision
-- is made by the 'PlayerIsRoot' hook.
-- @return [Boolean nil if nothing handles the hook]
function player_meta:is_root()
  return hook.Run('PlayerIsRoot', self)
end
