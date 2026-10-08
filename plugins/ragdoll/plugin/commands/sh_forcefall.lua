--- The `forcefall` staff command: makes the target players fall over, and optionally get back
-- up after a delay.

CMD.name = 'ForceFall'
CMD.description = 'command.forcefall.description'
CMD.syntax = 'command.forcefall.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'forcefallover', 'plyfall' }

--- Makes every living target that is not ragdolled fall over, and notifies the staff.
-- @param actor [Player the caller; not valid when run from the server console]
-- @param targets [List<Player> players to knock down]
-- @param delay=0 [String/Number seconds to pass to the targets' getup command, clamped
--   between 0 and 60; with 0 they stay down until they get up themselves]
function CMD:on_run(actor, targets, delay)
  delay = math.clamp(tonumber(delay) or 0, 0, 60)

  for k, v in ipairs(targets) do
    if IsValid(v) and v:Alive() and !v:is_ragdolled() then
      v:set_ragdoll_state(RAGDOLL_FALLENOVER)

      if delay > 0 then
        v:run_command('getup '..tostring(delay))
      end
    end
  end

  self:notify_staff('command.forcefall.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = delay
  })
end
