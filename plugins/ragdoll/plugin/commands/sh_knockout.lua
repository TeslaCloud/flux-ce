--- The `knockout` staff command: knocks the target players out, optionally for a set time.
-- A knocked out player cannot get up by themselves.

CMD.name = 'Knockout'
CMD.description = 'command.knockout.description'
CMD.syntax = 'command.knockout.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'plyknockout', 'forceknockout' }

--- Knocks every living target out, including the ones who are lying on the ground already,
-- with the caller as the attacker of the knockout hooks, and notifies the staff.
-- @param actor [Player the caller; not valid when run from the server console]
-- @param targets [List<Player> players to knock out]
-- @param delay=0 [String/Number seconds after which the targets come to, clamped between
--   0 and 600; with 0 they stay knocked out until someone gets them up]
function CMD:on_run(actor, targets, delay)
  delay = math.clamp(tonumber(delay) or 0, 0, 600)

  local options = { attacker = IsValid(actor) and actor or nil }

  for k, v in ipairs(targets) do
    if IsValid(v) and v:Alive() then
      v:knock_out(delay, options)
    end
  end

  self:notify_staff('command.knockout.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    time = delay
  })
end
