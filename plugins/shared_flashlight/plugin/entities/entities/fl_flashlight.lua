--- The light of a player's flashlight (`fl_flashlight`): an invisible entity parented to
-- the player that owns it, created and removed by `Player:set_flashlight`. Every client that
-- receives it draws a projected light from the owner's eyes along their view, shaped by the
-- `flashlight_fov`, `flashlight_distance`, `flashlight_brightness` and `flashlight_shadows`
-- configs, so the owner and everyone around them see the same beam.

AddCSLuaFile()

ENT.Type = 'anim'
ENT.PrintName = 'Flashlight'
ENT.Category = 'Flux'
ENT.Spawnable = false

if SERVER then
  --- Keeps the entity out of collisions and sends it along with the player it is parented
  -- to, so that a client that sees the player always has their light.
  function ENT:Initialize()
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(false)
    self:SetTransmitWithParent(true)
  end
else
  --- Does nothing but hide the shadow of the entity. The projected light is created on the
  -- first think that finds the owner, so that there is never a light without a player.
  function ENT:Initialize()
    self:DrawShadow(false)
  end

  --- Remembers the entity as the flashlight of its owner and moves the light to the owner's
  -- eyes, along their view. The engine Think of a clientside entity runs every frame, so the
  -- light follows the owner without a delay. The light is removed while the owner is not
  -- valid, which happens for a moment after the entity arrives and once the owner has left.
  function ENT:Think()
    local owner = self:GetOwner()

    if !IsValid(owner) or !owner:IsPlayer() then
      self:switch_off()

      return
    end

    if SharedFlashlight.lights[owner] != self then
      SharedFlashlight.lights[owner] = self
    end

    if !self.light then
      self.light = ProjectedTexture()
      self.light:SetTexture('effects/flashlight001')
      self.light:SetNearZ(12)
    end

    self.light:SetPos(owner:EyePos())
    self.light:SetAngles(owner:EyeAngles())
    self.light:SetFOV(Config.get('flashlight_fov', 50))
    self.light:SetFarZ(Config.get('flashlight_distance', 1024))
    self.light:SetBrightness(Config.get('flashlight_brightness', 1))
    self.light:SetEnableShadows(Config.get('flashlight_shadows', true))
    self.light:Update()
  end

  --- Draws nothing: the entity has no model, only the light.
  function ENT:Draw() end

  --- Removes the light, for the frames the owner is not known on. The next think that finds
  -- the owner creates it again.
  function ENT:switch_off()
    if self.light then
      self.light:Remove()
      self.light = nil
    end
  end

  --- Removes the light and forgets the entity as its owner's flashlight.
  function ENT:OnRemove()
    local owner = self:GetOwner()

    if self.light then
      self.light:Remove()
      self.light = nil
    end

    if IsValid(owner) and SharedFlashlight.lights[owner] == self then
      SharedFlashlight.lights[owner] = nil
    end
  end
end
