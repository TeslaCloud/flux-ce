--- Server-side functions of the Currencies plugin: puts money into the world, and saves and
-- loads the money that lies in it. The money is stored in the plugin data of the current
-- schema and map under the 'money' key, one entry for every fl_money entity.

--- Puts an amount of a currency into the world as an fl_money entity, with the model that
-- the currency has for that amount. Nobody is charged for it: `Entity:drop_money` is what
-- takes the money out of the pocket of a player. Server only.
-- ```
-- local trace = actor:GetEyeTraceNoCursor()
-- local money_ent = Currencies:spawn_money('tokens', 50, trace.HitPos)
-- ```
-- @param currency [String currency ID, letter case is ignored]
-- @param amount [Number amount the entity holds, has to be above 0]
-- @param position [Vector where to put the money; it is raised by the height of its bounds]
-- @param angles=nil [Angle]
-- @return [Entity the fl_money entity; nil if the currency is not registered, the amount or
--   the position is invalid, or the entity could not be created]
function Currencies:spawn_money(currency, amount, position, angles)
  if !isstring(currency) or !self:find_currency(currency) then return end
  if !isnumber(amount) or amount != amount or amount <= 0 or amount == math.huge then return end
  if !isvector(position) then return end

  local money_ent = ents.Create('fl_money')

  if !IsValid(money_ent) then return end

  currency = currency:lower()

  money_ent:set_currency(currency)
  money_ent:set_currency_amount(amount)
  money_ent:SetModel(self:get_money_model(currency, amount))

  local mins, maxs = money_ent:GetCollisionBounds()

  money_ent:SetPos(position + Vector(0, 0, maxs.z))

  if isangle(angles) then
    money_ent:SetAngles(angles)
  end

  money_ent:Spawn()

  return money_ent
end

--- Saves the currency, amount, position and angles of every fl_money entity in the world,
-- and whether it is frozen, to the plugin data of the current schema and map. Entities that
-- are being removed are left out, so it can be called right after `Entity:Remove`. The
-- plugin calls it whenever the framework saves its data and whenever money is picked up,
-- while the save_dropped_money config is on. Server only.
function Currencies:save_money()
  local saved = {}

  for k, v in ipairs(ents.FindByClass('fl_money')) do
    local currency = v:get_currency()
    local amount = v:get_currency_amount()

    if !v:IsMarkedForDeletion() and isstring(currency) and isnumber(amount) and amount > 0 then
      local phys_obj = v:GetPhysicsObject()

      table.insert(saved, {
        currency = currency,
        amount = amount,
        position = v:GetPos(),
        angles = v:GetAngles(),
        frozen = IsValid(phys_obj) and !phys_obj:IsMotionEnabled()
      })
    end
  end

  Data.save_plugin('money', saved)
end

--- Spawns the money that `Currencies:save_money` has saved for the current map, each
-- entity exactly where it was, and freezes what was frozen. Entries of currencies that are
-- no longer registered are skipped. Server only.
function Currencies:load_money()
  local saved = Data.load_plugin('money', {})

  if !istable(saved) then return end

  for k, v in pairs(saved) do
    if istable(v) and isvector(v.position) then
      local money_ent = self:spawn_money(v.currency, v.amount, v.position, v.angles)

      if IsValid(money_ent) then
        money_ent:SetPos(v.position)

        if v.frozen then
          local phys_obj = money_ent:GetPhysicsObject()

          if IsValid(phys_obj) then
            phys_obj:EnableMotion(false)
          end
        end
      end
    end
  end
end
