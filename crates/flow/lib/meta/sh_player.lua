local player_meta = FindMetaTable('Player')

function player_meta:has_initialized()
  return self:GetDTBool(BOOL_INITIALIZED) or false
end

function player_meta:get_data()
  return self:get_nv('fl_data', {})
end

player_meta.fl_name = player_meta.fl_name or player_meta.Name

function player_meta:Name(force_true_name)
  return (!force_true_name and hook.run('GetPlayerName', self)) or self:get_nv('name', self:fl_name())
end

player_meta.name = player_meta.Name

function player_meta:steam_name()
  return self:fl_name()
end

function player_meta:SetModel(path)
  local old_model = self:GetModel()

  hook.run('PlayerModelChanged', self, path, old_model)

  if SERVER then
    Cable.send(nil, 'fl_player_model_changed', self:EntIndex(), path, old_model)
  end

  return self:flSetModel(path)
end

if CLIENT then
  function player_meta:notify(message, arguments, color)
    if istable(arguments) then
      for k, v in pairs(arguments) do
        if isstring(v) then
          arguments[k] = t(v)
        elseif isentity(v) and IsValid(v) then
          if v:IsPlayer() then
            arguments[k] = hook.run('GetPlayerName', v) or v:name()
          else
            arguments[k] = tostring(v) or v:GetClass()
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

function player_meta:set_action(id, force)
  if force or self:get_action() == 'none' then
    self:set_nv('action', id)

    return true
  end
end

function player_meta:get_action()
  return self:get_nv('action', 'none')
end

function player_meta:is_doing_action(id)
  return (self:get_action() == id)
end

function player_meta:reset_action()
  self:set_action('none', true)
end

function player_meta:do_action(id)
  local act = self:get_action()

  if isstring(id) then
    act = id
  end

  if act and act != 'none' then
    local action_table = Flux.get_action(act)

    if istable(action_table) and isfunction(action_table.callback) then
      try {
        action_table.callback, self, act
      } catch {
        function(exception)
          error_with_traceback("Player action '"..tostring(act).."' has failed to run!\n"..exception)
        end
      }
    end
  end
end

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

function player_meta:can(action, object)
  return hook.run('PlayerHasPermission', self, action, object)
end

function player_meta:is_root()
  return hook.run('PlayerIsRoot', self)
end
