do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_money(currency)
    if Currencies:find_currency(currency) then
      return self:get_nv('fl_currencies')[currency] or 0
    end

    return 0
  end

  function player_meta:has_money(currency, value)
    return self:get_money(currency) >= value
  end

  if SERVER then
    function player_meta:set_money(currency, value)
      local currency_data = Currencies:find_currency(currency)

      if currency_data then
        local old_value = self:get_money(currency)

        value = math.max(0, math.round(value, currency_data.decimals or 0))

        local currency_table = self:get_nv('fl_currencies')
        currency_table[currency] = value

        local char = self:get_character()

        for k, v in pairs(char.currencies) do
          if v.currency_id == currency then
            char.currencies[k].amount = value

            break
          end
        end

        self:set_nv('fl_currencies', currency_table)

        hook.run('PlayerMoneyChanged', self, currency, value, old_value)
      end
    end

    function player_meta:take_money(currency, value)
      self:set_money(currency, self:get_money(currency) - value)
    end

    function player_meta:give_money(currency, value)
      self:set_money(currency, self:get_money(currency) + value)
    end

    function player_meta:drop_money(currency, value)
      local trace = self:GetEyeTraceNoCursor()
      local pos = trace.HitPos

      if self:EyePos():Distance(pos) > 120 then
        pos = self:EyePos() + trace.Normal * 120
      end

      if IsValid(trace.Entity) and trace.Entity:IsPlayer() then
        self:give_money_to(trace.Entity, currency, value)

        return
      end

      local success, err = hook.run('CanPlayerDropMoney', self, value, currency, pos, trace)

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
      self:notify('notification.currency.drop', { value, currency_data.name }, Color('red'))

      money_ent.next_pickup = CurTime() + 0.5
    end

    function player_meta:give_money_to(target, currency, value)
      if !target then
        local trace = self:GetEyeTraceNoCursor()

        target = trace.Entity
      end

      local success, err = hook.run('CanPlayerGiveMoney', self, target, value, currency)

      if success == false then
        return false, err
      end

      local currency_data = Currencies:find_currency(currency)

      self:take_money(currency, value)
      self:notify('notification.currency.give', { target, value, currency_data.name }, Color('red'))
      target:give_money(currency, value)
      target:notify('notification.currency.receive', { player, value, currency_data.name }, Color('green'))
    end
  end
end
