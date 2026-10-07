CMD.name = 'SetGodmode'
CMD.description = 'command.godmode.description'
CMD.syntax = 'command.godmode.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'godmode', 'plysetgodmode' }

--- Enables god mode for the targeted players, or toggles it when no truthy value is given,
-- and notifies them and staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to affect]
-- @param boolean=nil [String value read with tobool; truthy enables god mode, anything else
--   (or nothing) toggles it]
function CMD:on_run(actor, targets, boolean)
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
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
