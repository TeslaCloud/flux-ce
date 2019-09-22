CMD.name = 'Vanish'
CMD.description = 'command.vanish.description'
CMD.syntax = 'command.vanish.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'v'

function CMD:on_run(player, targets, should_vanish)
  for k, v in ipairs(targets) do
    should_vanish = should_vanish != nil and tobool(should_vanish) or !v.is_vanished

    v:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

    -- Make sure we are not interfering with observer.
    if !v:get_nv('observer') then
      if should_vanish then
        v.old_color = v:GetColor()

        v:DrawWorldModel(false)
        v:DrawShadow(false)
        v:SetNoDraw(true)
        v:SetNotSolid(true)
        v:SetColor(Color(0, 0, 0, 0))
      else
        v:DrawWorldModel(true)
        v:DrawShadow(true)
        v:SetNoDraw(false)
        v:SetNotSolid(false)
        v:SetColor(v.old_color)
      end
    end

    v:prevent_transmit_conditional(should_vanish, function(ply)
      if ply:can('moderator') then
        return false
      end
    end)

    v:notify('notification.vanish.'..(should_vanish and 'enabled' or 'disabled'))

    v.is_vanished = should_vanish
  end

  self:notify_staff('command.vanish.'..(should_vanish and 'enabled' or 'disabled'), {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
