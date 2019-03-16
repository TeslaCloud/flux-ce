local COMMAND = Command.new('vanish')
COMMAND.name = 'Vanish'
COMMAND.description = t'vanish.description'
COMMAND.syntax = t'vanish.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'v' }

function COMMAND:on_run(player, targets, should_vanish)
  local admin_name = get_player_name(player)

  for k, target in ipairs(targets) do
    should_vanish = should_vanish != nil and tobool(should_vanish) or !target.is_vanished

    local phrase = 'vanish.'..(should_vanish and 'enabled' or 'disabled')
    local target_name = target:name()

    target:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

    -- Make sure we are not interfering with observer.
    if !target:get_nv('observer') then
      if should_vanish then
        target.old_color = target:GetColor()

        target:DrawWorldModel(false)
        target:DrawShadow(false)
        target:SetNoDraw(true)
        target:SetNotSolid(true)
        target:SetColor(Color(0, 0, 0, 0))
      else
        target:DrawWorldModel(true)
        target:DrawShadow(true)
        target:SetNoDraw(false)
        target:SetNotSolid(false)
        target:SetColor(target.old_color)
      end
    end

    target:prevent_transmit_conditional(should_vanish, function(ply)
      if ply:can('moderator') then
        ply:notify_admin(phrase, { player_name = target_name, admin_name = admin_name })
        return false
      end
    end)

    target:notify('vanish.self', { state = 'vanish.'..(should_vanish and 'vanished' or 'unvanished') })

    target.is_vanished = should_vanish
  end
end

COMMAND:register()
