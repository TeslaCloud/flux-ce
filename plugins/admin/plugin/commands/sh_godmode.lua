COMMAND.name = 'SetGodmode'
COMMAND.description = 'command.godmode.description'
COMMAND.syntax = 'command.godmode.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.player_management'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'godmode', 'plysetgodmode' }

function COMMAND:on_run(player, targets, boolean)
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
