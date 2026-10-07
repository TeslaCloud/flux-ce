do
  local entity_meta = FindMetaTable('Entity')

  --- Returns how much of a currency the entity holds.
  -- @param currency [String currency ID]
  -- @return [Number amount, 0 if the currency is not registered]
  function entity_meta:get_money(currency)
    if Currencies:find_currency(currency) then
      return self:get_nv('fl_currencies', {})[currency] or 0
    end

    return 0
  end

  --- Checks whether the entity holds at least the given amount of a currency.
  -- @param currency [String currency ID]
  -- @param value [Number]
  -- @return [Boolean]
  function entity_meta:has_money(currency, value)
    return self:get_money(currency) >= value
  end

  --- Checks whether the entity is able to hold money by running the CanContainMoney hook.
  -- @return [Boolean true when a hook allows it, otherwise nil]
  function entity_meta:can_contain_money()
    return hook.Run('CanContainMoney', self)
  end

  if SERVER then
    --- Sets how much of a currency the entity holds, rounded to the currency's decimals and
    -- never below 0, networks it and runs the EntityMoneyChanged hook. Server only.
    -- @param currency [String currency ID; nothing happens if it is not registered]
    -- @param value [Number new amount]
    function entity_meta:set_money(currency, value)
      local currency_data = Currencies:find_currency(currency)

      if currency_data then
        local old_value = self:get_money(currency)

        value = math.max(0, math.round(value, currency_data.decimals or 0))

        local currency_table = self:get_nv('fl_currencies', {})
        currency_table[currency] = value

        if self:IsPlayer() then
          local char = self:get_character()

          for k, v in pairs(char.currencies) do
            if v.currency_id == currency then
              char.currencies[k].amount = value

              break
            end
          end
        else
          self.currencies[currency] = value
        end

        self:set_nv('fl_currencies', currency_table)

        hook.Run('EntityMoneyChanged', self, currency, value, old_value)
      end
    end

    --- Removes money from the entity; the balance stops at 0. Server only.
    -- ```
    -- if actor:has_money('tokens', 50) then
    --   actor:take_money('tokens', 50)
    -- end
    -- ```
    -- @param currency [String currency ID]
    -- @param value [Number amount to remove]
    function entity_meta:take_money(currency, value)
      self:set_money(currency, self:get_money(currency) - value)
    end

    --- Adds money to the entity. Server only.
    -- ```
    -- target:give_money('tokens', 50)
    -- ```
    -- @param currency [String currency ID]
    -- @param value [Number amount to add]
    function entity_meta:give_money(currency, value)
      self:set_money(currency, self:get_money(currency) + value)
    end

    --- Drops money from a player as an fl_money entity where they are looking, at most 120 units
    -- away; if they look at another player the money is given to that player. Server only.
    -- ```
    -- local success, err = actor:drop_money('tokens', 50)
    --
    -- if success == false then
    --   actor:notify(err)
    -- end
    -- ```
    -- @param currency [String currency ID]
    -- @param value [Number amount to drop]
    -- @return [Boolean false when the drop is refused, String error phrase; nothing otherwise]
    function entity_meta:drop_money(currency, value)
      if !self:IsPlayer() then return false, 'error.invalid_entity' end

      local trace = self:GetEyeTraceNoCursor()
      local pos = trace.HitPos

      if self:EyePos():Distance(pos) > 120 then
        pos = self:EyePos() + trace.Normal * 120
      end

      if IsValid(trace.Entity) and trace.Entity:IsPlayer() then
        self:give_money_to(trace.Entity, currency, value)

        return
      end

      local success, err = hook.Run('CanPlayerDropMoney', self, value, currency, pos, trace)

      if success == false then
        return false, err
      end

      local currency_data = Currencies:find_currency(currency)
      local money_ent = ents.Create('fl_money')
      money_ent:set_currency(currency)
      money_ent:set_currency_amount(value)

      local model = currency_data.model

      if currency_data.model_table then
        for k, v in SortedPairs(currency_data.model_table) do
          if k <= value then
            model = v
          end
        end
      end

      money_ent:SetModel(model)

      local mins, maxs = money_ent:GetCollisionBounds()

      pos = pos + Vector(0, 0, maxs.z)

      money_ent:SetPos(pos)
      money_ent:Spawn()

      self:take_money(currency, value)
      self:notify('notification.currency.drop', { value = value, currency = currency_data.name }, Color('salmon'))

      money_ent.next_pickup = CurTime() + 0.5
    end

    --- Moves money from this entity to another one if the CanGiveMoney hook allows it, and
    -- notifies the players involved. Server only.
    -- ```
    -- local success, err = actor:give_money_to(target, 'tokens', 50)
    --
    -- if success == false then
    --   actor:notify(err)
    -- end
    -- ```
    -- @param target=nil [Entity receiver; a player gives to the entity they look at when nil]
    -- @param currency [String currency ID]
    -- @param value [Number amount to move]
    -- @return [Boolean false when the transfer is refused, String error phrase; nothing otherwise]
    function entity_meta:give_money_to(target, currency, value)
      if !target and self:IsPlayer() then
        local trace = self:GetEyeTraceNoCursor()

        target = trace.Entity
      end

      local success, err = hook.Run('CanGiveMoney', self, target, value, currency)

      if success == false then
        return false, err
      end

      local currency_data = Currencies:find_currency(currency)

      self:take_money(currency, value)
      target:give_money(currency, value)

      if self:IsPlayer() then
        self:notify('notification.currency.give', { target = target, value = value, currency = currency_data.name }, Color('salmon'))
      end

      if target:IsPlayer() then
        target:notify('notification.currency.receive', { target = self, value = value, currency = currency_data.name }, Color('lightgreen'))
      end
    end
  end
end
