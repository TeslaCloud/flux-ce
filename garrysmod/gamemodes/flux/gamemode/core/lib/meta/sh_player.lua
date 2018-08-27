local player_meta = FindMetaTable("Player")

function player_meta:HasInitialized()
  return self:GetDTBool(BOOL_INITIALIZED) or false
end

function player_meta:get_data()
  return self:get_nv("flData", {})
end

player_meta.flName = player_meta.flName or player_meta.Name

function player_meta:Name(bForceTrueName)
  return (!bForceTrueName and hook.run("GetPlayerName", self)) or self:get_nv("name", self:flName())
end

function player_meta:SteamName()
  return self:flName()
end

function player_meta:SetModel(sPath)
  local oldModel = self:GetModel()

  hook.run("PlayerModelChanged", self, sPath, oldModel)

  if SERVER then
    netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel)
  end

  return self:flSetModel(sPath)
end

--[[
  Actions system
--]]

function player_meta:SetAction(id, bForce)
  if (bForce or self:GetAction() == "none") then
    self:set_nv("action", id)

    return true
  end
end

function player_meta:GetAction()
  return self:get_nv("action", "none")
end

function player_meta:IsDoingAction(id)
  return (self:GetAction() == id)
end

function player_meta:ResetAction()
  self:SetAction("none", true)
end

function player_meta:DoAction(id)
  local act = self:GetAction()

  if (isstring(id)) then
    act = id
  end

  if (act and act != "none") then
    local actionTable = fl.get_action(act)

    if (istable(actionTable) and isfunction(actionTable.callback)) then
      try {
        actionTable.callback, self, act
      } catch {
        function(exception)
          ErrorNoHalt("Player action '"..tostring(act).."' has failed to run!\n"..exception.."\n")
        end
      }
    end
  end
end

--[[
  Admin system

  Hook your admin mods to these functions, they're universally used
  throughout the Flux framework.
--]]

function player_meta:HasPermission(perm)
  return hook.run("PlayerHasPermission", self, perm)
end

function player_meta:is_root()
  return hook.run("PlayerIsRoot", self)
end

function player_meta:IsMemberOf(group)
  if (self:GetUserGroup() == group) then
    return true
  end

  return hook.run("PlayerIsMemberOfGroup", self, group)
end
