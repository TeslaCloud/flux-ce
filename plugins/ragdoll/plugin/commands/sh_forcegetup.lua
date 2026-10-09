--- The `forcegetup` staff command: makes the fallen or knocked out target players get up,
-- optionally after a delay.

CMD.name = 'ForceGetUp'
CMD.description = 'command.forcegetup.description'
CMD.syntax = 'command.forcegetup.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'forcegetup', 'plygetup' }

--- Makes every living, ragdolled target get up, and notifies the staff. With a delay the
-- targets are given a get up timer, which replaces the one they have; without one they get
-- up right away.
-- @param actor [Player the caller; not valid when run from the server console]
-- @param targets [List<Player> players to get up]
-- @param delay=0 [String/Number seconds before the targets get up, clamped between
--   0 and 60]
function CMD:on_run(actor, targets, delay)
  delay = math.clamp(tonumber(delay) or 0, 0, 60)

  for k, v in ipairs(targets) do
    if IsValid(v) and v:Alive() and v:is_ragdolled() then
      if delay <= 0 or !v:set_getup_time(delay) then
        v:set_ragdoll_state(RAGDOLL_NONE)
      end
    end
  end

  self:notify_staff('command.forcegetup.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = delay
  })
end
