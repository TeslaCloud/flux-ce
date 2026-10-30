--- Money lying in the world (`fl_money`): holds an amount of one currency and hands it to the
-- player who uses it (`Currencies:pickup_money`), unless the PlayerCanPickupMoney or the
-- PrePlayerPickupMoney hook prevents that. It is created by `Currencies:spawn_money`, which is
-- what `Entity:drop_money` puts the money of a player into the world with. While the
-- currencies_save_dropped_money config is on, the Currencies plugin saves these entities and puts them
-- back when the map is loaded again; a pickup marks the saved money as out of date, so that
-- the next data save writes what is left.

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

  --- Lets the activator pick the money up: asks the PlayerCanPickupMoney and the
  -- PrePlayerPickupMoney hooks, gives the money to the activator with
  -- `Currencies:pickup_money` and removes the entity. Only players pick money up, and money
  -- that is being removed cannot be picked up again. The entity stays if either hook
  -- returns false or if the money is refused, as it is when the CanEntityReceiveMoney hook
  -- refuses it.
  -- @param activator [Entity]
  -- @param _caller [Entity]
  -- @param _use_type [Number USE_* enum]
  -- @param _value [Number]
  function ENT:Use(activator, _caller, _use_type, _value)
    if !IsValid(activator) or !activator:IsPlayer() or self:IsMarkedForDeletion() then return end

    --- Decides whether a player may pick up money lying in the world: the rule, such as the
    -- pickup cooldowns of the Currencies plugin. Called on the server when a player uses an
    -- fl_money entity, before `PrePlayerPickupMoney`.
    -- @param activator [Player the player who used the money]
    -- @param entity [Entity the fl_money entity]
    -- @return [Boolean return false to prevent the pickup]
    if hook.Run('PlayerCanPickupMoney', activator, self) == false then return end

    --- Called on the server right before money is picked up, once every `PlayerCanPickupMoney`
    -- handler has allowed the pickup and before anything has changed hands. A handler can
    -- still cancel this pickup or take note of it; the money itself is given by
    -- `Currencies:pickup_money` once the hook has run.
    -- @param activator [Player the player who used the money]
    -- @param entity [Entity the fl_money entity; its get_currency and get_currency_amount
    --   methods return what it holds]
    -- @return [Boolean return false to leave the money where it is. A returned value keeps
    --   the handlers after it from running, so return nothing otherwise]
    if hook.Run('PrePlayerPickupMoney', activator, self) == false then return end

    if Currencies:pickup_money(activator, self) then
      --- Called on the server after a player has picked money up, right before the money
      -- entity is removed. Not called when nothing has changed hands.
      -- @param activator [Player the player who has picked the money up]
      -- @param entity [Entity the fl_money entity]
      hook.Run('PostPlayerPickupMoney', activator, self)

      self:Remove()
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
    local amount = self:get_currency_amount()
    local currency_data = isstring(currency) and Currencies:find_currency(currency)

    if !currency_data or !amount then return end

    local title = t(currency_data.name)..' x '..amount
    local alpha = 255 - 255 * (distance / 300)
    local font = Theme.get_font('tooltip_large')
    local text_w = util.text_size(title, font)

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
  end
end
