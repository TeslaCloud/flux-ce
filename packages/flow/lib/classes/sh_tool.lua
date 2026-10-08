--- Base class of the tool gun tools that Flux loads. It reimplements the tool object of
-- Sandbox, so that a tool file written for Sandbox works as it is: the same fields (`Mode`,
-- `ClientConVar`, `Objects` and so on), the same callbacks to override (`LeftClick`,
-- `RightClick`, `Reload`, `Think`, `Deploy`, `Holster`, `DrawHUD`) and the same helpers for
-- console variables, selected objects and ghost entities. What Flux adds is that the name and
-- the description of a tool come from the `tool.<id>.name` and `tool.<id>.desc` language
-- phrases. Tool files are loaded from the `tools` folders by the `Flux.Tool` library, which
-- creates the object and passes it to the file as `TOOL`.

--[[
  Sandbox's tools copy-pasta.
  Because sandbox only lets you create tools
  from the entities folder, which isn't exactly
  acceptable for us.
--]]

--[[
  For tool object documentation, as well as tutorials on
  creating gmod tools, go to the gmod wiki. Our wiki only covers
  extras added by Flux.
--]]

class 'Tool'
Tool.is_flux_tool = true

--- Draws the scrolling name of the tool on the screen of the tool gun.
-- @param w [Number width of the screen]
-- @param h [Number height of the screen]
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

--- Returns the translated description of the tool.
-- @return [String]
function Tool:GetHelpText()
  return t('tool.'..self.id..'.desc')
end

--- Creates a translucent ghost prop that previews the result of the tool, replacing
-- the previous one. Ragdolls and effects cannot be ghosts.
-- @param model [String path to the model]
-- @param pos [Vector]
-- @param angle [Angle]
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

--- Creates a ghost entity that copies the model, position and angles of the specified entity.
-- @param ent [Entity]
function Tool:StartGhostEntity(ent)
  if SERVER and !game.SinglePlayer() then return end
  if CLIENT and game.SinglePlayer() then return end

  self:MakeGhostEntity(ent:GetModel(), ent:GetPos(), ent:GetAngles())
end

--- Removes the ghost entity of the tool.
function Tool:ReleaseGhostEntity()
  if self.GhostEntity then
    if !IsValid(self.GhostEntity) then self.GhostEntity = nil return end
    self.GhostEntity:Remove()
    self.GhostEntity = nil
    self.GhostEntityLastDelete = CurTime()
  end

  -- This is unused!
  if self.GhostEntities then
    for k, v in pairs(self.GhostEntities) do
      if IsValid(v) then v:Remove() end
      self.GhostEntities[k] = nil
    end

    self.GhostEntities = nil
    self.GhostEntityLastDelete = CurTime()
  end

  -- This is unused!
  if self.GhostOffset then
    for k, v in pairs(self.GhostOffset) do
      self.GhostOffset[k] = nil
    end
  end
end

--- Moves the ghost entity to where the first selected object would end up if the tool
-- was applied to the spot the owner is aiming at.
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

--- Sets the stage of the tool to the number of selected objects.
function Tool:UpdateData()
  self:SetStage(self:NumObjects())
end

--- Sets the stage of the tool and networks it to the clients. Does nothing on the client.
-- @param i [Number]
function Tool:SetStage(i)
  if SERVER then
    self:GetWeapon():SetNWInt('Stage', i, true)
  end
end

--- Returns the current stage of the tool.
-- @return [Number]
function Tool:GetStage()
  return self:GetWeapon():GetNWInt('Stage', 0)
end

--- Sets the operation of the tool and networks it to the clients. Does nothing on the client.
-- @param i [Number]
function Tool:SetOperation(i)
  if SERVER then
    self:GetWeapon():SetNWInt('Op', i, true)
  end
end

--- Returns the current operation of the tool.
-- @return [Number]
function Tool:GetOperation()
  return self:GetWeapon():GetNWInt('Op', 0)
end

--- Clears the selected objects, removes the ghost entity and resets the stage and operation.
function Tool:ClearObjects()
  self:ReleaseGhostEntity()
  self.Objects = {}
  self:SetStage(0)
  self:SetOperation(0)
end

--- Returns the entity of the numbered hit.
-- @param i [Number index of the selected object]
-- @return [Entity the entity, NULL if there is no object with this index]
function Tool:GetEnt(i)
  if !self.Objects[i] then return NULL end

  return self.Objects[i].Ent
end

--- Returns the world position of the numbered hit.
-- @param i [Number index of the selected object]
-- @return [Vector]
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

--- Returns the position of the numbered hit local to the entity that was hit.
-- @param i [Number index of the selected object]
-- @return [Vector]
function Tool:GetLocalPos(i)
  return self.Objects[i].Pos
end

--- Returns the physics bone number of the numbered hit (for ragdolls).
-- @param i [Number index of the selected object]
-- @return [Number]
function Tool:GetBone(i)
  return self.Objects[i].Bone
end

