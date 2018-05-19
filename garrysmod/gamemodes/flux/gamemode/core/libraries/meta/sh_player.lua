--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local player_meta = FindMetaTable("Player")

function player_meta:HasInitialized()
  return self:GetDTBool(BOOL_INITIALIZED) or false
end

function player_meta:GetData()
  return self:GetNetVar("flData", {})
end

player_meta.flName = player_meta.flName or player_meta.Name

function player_meta:Name(bForceTrueName)
  return (!bForceTrueName and hook.Run("GetPlayerName", self)) or self:GetNetVar("name", self:flName())
end

function player_meta:SteamName()
  return self:flName()
end

function player_meta:SetModel(sPath)
  local oldModel = self:GetModel()

  hook.Run("PlayerModelChanged", self, sPath, oldModel)

  if (SERVER) then
    netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel)
  end

  return self:flSetModel(sPath)
end

--[[
  Actions system
--]]

function player_meta:SetAction(id, bForce)
  if (bForce or self:GetAction() == "none") then
    self:SetNetVar("action", id)

    return true
  end
end

function player_meta:GetAction()
  return self:GetNetVar("action", "none")
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
    local actionTable = fl.GetAction(act)

    if (istable(actionTable) and isfunction(actionTable.callback)) then
      try {
        actionTable.callback, self, act
      } catch {
        function(exception)
          ErrorNoHalt("[Flux] Player action '"..tostring(act).."' has failed to run!\n"..exception.."\n")
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
  return hook.Run("PlayerHasPermission", self, perm)
end

function player_meta:IsRoot()
  return hook.Run("PlayerIsRoot", self)
end

function player_meta:IsMemberOf(group)
  if (self:GetUserGroup() == group) then
    return true
  end

  return hook.Run("PlayerIsMemberOfGroup", self, group)
end
