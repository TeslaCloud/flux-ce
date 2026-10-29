--- Network handlers of the turn based combat on the client: the turns, the turn order, the
-- messages and the end of a combat.

Cable.receive('fl_combat_notify_turn', function(entity)
  local text = t('notification.combat.turn', { entity = t(entity:get_name()) })
  local sound_path = 'ui/freeze_cam.wav'

  if entity == PLAYER then
    text = t'notification.combat.your_turn'
    sound_path = 'ui/achievement_earned.wav'
  end

  PLAYER:EmitSound(sound_path, 75, 100, 0.5)
  CombatSystem:create_notify(text)
end)

Cable.receive('fl_combat_notify_finish', function()
  PLAYER:EmitSound('ui/achievement_earned.wav', 75, 100, 0.5)
  CombatSystem:create_notify(t('notification.combat.finish'))
end)

Cable.receive('fl_combat_message', function(text, arguments)
  CombatSystem:create_message(text, arguments)
end)

Cable.receive('fl_combat_turn_order', function(order)
  timer.Simple(0, function()
    CombatSystem:create_message('notification.combat.turn_order')

    for _k, v in pairs(order) do
      timer.Simple(0, function()
        CombatSystem:create_message('{entity} - {initiative}', { entity = v.entity, initiative = v.initiative })
      end)
    end
  end)
end)

Cable.receive('fl_combat_update_pos', function(pos)
  PLAYER.walk_pos = pos
  chat.PlaySound()
end)

Cable.receive('fl_combat_end_turn', function()
  PLAYER.walk_pos = nil
  PLAYER.turn_end = nil
end)

Cable.receive('fl_combat_start_turn', function(pos)
  PLAYER.walk_pos = pos
  PLAYER.turn_end = CurTime() + 60
end)
