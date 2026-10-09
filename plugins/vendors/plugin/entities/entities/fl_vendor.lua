--- The vendor entity (`fl_vendor`): an NPC merchant that stands in place, plays an idle
-- animation and opens the trade panel for the player who uses it.
-- Its settings are kept on the server in the `vendor_data` field (see the server side of the
-- Vendors plugin) and are changed with `Vendors:apply`; the name and the description are
-- networked to the clients, which draw them when the vendor is looked at. Vendors are created
-- with `Vendors:create` or with the Vendor Tool rather than spawned directly.

AddCSLuaFile()

ENT.Type = 'anim'
ENT.Base = 'base_anim'
ENT.PrintName = 'Vendor'
ENT.Category = 'Flux'
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true
ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true

--- Returns the name of the vendor.
-- @return [String the name, or an empty string if it has not been networked yet]
function ENT:get_vendor_name()
  return self:get_nv('fl_vendor_name', '')
end

--- Returns the description of the vendor.
-- @return [String the description, or an empty string if the vendor has none]
function ENT:get_vendor_description()
  return self:get_nv('fl_vendor_description', '')
end

if SERVER then
  --- Makes the vendor usable with a single press of the use key and solid. A vendor that
  -- was spawned without settings gets the default ones.
  function ENT:Initialize()
    if !self.vendor_data then
      self.vendor_data = Vendors:get_default_data()
    end

    if !self:GetModel() or self:GetModel() == '' then
      self:SetModel(self.vendor_data.model)
    end

    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(true)
    self:setup_physics()
  end

  --- Gives the vendor a solid, motionless bounding box that fits its current model.
  function ENT:setup_physics()
    self:SetSolid(SOLID_BBOX)
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)

    local phys_obj = self:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:EnableMotion(false)
      phys_obj:Sleep()
    end
  end

  --- Plays the idle animation of the vendor: the sequence named in its settings if its model
  -- has it, otherwise the idle activity of the model, otherwise the first sequence with
  -- 'idle' in its name.
  function ENT:update_animation()
    local animation = self.vendor_data and self.vendor_data.animation
    local sequence = -1

    if isstring(animation) and animation != '' then
      sequence = self:LookupSequence(animation)
    end

    if sequence < 0 then
      sequence = self:SelectWeightedSequence(ACT_IDLE)
    end

    if sequence < 0 then
      for i = 0, self:GetSequenceCount() - 1 do
        if self:GetSequenceName(i):lower():find('idle', 1, true) then
          sequence = i

          break
        end
      end
    end

    self:ResetSequence(math.max(sequence, 0))
  end

  --- Stores the settings of the vendor and applies those that show: the model, the networked
  -- name and description, and the animation. The settings are not checked here.
  -- @warning [Internal] Use Vendors:apply to change the settings of a vendor.
  -- @param data [Map vendor settings that went through Vendors:sanitize]
  function ENT:set_vendor_data(data)
    self.vendor_data = data

    if (self:GetModel() or ''):lower() != data.model:lower() then
      self:SetModel(data.model)
      self:setup_physics()
    end

    self:set_nv('fl_vendor_name', data.name)
    self:set_nv('fl_vendor_description', data.description)
    self:update_animation()
  end

  --- Starts trading with the player who has used the vendor.
  -- @param activator [Entity the entity that pressed the use key, normally a Player]
  -- @param caller [Entity]
  -- @param use_type [Number USE_ enumerator]
  -- @param value [Number]
  function ENT:Use(activator, caller, use_type, value)
    if IsValid(activator) and activator:IsPlayer() then
      Vendors:open(activator, self)
    end
  end

  --- Thinks every tick, which is what keeps the animation of the vendor advancing.
  -- @return [Boolean always true, so that the next think time set here is used]
  function ENT:Think()
    self:NextThink(CurTime())

    return true
  end
else
  --- Draws the model of the vendor.
  function ENT:Draw()
    self:DrawModel()
  end
end
