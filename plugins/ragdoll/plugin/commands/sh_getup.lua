--- The `getup` command: the fallen caller gets back up after a delay, during which they see a
-- progress bar.

CMD.name = 'GetUp'
CMD.description = 'command.getup.description'
CMD.syntax = 'command.getup.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'chargetup', 'unfall', 'unfallover' }
CMD.no_console = true

--- Makes the fallen player start getting up, showing them a progress bar until they are
-- back on their feet. Notifies the player instead if they cannot: they are dead, not fallen
-- over, knocked out, already getting up, or kept down by the PlayerCanGetUp hook.
-- @param actor [Player the caller]
-- @param delay=nil [String/Number seconds it takes to get up, clamped between the
--   ragdoll_getup_time config and 60]
function CMD:on_run(actor, delay)
  if !actor:get_up(delay) then
    actor:notify('error.cant_now')
  end
end
