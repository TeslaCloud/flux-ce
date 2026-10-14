--- The `itsremove` command: removes the static text the caller is looking at.

CMD.name = 'Itsremove'
CMD.description = 'command.itsremove.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = {
  'removedescribe',
  'describeremove',
  'actionremove',
  'removeaction',
  'itstaticremove',
  'removeits',
  'removeitstatic'
}
CMD.no_console = true

--- Removes the static text the player is looking at if they placed it or are staff.
-- @param actor [Player player running the command]
function CMD:on_run(actor)
  local trace = actor:GetEyeTraceNoCursor()

  if trace.Hit then
    local hit_pos = trace.HitPos
    local steamid = actor:SteamID()

    for k, v in pairs(RPCommands.texts) do
      if hit_pos:DistToSqr(v.pos) <= 2500 and (v.steamid == steamid or actor:is_assistant()) then
        RPCommands.remove_static_text(k)
        actor:notify('notification.static_text.removed')

        Log:print(
          actor:Name(true)..' ('..steamid..') removed static text: '..tostring(v.text)..
          '; pos: '..tostring(v.pos),
          'player_action'
        )

        return
      end
    end
  end

  actor:notify('notification.static_text.not_found')
end
