--- Server-side functions of the Currencies plugin: puts money into the world, hands it to
-- the players who pick it up, saves and loads the money that lies in it, and decides who is
-- sent the balances of a player. The money in the world is stored in the plugin data of the
-- current schema and map under the 'money' key, one entry for every fl_money entity. It is
-- saved again a second after every pickup and every drop, as the balance of the character
-- is, so that a crash does not bring back money that has changed hands.

local IsValid = IsValid
local isstring = isstring
local isnumber = isnumber
local pairs = pairs
local ipairs = ipairs

--- Gives the contents of a money entity to a player, notifies them, starts their pickup
-- cooldown and has the money in the world saved a second later. The entity is not removed
-- here. Server only.
-- @param actor [Player]
-- @param entity [Entity the fl_money entity]
-- @return [Boolean true if the player has received the money; false if the entity holds no
--   registered currency or the CanEntityReceiveMoney hook has refused the money, in which
--   case the money stays where it is]
function Currencies:pickup_money(actor, entity)
  local currency = entity:get_currency()
  local amount = entity:get_currency_amount()
  local currency_data = isstring(currency) and self:find_currency(currency)

  if !currency_data or !isnumber(amount) then return false end

  local received = actor:give_money(currency, amount, entity)

  actor.next_money_pickup = CurTime() + 0.5

  if received == false then
    return false
  end

  self.money_dirty = true
  self:queue_money_save()

  actor:notify('notification.currency.pickup', { value = received, currency = currency_data.name }, Color('lightgreen'))
  entity:EmitSound('physics/cardboard/cardboard_box_impact_bullet'..math.random(1, 5)..'.wav', 55)

  return true
end

--- Puts an amount of a currency into the world as an fl_money entity, with the model that
-- the currency has for that amount. Nobody is charged for it: `Entity:drop_money` is what
-- takes the money out of the pocket of a player. Server only.
-- ```
-- local trace = actor:GetEyeTraceNoCursor()
-- local money_ent = Currencies:spawn_money('tokens', 50, trace.HitPos)
-- ```
-- @param currency [String currency ID, letter case is ignored]
-- @param amount [Number amount the entity holds, has to be above 0]
-- @param position [Vector where to put the money; it is moved away from it by the height of
--   its bounds]
-- @param angles=nil [Angle]
-- @param normal=nil [Vector the direction to move the money in, such as the normal of the
--   surface it is put on; straight up if nil]
-- @return [Entity the fl_money entity; nil if the currency is not registered, the amount or
--   the position is invalid, or the entity could not be created]
function Currencies:spawn_money(currency, amount, position, angles, normal)
  if !self:find_currency(currency) then return end
  if !math.is_finite(amount) or amount <= 0 then return end
  if !isvector(position) then return end

  local money_ent = ents.Create('fl_money')

  if !IsValid(money_ent) then return end

  currency = currency:lower()

  money_ent:set_currency(currency)
  money_ent:set_currency_amount(amount)
  money_ent:SetModel(self:get_money_model(currency, amount))

  local _mins, maxs = money_ent:GetCollisionBounds()

  money_ent:SetPos(position + (isvector(normal) ? normal : vector_up) * maxs.z)

  if isangle(angles) then
    money_ent:SetAngles(angles)
  end

  money_ent:Spawn()

  return money_ent
end

--- Saves the money that lies in the world a second from now, if the currencies_save_dropped_money
-- config is on. Calls that come within that second are saved together. Server only.
function Currencies:queue_money_save()
  if !Config.get('currencies_save_dropped_money') then return end

  timer.Create('fl_save_dropped_money', 1, 1, function()
    if Config.get('currencies_save_dropped_money') then
      Currencies:save_money()
    end
  end)
end

--- Saves the currency, amount, position and angles of every fl_money entity in the world,
-- and whether it is frozen, to the plugin data of the current schema and map. Entities that
-- are being removed are left out, so it can be called right after `Entity:Remove`. The
-- plugin calls it whenever the framework saves its data, while the currencies_save_dropped_money
-- config is on. Server only.
function Currencies:save_money()
  local saved = {}

  for _, entity in ipairs(ents.FindByClass('fl_money')) do
    local currency = entity:get_currency()
    local amount = entity:get_currency_amount()

    if !entity:IsMarkedForDeletion() and isstring(currency) and isnumber(amount) and amount > 0 then
      local phys_obj = entity:GetPhysicsObject()

      saved[#saved + 1] = {
        currency = currency,
        amount = amount,
        position = entity:GetPos(),
        angles = entity:GetAngles(),
        frozen = IsValid(phys_obj) and !phys_obj:IsMotionEnabled()
      }
    end
  end

  Data.save_plugin('money', saved)
end

--- Spawns the money that `Currencies:save_money` has saved for the current map, each
-- entity exactly where it was, and freezes what was frozen. Entries of currencies that are
-- not registered are skipped. Server only.
function Currencies:load_money()
  local saved = Data.load_plugin('money', {})

  if !istable(saved) then return end

  for _, entry in pairs(saved) do
    if istable(entry) and isvector(entry.position) then
      local money_ent = self:spawn_money(entry.currency, entry.amount, entry.position, entry.angles)

      if IsValid(money_ent) then
        money_ent:SetPos(entry.position)

        if entry.frozen then
          local phys_obj = money_ent:GetPhysicsObject()

          if IsValid(phys_obj) then
            phys_obj:EnableMotion(false)
          end
        end
      end
    end
  end
end

--- Finds an inventory of an entity that is open for a player, which is what entitles the
-- player to see and take the money of that entity.
-- @param actor [Player the player who wants the money]
-- @param entity [Entity the container or the player that holds the money]
-- @return [Inventory the open inventory, or nil if the entity has none open for the player]
function Currencies:find_open_inventory(actor, entity)
  if entity:IsPlayer() then
    for _, inventory in pairs(entity:get_inventories()) do
      if inventory:has_receiver(actor) then
        return inventory
      end
    end
  elseif entity.inventory and entity.inventory:has_receiver(actor) then
    return entity.inventory
  end
end

--- Sends the balances of a player to the player and to everyone who has one of the
-- inventories of that player open, such as someone who searches them, and to nobody else.
-- @param target [Player the player whose balances are sent]
function Currencies:update_balance_recipients(target)
  local recipients = { target }

  for _, inventory in pairs(target:get_inventories()) do
    for _, receiver in ipairs(inventory.receivers) do
      if IsValid(receiver) and !table.HasValue(recipients, receiver) then
        recipients[#recipients + 1] = receiver
      end
    end
  end

  target:set_nv_recipients('fl_currencies', recipients)
end
