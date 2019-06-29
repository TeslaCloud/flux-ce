
function Currencies:PostCreateCharacter(player, char, char_data)
  for k, v in pairs(Currencies.all()) do
    local currency = Currency.new()
      currency.currency_id = k
      currency.amount = 0
    table.insert(char.currencies, currency)
  end
end

function Currencies:OnActiveCharacterSet(player, character)
  local currencies = {}

  if character.currencies then
    for k, v in pairs(character.currencies) do
      currencies[v.currency_id] = v.amount
    end
  end

  player:set_nv('fl_currencies', currencies)
end

function Currencies:PlayerMoneyChanged(player, currency, value, old_value)
  hook.run('PlayerInventoryUpdated', player)
end

function Currencies:CanPlayerPickupMoney(player, entity)
  if player.next_money_pickup and player.next_money_pickup > CurTime() then
    return false
  end

  if entity.next_pickup and entity.next_pickup > CurTime() then
    return false
  end
end

function Currencies:PlayerPickupMoney(player, entity)
  local currency = entity:get_currency()
  local amount = entity:get_currency_amount()
  local currency_data = Currencies:find_currency(currency)

  player:give_money(currency, amount)
  player.next_money_pickup = CurTime() + 0.5
  player:notify('currency.notify.pickup', { amount, currency_data.name }, Color('lightgreen'))
  entity:EmitSound('physics/cardboard/cardboard_box_impact_bullet'..math.random(1, 5)..'.wav', 55)
end

function Currencies:CanPlayerTransferMoney(player, amount, currency)
  if !amount or amount <= 0 then
    return false, 'currency.notify.invalid_amount'
  end

  local currency_data = Currencies:find_currency(currency)

  if !currency_data then
    return false, 'currency.notify.invalid_currency'
  end

  if !player:has_money(currency, amount) then
    return false, 'currency.notify.not_enough_money'
  end
end

function Currencies:CanPlayerDropMoney(player, amount, currency, pos, trace)
  local success, err = hook.run('CanPlayerTransferMoney', player, amount, currency)

  if success == false then
    return false, err
  end

  if pos:Distance(player:EyePos()) > 120 then
    return false, 'currency.notify.too_far'
  end

  if player.next_money_pickup and player.next_money_pickup > CurTime() then
    return false
  end
end

function Currencies:CanPlayerGiveMoney(player, target, amount, currency)
  local success, err = hook.run('CanPlayerTransferMoney', player, amount, currency)

  if success == false then
    return false, err
  end

  if !IsValid(target) then
    return false, 'currency.notify.invalid_entity'
  end

  if IsValid(target) then
    if !target:IsPlayer() then
      return false, 'currency.notify.invalid_entity'
    end

    if target:GetPos():Distance(player:EyePos()) > 120 then
      return false, 'currency.notify.too_far'
    end
  end
end

Cable.receive('fl_currency_give', function(player, amount, currency)
  local success, err = player:give_money_to(nil, currency, amount)

  if success == false then
    player:notify(err)
  end
end)

Cable.receive('fl_currency_drop', function(player, amount, currency)
  local success, err = player:drop_money(currency, amount)

  if success == false then
    player:notify(err)
  end
end)
