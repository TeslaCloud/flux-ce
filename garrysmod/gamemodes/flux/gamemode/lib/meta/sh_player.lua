local player_meta = FindMetaTable('Player')

function player_meta:HasInitialized()
  return self:GetDTBool(BOOL_INITIALIZED) or false
end

function player_meta:get_data()
  return self:get_nv('fl_data', {})
end

player_meta.flName = player_meta.flName or player_meta.Name

function player_meta:Name(bForceTrueName)
  return (!bForceTrueName and hook.run('GetPlayerName', self)) or self:get_nv('name', self:flName())
end

function player_meta:SteamName()
  return self:flName()
end

function player_meta:SetModel(sPath)
  local oldModel = self:GetModel()

  hook.run('PlayerModelChanged', self, sPath, oldModel)

  if SERVER then
    netstream.Start(nil, 'PlayerModelChanged', self:EntIndex(), sPath, oldModel)
  end

  return self:flSetModel(sPath)
end

--[[
  Actions system
--]]

function player_meta:SetAction(id, bForce)
  if bForce or self:GetAction() == 'none' then
    self:set_nv('action', id)

    return true
  end
end

function player_meta:GetAction()
  return self:get_nv('action', 'none')
end

function player_meta:IsDoingAction(id)
  return (self:GetAction() == id)
end

function player_meta:ResetAction()
  self:SetAction('none', true)
end

function player_meta:DoAction(id)
  local act = self:GetAction()

  if isstring(id) then
    act = id
  end

  if act and act != 'none' then
    local actionTable = fl.get_action(act)

    if istable(actionTable) and isfunction(actionTable.callback) then
      try {
        actionTable.callback, self, act
      } catch {
        function(exception)
          ErrorNoHalt("Player action '"..tostring(act).."' has failed to run!\n"..exception..'\n')
        end
      }
    end
  end
end

function player_meta:running()
  if self:Alive() and !self:Crouching() and self:GetMoveType() == MOVETYPE_WALK
  and (self:OnGround() or self:WaterLevel() > 0) and self:GetVelocity():Length2DSqr() > (config.get('walk_speed', 100) + 20)^2 then
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

function player_meta:has_group(group)
  if self:GetUserGroup() == group then
    return true
  end

  return hook.run('PlayerHasGroup', self, group)
end
