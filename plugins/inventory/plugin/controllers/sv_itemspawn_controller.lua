MVC.handler('SpawnMenu::SpawnItem', function(player, item_id)
  if !player:can('spawn_items') then
    player:notify('error.no_permission')

    return
  end

  local item_obj = Item.create(item_id)

  if item_obj then
    local trace = player:GetEyeTraceNoCursor()

    local entity = Item.spawn(trace.HitPos, nil, item_obj)

    undo.create('item')
      undo.add_entity(entity)
      undo.set_player(player)
      undo.set_custom_undo_text('Undone '..t(item_obj:get_real_name()))
    undo.finish()
  end
end)

MVC.handler('SpawnMenu::GiveItem', function(player, target, item_id, amount)
  if !player:can('give_items') then
    player:notify('error.no_permission')

    return
  end

  local item_obj = Item.find(item_id)

  local success, error_text = target:give_item(item_id, amount)

  if success then
    target:notify('notification.item_given', {
      amount = amount,
      item = item_obj.name
    })
  else
    player:notify(error_text)
  end
end)
