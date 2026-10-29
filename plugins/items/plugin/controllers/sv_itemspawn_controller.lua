--- Server-side handlers of the items tab of the spawn menu.
-- `SpawnMenu::SpawnItem` creates an item and spawns it where the player is looking, which
-- requires the `spawn_items` permission. `SpawnMenu::GiveItem` gives a number of items
-- to a player, which requires the `give_items` permission.

MVC.handler('SpawnMenu::SpawnItem', function(actor, item_id)
  if !actor:can('spawn_items') then
    actor:notify('error.no_permission')

    return
  end

  local item_obj = Item.create(item_id)

  if item_obj then
    local trace = actor:GetEyeTraceNoCursor()

    local entity = Item.spawn(trace.HitPos, nil, item_obj)

    undo.Create('item')
      undo.AddEntity(entity)
      undo.SetPlayer(actor)
      undo.SetCustomUndoText('Undone '..t(item_obj:get_real_name()))
    undo.Finish()
  end
end)

MVC.handler('SpawnMenu::GiveItem', function(actor, target, item_id, amount)
  if !actor:can('give_items') then
    actor:notify('error.no_permission')

    return
  end

  if !IsValid(target) or !target:IsPlayer() then return end

  local item_obj = isstring(item_id) and Item.find_by_id(item_id)

  if !item_obj then return end

  amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, item_obj.max_stack or 1)

  local success, error_text = target:give_item(item_obj.id, amount)

  if success then
    target:notify('notification.item_given', {
      amount = amount,
      item = item_obj.name
    })
  else
    actor:notify(error_text)
  end
end)
