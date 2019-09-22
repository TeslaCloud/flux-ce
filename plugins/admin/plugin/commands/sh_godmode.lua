CMD.name = 'SetGodmode'
CMD.description = 'command.godmode.description'
CMD.syntax = 'command.godmode.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'godmode', 'plysetgodmode' }

function CMD:on_run(player, targets, boolean)
  for k, v in ipairs(targets) do
    boolean = boolean != nil and tobool(boolean) or !v:HasGodMode()

    if boolean then
      v:GodEnable()
    else
      v:GodDisable()
    end

    v:notify('notification.godmode.'..(boolean and 'enabled' or 'disabled'))
  end

  self:notify_staff('command.godmode.'..(boolean and 'enabled' or 'disabled'), {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
