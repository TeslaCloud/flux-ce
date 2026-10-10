--- Entity extensions of the Currencies plugin: the money an entity holds.
-- The balances of an entity are networked, so they can be read on the server and the client;
-- on the server they can be set, given, taken, dropped and moved to another entity. The
-- balance of a player belongs to their active character and is stored in its `Currency`
-- records, while other entities, such as containers, keep theirs on the entity.
--
-- Money that is added with `Entity:give_money` passes through the AdjustReceivedMoney hook,
-- which can change the amount or refuse it, whatever the money comes from: another player,
-- a container, money picked up from the ground or a plugin. `Entity:set_money` sets a
-- balance directly and does not run that hook.

local Color = Color

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
    --- Asks whether an entity is able to hold money. Called by `Entity:can_contain_money`, and
    -- on the server by the default CanGiveMoney handler for the receiver of the money.
    -- @param object [Entity]
    -- @return [Boolean return true if the entity can hold money; it cannot when nothing is
    --   returned]
    return hook.Run('CanContainMoney', self)
  end

  if SERVER then
    --- Rounds an amount of money to the decimals of a currency, the way set_money rounds a
    -- balance.
    -- @param currency [String currency ID]
    -- @param value [Number]
    -- @return [Number the rounded amount, or value itself if the currency is not registered]
    local function round_amount(currency, value)
      local currency_data = Currencies:find_currency(currency)

      return currency_data and math.round(value, currency_data.decimals or 0) or value
    end

    --- Works out how much of the money that an entity is about to be given it really gets:
    -- rounds the amount to the decimals of the currency and, if it is above 0, runs the
    -- AdjustReceivedMoney hook, which can change or refuse it. Nothing is added here.
    -- @param entity [Entity the entity that receives the money]
    -- @param currency [String ID of a registered currency]
    -- @param value [Number amount that is given]
    -- @param source=nil [Any what the money comes from, as passed to give_money]
    -- @return [Number the amount to add, which is never below 0 once a hook has changed it;
    --   false if a hook has refused the money]
    local function adjust_received(entity, currency, value, source)
      value = round_amount(currency, value)

      if value > 0 then
        --- Lets plugins change or refuse the money that an entity is about to be given, for
        -- instance to tax it. Called on the server by `Entity:give_money` and
        -- `Entity:give_money_to` for every amount above 0, whatever it comes from: a transfer
        -- from a player or a container, money picked up from the ground, or another plugin.
        -- Nothing has been moved yet when it runs. It is not called when a balance is set
        -- directly with `Entity:set_money`.
        -- @param entity [Entity the entity that receives the money: a player, whose active
        --   character gets it, or another entity such as a container]
        -- @param currency [String currency ID]
        -- @param amount [Number amount that is about to be added, rounded to the decimals of
        --   the currency]
        -- @param source [Any what the money comes from, as passed to give_money: the giving
        --   entity, a string that names the reason, or nil if the caller has not said]
        -- @return [Boolean/Number return false to refuse the money: nothing is added, and a
        --   transfer or a pickup it belongs to does not happen. Return a number to add that
        --   amount instead; it is rounded to the decimals of the currency and never below 0,
        --   and whoever gives the money still pays the full amount. Return nothing to leave
        --   the amount as it is]
        local result = hook.Run('AdjustReceivedMoney', entity, currency, value, source)

        if result == false then
          return false
        end

        if isnumber(result) and result == result and result != math.huge then
          return math.max(0, round_amount(currency, result))
        end
      end

      return value
    end

    --- Sets how much of a currency the entity holds, rounded to the currency's decimals and
    -- never below 0, networks it and runs the EntityMoneyChanged hook. A character that was
    -- created before the currency was registered gets its `Currency` record here, as long
    -- as the ID is spelled the way the currency is registered. Server only.
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
          local records = char and char.currencies

          if istable(records) then
            local found = false

            for k, v in pairs(records) do
              if v.currency_id == currency then
                v.amount = value
                found = true

                break
              end
            end

            if !found and Currencies:all()[currency] then
              local record = Currency.new()
                record.currency_id = currency
                record.amount = value
              table.insert(records, record)
            end
          end
        else
          self.currencies[currency] = value
        end

        self:set_nv('fl_currencies', currency_table)

        --- Called on the server after the amount of a currency that an entity holds has been
        -- set and networked.
        -- @param entity [Entity the player or other entity whose balance was set]
        -- @param currency [String currency ID]
        -- @param value [Number the new amount]
        -- @param old_value [Number the amount before the change]
        hook.Run('EntityMoneyChanged', self, currency, value, old_value)
      end
    end

    --- Adds an amount that `adjust_received` has returned to the balance of an entity and
    -- runs the EntityMoneyReceived hook if it is above 0. Does nothing for an amount of 0.
    -- @param entity [Entity the entity that receives the money]
    -- @param currency [String ID of a registered currency]
    -- @param value [Number amount to add, already rounded to the decimals of the currency]
    -- @param source=nil [Any what the money comes from, as passed to give_money]
    local function add_received(entity, currency, value, source)
      if value == 0 then return end

      entity:set_money(currency, entity:get_money(currency) + value)

      if value > 0 then
        --- Called on the server after money has been added to an entity with
        -- `Entity:give_money` or `Entity:give_money_to`. This is the place to log where
        -- money comes from.
        -- @param entity [Entity the entity that has received the money]
        -- @param currency [String currency ID]
        -- @param amount [Number amount that was added, after the AdjustReceivedMoney hook]
        -- @param source [Any what the money comes from, as passed to give_money: the giving
        --   entity, a string that names the reason, or nil if the caller has not said]
        hook.Run('EntityMoneyReceived', entity, currency, value, source)
      end
    end

    --- Removes money from the entity; the balance stops at 0. The amount is rounded to the
    -- currency's decimals before it is subtracted, so that taking an amount from one entity
    -- and giving the same amount to another always moves the same sum. Server only.
    -- ```
    -- if actor:has_money('tokens', 50) then
    --   actor:take_money('tokens', 50)
    -- end
    -- ```
    -- @param currency [String currency ID]
    -- @param value [Number amount to remove]
    function entity_meta:take_money(currency, value)
      self:set_money(currency, self:get_money(currency) - round_amount(currency, value))
    end

    --- Adds money to the entity. The amount is rounded to the currency's decimals before it
    -- is added, as in take_money. An amount above 0 first goes through the
    -- AdjustReceivedMoney hook, which can change or refuse it, and is reported with the
    -- EntityMoneyReceived hook once it has been added. Server only.
    -- ```
    -- local received = target:give_money('tokens', 50, 'reward')
    --
    -- if received == false then
    --   actor:notify('error.money_refused')
    -- end
    -- ```
    -- @param currency [String currency ID]
    -- @param value [Number amount to add]
    -- @param source=nil [Any what the money comes from, for the hooks: the entity that gives
    --   it (a player, a container or the fl_money entity that is picked up), or a string
    --   that names the reason]
    -- @return [Number the amount that was added, which a hook may have changed, 0 if the
    --   currency is not registered; false if a hook has refused the money]
    function entity_meta:give_money(currency, value, source)
      if !Currencies:find_currency(currency) then
        return 0
      end

      value = adjust_received(self, currency, value, source)

      if value == false then
        return false
      end

      add_received(self, currency, value, source)

      return value
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
    -- @param value [Number amount to drop; by default it has to be positive and may not have
    --   more decimals than the currency]
    -- @return [Boolean false when the drop is refused, String error phrase; nothing otherwise]
    function entity_meta:drop_money(currency, value)
      if !self:IsPlayer() then return false, 'error.invalid_entity' end

      local trace = self:GetEyeTraceNoCursor()
      local pos = trace.HitPos
      local eye_pos = self:EyePos()

      if eye_pos:DistToSqr(pos) > 14400 then
        pos = eye_pos + trace.Normal * 120
      end

      if IsValid(trace.Entity) and trace.Entity:IsPlayer() then
        return self:give_money_to(trace.Entity, currency, value)
      end

      --- Decides whether a player may drop money on the ground. Called on the server by
      -- `Entity:drop_money` before the money entity is created.
      -- @param actor [Player]
      -- @param amount [Number]
      -- @param currency [String currency ID]
      -- @param pos [Vector where the money would appear, at most 120 units from the eyes of
      --   the player]
      -- @param trace [Map eye trace result of the player]
      -- @return [Boolean return false to refuse the drop, String error phrase that drop_money
      --   returns to its caller]
      local success, err = hook.Run('CanPlayerDropMoney', self, value, currency, pos, trace)

      if success == false then
        return false, err
      end

      local currency_data = Currencies:find_currency(currency)
      local money_ent = Currencies:spawn_money(currency, value, pos)

      if !IsValid(money_ent) then
        return false, 'error.invalid_amount'
      end

      self:take_money(currency, value)
      self:notify('notification.currency.drop', { value = value, currency = currency_data.name }, Color('salmon'))

      money_ent.next_pickup = CurTime() + 0.5
    end

    --- Moves money from this entity to another one if the CanGiveMoney hook allows it, and
    -- notifies the players involved. The AdjustReceivedMoney hook is run for the receiver
    -- before anything is moved, so it can lower what arrives or refuse the transfer; the
    -- giver is then charged the full amount and the receiver gets what the hook has left,
    -- which is reported with the EntityMoneyReceived hook. Server only.
    -- ```
    -- local success, err = actor:give_money_to(target, 'tokens', 50)
    --
    -- if success == false then
    --   actor:notify(err)
    -- end
    -- ```
    -- @param target=nil [Entity receiver; a player gives to the entity they look at when nil]
    -- @param currency [String currency ID]
    -- @param value [Number amount to move; by default it has to be positive and may not have
    --   more decimals than the currency]
    -- @return [Boolean false when the transfer is refused, String error phrase; nothing otherwise]
    function entity_meta:give_money_to(target, currency, value)
      if !target and self:IsPlayer() then
        local trace = self:GetEyeTraceNoCursor()

        target = trace.Entity
      end

      --- Decides whether money may be moved from one entity to another. Called on the server
      -- by `Entity:give_money_to` before anything is moved.
      -- @param giver [Entity the entity the money is taken from, a player or a container]
      -- @param target [Entity the receiver; it may be invalid when a player gives money to
      --   whatever they are looking at]
      -- @param amount [Number]
      -- @param currency [String currency ID]
      -- @return [Boolean return false to refuse the transfer, String error phrase that
      --   give_money_to returns to its caller]
      local success, err = hook.Run('CanGiveMoney', self, target, value, currency)

      if success == false then
        return false, err
      end

      local currency_data = Currencies:find_currency(currency)

      if !currency_data then
        return false, 'error.invalid_currency'
      end

      local received = adjust_received(target, currency, value, self)

      if received == false then
        return false, 'error.money_refused'
      end

      self:take_money(currency, value)
      add_received(target, currency, received, self)

      if self:IsPlayer() then
        self:notify(
          'notification.currency.give',
          { target = target, value = value, currency = currency_data.name },
          Color('salmon')
        )
      end

      if target:IsPlayer() and received > 0 then
        target:notify(
          'notification.currency.receive',
          { target = self, value = received, currency = currency_data.name },
          Color('lightgreen')
        )
      end
    end
  end
end
