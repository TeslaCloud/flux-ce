--[[
  Sandbox's tools copy-pasta.
  Because sandbox only lets you create tools
  from entities folder, which isn't exactly
  acceptable for us.
--]]

--[[
  For tool object documentation, as well as tutorials on
  creating gmod tools, go to gmod wiki. Our wiki only covers
  extras added by Flux.
--]]

class 'Tool'
Tool.is_flux_tool = true

function Tool:DrawToolScreen(w, h)
  surface.SetFont('GModToolScreen')

  local text = t('tool.'..self.id..'.name')
  local y = 104
  local w, h = surface.GetTextSize(text)
  w = w + 64

  y = y - h * 0.5

  local x = RealTime() * 250 % w * -1

  while x < w do
    surface.SetTextColor(0, 0, 0, 255)
    surface.SetTextPos(x + 3, y + 3)
    surface.DrawText(text)

    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(x, y)
    surface.DrawText(text)

    x = x + w
  end
end

function Tool:GetHelpText()
  return t('tool.'..self.id..'.desc')
end

function Tool:MakeGhostEntity(model, pos, angle)
  util.PrecacheModel(model)

  if SERVER and !game.SinglePlayer() then return end
  if CLIENT and game.SinglePlayer() then return end
  if self.GhostEntityLastDelete and self.GhostEntityLastDelete + 0.1 > CurTime() then return end

  -- Release the old ghost entity
  self:ReleaseGhostEntity()

  -- Don't allow ragdolls/effects to be ghosts
  if !util.IsValidProp(model) then return end

  if CLIENT then
    self.GhostEntity = ents.CreateClientProp(model)
  else
    self.GhostEntity = ents.Create('prop_physics')
  end

  -- If there's too many entities we might not spawn..
  if !IsValid(self.GhostEntity) then
    self.GhostEntity = nil
    return
  end

  self.GhostEntity:SetModel(model)
  self.GhostEntity:SetPos(pos)
  self.GhostEntity:SetAngles(angle)
  self.GhostEntity:Spawn()

  self.GhostEntity:SetSolid(SOLID_VPHYSICS)
  self.GhostEntity:SetMoveType(MOVETYPE_NONE)
  self.GhostEntity:SetNotSolid(true)
  self.GhostEntity:SetRenderMode(RENDERMODE_TRANSALPHA)
  self.GhostEntity:SetColor(Color(255, 255, 255, 150))
end

function Tool:StartGhostEntity(ent)
  if SERVER and !game.SinglePlayer() then return end
  if CLIENT and game.SinglePlayer() then return end

  self:MakeGhostEntity(ent:GetModel(), ent:GetPos(), ent:GetAngles())
end

function Tool:ReleaseGhostEntity()
  if self.GhostEntity then
    if !IsValid(self.GhostEntity) then self.GhostEntity = nil return end
    self.GhostEntity:Remove()
    self.GhostEntity = nil
    self.GhostEntityLastDelete = CurTime()
  end

  -- This is unused!
  if self.GhostEntities then
    for k,v in pairs(self.GhostEntities) do
      if IsValid(v) then v:Remove() end
      self.GhostEntities[k] = nil
    end

    self.GhostEntities = nil
    self.GhostEntityLastDelete = CurTime()
  end

  -- This is unused!
  if self.GhostOffset then
    for k,v in pairs(self.GhostOffset) do
      self.GhostOffset[k] = nil
    end
  end
end

function Tool:UpdateGhostEntity()
  if self.GhostEntity == nil then return end
  if !IsValid(self.GhostEntity) then self.GhostEntity = nil return end

  local trace = self:GetOwner():GetEyeTrace()
  if !trace.Hit then return end

  local ang1, ang2 = self:GetNormal(1):Angle(), (trace.HitNormal * -1):Angle()
  local target_angle = self:GetEnt(1):AlignAngles(ang1, ang2)

  self.GhostEntity:SetPos(self:GetEnt(1):GetPos())
  self.GhostEntity:SetAngles(target_angle)

  local translated_pos = self.GhostEntity:LocalToWorld(self:GetLocalPos(1))
  local target_pos = trace.HitPos + (self:GetEnt(1):GetPos() - translated_pos) + trace.HitNormal

  self.GhostEntity:SetPos(target_pos)
end

function Tool:UpdateData()
  self:SetStage(self:NumObjects())
end

function Tool:SetStage(i)
  if SERVER then
    self:GetWeapon():SetNWInt('Stage', i, true)
  end
end

function Tool:GetStage()
  return self:GetWeapon():GetNWInt('Stage', 0)
end

function Tool:SetOperation(i)
  if SERVER then
    self:GetWeapon():SetNWInt('Op', i, true)
  end
end

function Tool:GetOperation()
  return self:GetWeapon():GetNWInt('Op', 0)
end

-- Clear the selected objects
function Tool:ClearObjects()
  self:ReleaseGhostEntity()
  self.Objects = {}
  self:SetStage(0)
  self:SetOperation(0)
end

function Tool:GetEnt(i)
  if !self.Objects[i] then return NULL end

  return self.Objects[i].Ent
end

