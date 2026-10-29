--- Client side of the Voice Lines plugin: the Voice Lines page of the Help tab, which lists the
-- lines the character of the local player may use, lets the player listen to them and asks
-- the server to say them.

local available_cache = {}

--- Returns the lines the character of the local player may use, by category, like
-- `VoiceLines:get_available`. The list is kept for as long as the character, its faction, its
-- rank and the registered lines stay the same, so that the Voice Lines page does not check
-- every line again whenever it is drawn anew.
-- @return [List<Map> category (Map) and lines (List<Map>), see VoiceLines:get_available]
function VoiceLines:get_local_available()
  if !IsValid(PLAYER) then return {} end

  local key = table.concat({
    tostring(PLAYER:get_character_id()), tostring(PLAYER:get_faction_id()), tostring(PLAYER:get_rank()),
    tostring(self:get_gender(PLAYER)), tostring(self.version)
  }, '|')

  if available_cache.key != key then
    available_cache.key = key
    available_cache.value = self:get_available(PLAYER)
  end

  return available_cache.value
end

--- Plays the sound of a line to the local player only, in the variant of the gender of their
-- character.
-- @param line [Map]
function VoiceLines:preview(line)
  local sound_path = self:get_sound(line, self:get_gender(PLAYER))

  if isstring(sound_path) then
    surface.PlaySound(sound_path)
  end
end

--- Asks the server to make the character of the local player say a line, as if its text had
-- been typed into the chat. The server checks whether the character may use it.
-- @param category_id [String category ID]
-- @param line_id [String line ID]
function VoiceLines:request_say(category_id, line_id)
  Cable.send('fl_voice_line_say', category_id, line_id)
end

Flux.Help:add_page('voice_lines', {
  title = 'ui.voice_lines.title',
  component = 'voice_lines',
  priority = 30,
  visible = _page -> #VoiceLines:get_local_available() > 0
})
