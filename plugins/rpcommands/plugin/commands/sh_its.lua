--- The `its` command: places a static text that describes a detail of the surroundings and
-- stays there for everyone who comes near.

CMD.name = 'Its'
CMD.description = 'command.its.description'
CMD.syntax = 'command.its.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'action', 'itstatic', 'describe' }
CMD.arguments = 1
CMD.no_console = true

--- Places a static text at the player's position unless another one is within 50 units, with a 5 second cooldown.
-- @param actor [Player player running the command]
function CMD:on_run(actor, ...)
  local cur_time = CurTime()

  if actor.next_its and actor.next_its >= cur_time then
    actor:notify('error.wait')

    return
  end

  local pos = actor:GetPos()
  local text = table.concat({ ... }, ' '):chomp(' '):spelling()

  for k, v in pairs(RPCommands.texts) do
    if v.pos:DistToSqr(pos) <= 2500 then
      actor:notify('error.its_too_close')

      return
    end
  end

  local data = {
    pos = pos + Vector(0, 0, 30),
    text = text,
    name = actor:Name(true),
    steamid = actor:SteamID(),
    time = to_datetime(os.time())
  }

  RPCommands.add_static_text(data)

  actor.next_its = cur_time + 5
  actor:notify('notification.static_text.added')

  Log:print(
    actor:Name(true)..' ('..actor:SteamID()..') added static text: '..text..'; pos: '..tostring(pos),
    'player_action'
  )
end
