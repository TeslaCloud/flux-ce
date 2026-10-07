AddCSLuaFile()

ENT.Type = 'anim'
ENT.PrintName = 'Money'
ENT.Category = 'Flux'
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

--- Returns the currency this money entity holds.
-- @return [String currency ID, or nil if it has not been set]
function ENT:get_currency()
  return self:get_nv('fl_currency')
end

--- Returns how much money this entity holds.
-- @return [Number amount, or nil if it has not been set]
function ENT:get_currency_amount()
  return self:get_nv('fl_currency_amount')
end

--- Sets the currency this money entity holds. Server only.
-- @param value [String currency ID]
function ENT:set_currency(value)
  self:set_nv('fl_currency', value)
end

--- Sets how much money this entity holds. Server only.
-- @param value [Number]
function ENT:set_currency_amount(value)
  self:set_nv('fl_currency_amount', value)
end

if SERVER then
  --- Sets up physics, use type and collision group, and wakes the physics object.
  function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(ONOFF_USE)
    self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

    local phys_obj = self:GetPhysicsObject()

    if IsValid(phys_obj) then
      phys_obj:EnableMotion(true)
      phys_obj:Wake()
    end
  end

  --- Lets the activator pick the money up: runs PlayerPickupMoney and removes the entity
  -- unless a CanPlayerPickupMoney hook returns false.
  -- @param activator [Entity]
  -- @param caller [Entity]
  -- @param use_type [Number USE_* enum]
  -- @param value [Number]
  function ENT:Use(activator, caller, use_type, value)
    if IsValid(activator) then
      if hook.Run('CanPlayerPickupMoney', activator, self) != false then
        hook.Run('PlayerPickupMoney', activator, self)

        self:Remove()
      end
    end
  end
else
  --- Draws the entity's model.
  function ENT:Draw()
    self:DrawModel()
  end

  --- Draws the currency name and amount when the local player looks at the entity, fading
  -- out with distance.
  -- @param x [Number]
  -- @param y [Number]
  -- @param distance [Number distance between the local player and the entity]
  function ENT:DrawTargetID(x, y, distance)
    local currency = self:get_currency()

    if currency then
      local amount = self:get_currency_amount()
      local currency_data = Currencies:find_currency(currency)
      local title = t(currency_data.name)..' x '..amount
      local alpha = 255 - 255 * (distance / 300)

      if title then
        local font = Theme.get_font('tooltip_large')
        local text_w, text_h = util.text_size(title, font)

        draw.SimpleTextOutlined(title, font, x - text_w * 0.5, y, Theme.get_color('accent_light'):alpha(alpha), nil, nil, 1, color_black:alpha(alpha))

        y = y + text_h + 4
      end
    end
  end
end