--- Returns the surface normal of the numbered hit in world space.
-- @param i [Number index of the selected object]
-- @return [Vector]
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

--- Returns the physics object of the numbered hit.
-- @param i [Number index of the selected object]
-- @return [PhysObj]
function Tool:GetPhys(i)
  if self.Objects[i].Phys == nil then
    return self:GetEnt(i):GetPhysicsObject()
  end

  return self.Objects[i].Phys
end

--- Stores a selected object. The position and the normal are converted to be local to the
-- physics object (or the entity), so that they stay valid when it moves.
-- @param i [Number index to store the object under]
-- @param ent [Entity the entity that was hit]
-- @param pos [Vector world position of the hit]
-- @param phys [PhysObj physics object that was hit]
-- @param bone [Number physics bone number]
-- @param norm [Vector surface normal of the hit]
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

--- Returns the number of selected objects. On the client this is the stage of the tool.
-- @return [Number]
function Tool:NumObjects()
  if CLIENT then
    return self:GetStage()
  end

  return #self.Objects
end

if CLIENT then
  --- Determines whether the view angles of the owner should be frozen while using the tool.
  -- Returns false by default.
  -- @return [Boolean]
  function Tool:FreezeMovement()
    return false
  end

  --- Gives the tool an opportunity to draw to the HUD. Does nothing by default.
  function Tool:DrawHUD()
  end
end

--- Creates a new tool with the default values of its fields.
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

--- Creates the console variables of the tool: the ones listed in ClientConVar on the client,
-- and 'toolmode_allow_<mode>' on the server.
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

--- Returns the value of a console variable of the tool.
-- @param property [String name of the variable without the tool mode prefix]
-- @return [String]
function Tool:GetServerInfo(property)
  local mode = self:GetMode()
  return GetConVarString(mode..'_'..property)
end

--- Builds a list of the client console variables of the tool with their defaults.
-- @return [Map default values by full variable name]
function Tool:BuildConVarList()
  local mode = self:GetMode()
  local convars = {}

  for k, v in pairs(self.ClientConVar) do convars[mode..'_'..k] = v end

  return convars
end

--- Returns the value of a client console variable of the tool for its owner.
-- @param property [String name of the variable without the tool mode prefix]
-- @return [String]
function Tool:GetClientInfo(property)
  return self:GetOwner():GetInfo(self:GetMode()..'_'..property)
end

--- Returns the value of a client console variable of the tool for its owner as a number.
-- @param property [String name of the variable without the tool mode prefix]
-- @param default=0 [Number returned if the variable is not a number]
-- @return [Number]
function Tool:GetClientNumber(property, default)
  return self:GetOwner():GetInfoNum(self:GetMode()..'_'..property, tonumber(default) or 0)
end

--- Checks whether the tool is allowed to be used on the server. Always true on the client.
-- @return [Boolean]
function Tool:Allowed()
  if CLIENT then return true end

  return self.AllowedCVar:GetBool()
end

-- Now for all the Tool redirects

--- Called when the tool gun initializes the tool. Does nothing by default.
function Tool:Init()
end

--- Returns the mode (ID) of the tool.
-- @return [String]
function Tool:GetMode()     return self.Mode end

--- Returns the tool gun that this tool belongs to.
-- @return [Weapon]
function Tool:GetSWEP()     return self.SWEP end

--- Returns the player who holds the tool gun.
-- @return [Player]
function Tool:GetOwner()    return self:GetSWEP().Owner or self.Owner end

--- Returns the weapon entity of the tool gun.
-- @return [Weapon]
function Tool:GetWeapon()   return self:GetSWEP().Weapon or self.Weapon end

--- Called when the owner presses primary attack. Returns false by default.
-- @return [Boolean false, overrides should return true if the tool has done something]
function Tool:LeftClick()   return false end

--- Called when the owner presses secondary attack. Returns false by default.
-- @return [Boolean false, overrides should return true if the tool has done something]
function Tool:RightClick()  return false end

--- Called when the owner presses reload. Clears the selected objects by default.
function Tool:Reload()      self:ClearObjects() end

--- Called when the tool gun is deployed. Removes the ghost entity by default.
function Tool:Deploy()      self:ReleaseGhostEntity() return end

--- Called when the tool gun is holstered. Removes the ghost entity by default.
function Tool:Holster()     self:ReleaseGhostEntity() return end

--- Called every tick while the tool is active. Removes the ghost entity by default.
function Tool:Think()       self:ReleaseGhostEntity() end

--[[---------------------------------------------------------
  Checks the objects before any action is taken
  This is to make sure that the entities haven't been removed
-----------------------------------------------------------]]

--- Clears the selected objects if any of their entities has been removed.
function Tool:CheckObjects()
  for k, v in pairs(self.Objects) do
    if !v.Ent:IsWorld() and !v.Ent:IsValid() then
      self:ClearObjects()
    end
  end
end

--- Converts the tool to a string for printing.
-- @return [String]
function Tool:__tostring()
  return '#<Tool:'..(self.id or 'Unknown')..'>'
end