function Tool:GetPos(i)
  if self.Objects[i].Ent:EntIndex() == 0 then
    return self.Objects[i].Pos
  else
    if IsValid(self.Objects[i].Phys) then
      return self.Objects[i].Phys:LocalToWorld(self.Objects[i].Pos)
    else
      return self.Objects[i].Ent:LocalToWorld(self.Objects[i].Pos)
    end
  end
end

-- Returns the local position of the numbered hit
function Tool:GetLocalPos(i)
  return self.Objects[i].Pos
end

-- Returns the physics bone number of the hit (ragdolls)
function Tool:GetBone(i)
  return self.Objects[i].Bone
end

function Tool:GetNormal(i)
  if self.Objects[i].Ent:EntIndex() == 0 then
    return self.Objects[i].Normal
  else
    local norm
    if IsValid(self.Objects[i].Phys) then
      norm = self.Objects[i].Phys:LocalToWorld(self.Objects[i].Normal)
    else
      norm = self.Objects[i].Ent:LocalToWorld(self.Objects[i].Normal)
    end

    return norm - self:GetPos(i)
  end
end

-- Returns the physics object for the numbered hit
function Tool:GetPhys(i)
  if self.Objects[i].Phys == nil then
    return self:GetEnt(i):GetPhysicsObject()
  end

  return self.Objects[i].Phys
end

-- Sets a selected object
function Tool:SetObject(i, ent, pos, phys, bone, norm)
  self.Objects[i] = {}
  self.Objects[i].Ent = ent
  self.Objects[i].Phys = phys
  self.Objects[i].Bone = bone
  self.Objects[i].Normal = norm

  -- Worldspawn is a special case
  if ent:EntIndex() == 0 then
    self.Objects[i].Phys = nil
    self.Objects[i].Pos = pos
  else
    norm = norm + pos

    -- Convert the position to a local position - so it's still valid when the object moves
    if IsValid(phys) then
      self.Objects[i].Normal = self.Objects[i].Phys:WorldToLocal(norm)
      self.Objects[i].Pos = self.Objects[i].Phys:WorldToLocal(pos)
    else
      self.Objects[i].Normal = self.Objects[i].Ent:WorldToLocal(norm)
      self.Objects[i].Pos = self.Objects[i].Ent:WorldToLocal(pos)
    end
  end

  if SERVER then
    -- Todo: Make sure the client got the same info
  end
end

-- Returns the number of objects in the list
function Tool:NumObjects()
  if CLIENT then
    return self:GetStage()
  end

  return #self.Objects
end

if CLIENT then
  -- Tool should return true if freezing the view angles
  function Tool:FreezeMovement()
    return false
  end

  -- The tool's opportunity to draw to the HUD
  function Tool:DrawHUD()
  end
end

function Tool:init()
  self.Mode          = nil
  self.SWEP          = nil
  self.Owner         = nil
  self.ClientConVar  = {}
  self.ServerConVar  = {}
  self.Objects       = {}
  self.Stage         = 0
  self.Message       = 'start'
  self.LastMessage   = 0
  self.AllowedCVar   = 0
end

function Tool:CreateConVars()
  local mode = self:GetMode()

  if CLIENT then
    for cvar, default in pairs(self.ClientConVar) do
      CreateClientConVar(mode..'_'..cvar, default, true, true)
    end

    return
  end

  if SERVER then
    self.AllowedCVar = CreateConVar('toolmode_allow_'..mode, 1, FCVAR_NOTIFY)
  end
end

function Tool:GetServerInfo(property)
  local mode = self:GetMode()
  return GetConVarString(mode..'_'..property)
end

function Tool:BuildConVarList()
  local mode = self:GetMode()
  local convars = {}

  for k, v in pairs(self.ClientConVar) do convars[mode..'_'..k] = v end

  return convars
end

function Tool:GetClientInfo(property)
  return self:GetOwner():GetInfo(self:GetMode()..'_'..property)
end

function Tool:GetClientNumber(property, default)
  return self:GetOwner():GetInfoNum(self:GetMode()..'_'..property, tonumber(default) or 0)
end

function Tool:Allowed()
  if CLIENT then return true end

  return self.AllowedCVar:GetBool()
end

-- Now for all the Tool redirects
function Tool:Init()
end

function Tool:GetMode()     return self.Mode end
function Tool:GetSWEP()     return self.SWEP end
function Tool:GetOwner()    return self:GetSWEP().Owner or self.Owner end
function Tool:GetWeapon()   return self:GetSWEP().Weapon or self.Weapon end

function Tool:LeftClick()   return false end
function Tool:RightClick()  return false end
function Tool:Reload()      self:ClearObjects() end
function Tool:Deploy()      self:ReleaseGhostEntity() return end
function Tool:Holster()     self:ReleaseGhostEntity() return end
function Tool:Think()       self:ReleaseGhostEntity() end

--[[---------------------------------------------------------
  Checks the objects before any action is taken
  This is to make sure that the entities haven't been removed
-----------------------------------------------------------]]
function Tool:CheckObjects()
  for k, v in pairs(self.Objects) do
    if !v.Ent:IsWorld() and !v.Ent:IsValid() then
      self:ClearObjects()
    end
  end
end

function Tool:__tostring()
  return 'Tool ['..(self.id or 'Unknown')..']'
end
