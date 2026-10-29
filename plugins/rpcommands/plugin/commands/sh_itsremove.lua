--- The `itsremove` command: removes the static text the caller is looking at.

CMD.name = 'Itsremove'
CMD.description = 'command.itsremove.description'
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

    local is_assistant = actor:is_assistant()

    for text_id, static_text in pairs(RPCommands.texts) do
      if hit_pos:DistToSqr(static_text.pos) <= 2500 and (static_text.steamid == steamid or is_assistant) then
        RPCommands.remove_static_text(text_id)
        actor:notify('notification.static_text.removed')

        Log:print(
          actor:Name(true)..' ('..steamid..') removed static text: '..tostring(static_text.text)..
          '; pos: '..tostring(static_text.pos),
          'player_action'
        )

        return
      end
    end
  end

  actor:notify('notification.static_text.not_found')
end
