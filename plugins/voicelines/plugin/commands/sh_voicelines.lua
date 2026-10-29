--- The `voicelines` command: lists in the chat the voice lines the character of the player may
-- use whose command, text or alias contains the search text, or how many lines there are by
-- category without one. The full list is on the Voice Lines page of the Help tab.

CMD.name = 'VoiceLines'
CMD.description = 'command.voicelines.description'
CMD.syntax = 'command.voicelines.syntax'
CMD.category = 'permission.categories.roleplay'
CMD.aliases = { 'voices', 'vl' }
CMD.arguments = 0
CMD.arg_types = { 'text' }
CMD.no_console = true
CMD.permission = 'user'

local max_results = 15

--- Lists the matching voice lines to the player, in their language.
-- @param actor [Player player running the command]
-- @param query=nil [String text to search for]
function CMD:on_run(actor, query)
  local lang = Flux.Lang:get_player_lang(actor)
  local header_color = Color(150, 200, 255)
  local dim = Color(180, 180, 180)

  query = isstring(query) and query:strip() or ''

  if query == '' then
    local available = VoiceLines:get_available(actor)

    if #available == 0 then
      actor:notify('notification.voice_lines.none')

      return
    end

    Chatbox.add_text(actor, header_color, t('ui.voice_lines.list_header', nil, lang))

    for _k, group in ipairs(available) do
      Chatbox.add_text(actor, Color(255, 255, 255), t(group.category.name, nil, lang)..': ',
        dim, t('ui.voice_lines.line_count', { count = #group.lines }, lang))
    end

    return
  end

  local results = VoiceLines:search(actor, query)

  if #results == 0 then
    actor:notify('notification.voice_lines.not_found', { query = query })

    return
  end

  Chatbox.add_text(actor, header_color,
    t('ui.voice_lines.results', { count = #results, shown = math.min(#results, max_results) }, lang))

  local gender = VoiceLines:get_gender(actor)

  for i = 1, math.min(#results, max_results) do
    local result = results[i]

    Chatbox.add_text(actor, Color(255, 220, 120), result.line.id, Color(255, 255, 255), ' - ',
      VoiceLines:get_text(result.line, gender), dim, ' ('..t(result.category.name, nil, lang)..')')
  end
end
