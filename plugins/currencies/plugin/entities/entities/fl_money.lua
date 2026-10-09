--- Money lying in the world (`fl_money`): holds an amount of one currency and hands it to the
-- player who uses it, unless the CanPlayerPickupMoney hook prevents that. It is created by
-- `Currencies:spawn_money`, which is what `Entity:drop_money` puts the money of a player into
-- the world with. While the save_dropped_money config is on, the Currencies plugin saves
-- these entities and puts them back when the map is loaded again; the money that is left is
-- saved again as soon as one of them is picked up, so that it cannot come back after it has
-- been taken.

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
  -- unless a CanPlayerPickupMoney hook returns false. The entity also stays if a
  -- PlayerPickupMoney handler returns false, which the Currencies plugin does when the money
  -- was refused. Once the entity is removed, the money that is left in the world is saved
  -- if the save_dropped_money config is on.
  -- @param activator [Entity]
  -- @param caller [Entity]
  -- @param use_type [Number USE_* enum]
  -- @param value [Number]
  function ENT:Use(activator, caller, use_type, value)
    if IsValid(activator) then
      --- Decides whether money lying in the world may be picked up. Called on the server when
      -- a valid entity uses an fl_money entity.
      -- @param activator [Entity the entity that used the money, normally a player]
      -- @param entity [Entity the fl_money entity]
      -- @return [Boolean return false to prevent the pickup]
      if hook.Run('CanPlayerPickupMoney', activator, self) != false then
        --- Called on the server when money is picked up, right before its entity is removed.
        -- The handler of the Currencies plugin itself is what adds the money to the player.
        -- @param activator [Entity the entity that used the money, normally a player]
        -- @param entity [Entity the fl_money entity; its get_currency and get_currency_amount
        --   methods return what it holds]
        -- @return [Boolean return false to leave the money where it is, as the Currencies
        --   plugin does when the AdjustReceivedMoney hook has refused it. A returned value
        --   keeps the handlers after it from running, so return nothing otherwise]
        if hook.Run('PlayerPickupMoney', activator, self) != false then
          self:Remove()

          if Config.get('save_dropped_money') then
            Currencies:save_money()
          end
        end
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

        draw.SimpleTextOutlined(
          title,
          font,
          x - text_w * 0.5,
          y,
          Theme.get_color('accent_light'):alpha(alpha),
          nil,
          nil,
          1,
          color_black:alpha(alpha)
        )

        y = y + text_h + 4
      end
    end
  end
end
