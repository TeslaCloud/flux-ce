AddCSLuaFile()

ENT.Type = 'anim'
ENT.PrintName = 'Money'
ENT.Category = 'Flux'
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:get_currency()
  return self:get_nv('fl_currency')
end

function ENT:get_currency_amount()
  return self:get_nv('fl_currency_amount')
end

function ENT:set_currency(value)
  self:set_nv('fl_currency', value)
end

function ENT:set_currency_amount(value)
  self:set_nv('fl_currency_amount', value)
end

if SERVER then
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

  function ENT:Use(activator, caller, use_type, value)
    if IsValid(activator) then
      if hook.run('CanPlayerPickupMoney', activator, self) != false then
        hook.run('PlayerPickupMoney', activator, self)

        self:Remove()
      end
    end
  end
else
  function ENT:Draw()
    self:DrawModel()
  end

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
