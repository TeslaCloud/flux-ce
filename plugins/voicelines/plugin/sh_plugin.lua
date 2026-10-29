--- Voice Lines lets characters say the recorded lines of their faction. A line has a command,
-- a text, optional aliases and a sound, which can differ by gender. When a character says in
-- character nothing but the command, the text or an alias of a line they may use, ignoring
-- letter case and the punctuation at the end, the chat shows the text of the line and the
-- sound plays from the speaker for everyone who hears the message. Whispers and yells keep
-- their volume. Only a whole message says a line, so a phrase that merely starts with a
-- command is ordinary speech. Over the radio the text is sent as usual, the players near the
-- speaker hear the sound from the speaker and the listeners on the frequency hear it quieter,
-- as if from their own radio.
--
-- Lines are grouped into categories, and a category names the factions whose members may use
-- its lines, and optionally the rank they need in a faction. The plugin has no lines of its
-- own: the schema and other plugins add categories and lines from the `RegisterVoiceLines`
-- hook, out of a YAML file with `VoiceLines:load_file`, which documents the format, or with
-- `VoiceLines:register_category` and `VoiceLines:register_line`:
-- ```
-- function PLUGIN:RegisterVoiceLines(voice_lines)
--   voice_lines:register_category('rebels', {
--     name = 'ui.voice_lines.category.rebels',
--     order = 60,
--     factions = { 'rebel' }
--   })
--
--   voice_lines:register_line('rebels', 'lambda', {
--     sound = { male = 'vo/npc/male01/freeman.wav', female = 'vo/npc/female01/freeman.wav' },
--     text = 'Freeman!',
--     aliases = { 'gordon' }
--   })
--
--   -- A line can be added to a category of another plugin or of the schema as well.
--   voice_lines:register_line('citizens', 'overhere', {
--     sound = { male = 'vo/npc/male01/overhere01.wav', female = 'vo/npc/female01/overhere01.wav' },
--     text = 'Over here!'
--   })
-- end
-- ```
-- The `PlayerCanUseVoiceLine` hook overrides who may use a line, and `VoiceLinePlayed` is run on
-- the server every time the sound of a line plays. Players find the lines they may use on the
-- Voice Lines page of the Help tab, where they can listen to a line or say it, and with the
-- `voicelines` command. A player can play a voice line once per 'voicelines_interval' config;
-- a line said sooner shows its text without the sound.
-- @module [VoiceLines]

PLUGIN:set_global('VoiceLines')

local isstring = isstring
local istable = istable

VoiceLines.categories = {}

local categories = VoiceLines.categories
local index = {}
local index_dirty = true

VoiceLines.version = (VoiceLines.version or 0) + 1

--- Notes that the categories or the lines have changed: the lookup table is built again on
-- the next match, and `VoiceLines.version` goes up, so that lists kept from before can tell
-- that they are out of date.
local function mark_changed()
  index_dirty = true
  VoiceLines.version += 1
end

--- Turns a sound path of a line into a path relative to the sound folder.
-- @param path [String path, with or without the leading 'sound/' folder]
-- @return [String path, or nil if it is not a string that is not empty]
local function clean_sound(path)
  if !isstring(path) then return end

  path = path:strip():gsub('\\', '/')

  if path:start_with('sound/') then
    path = path:sub(7)
  end

  if path == '' then return end

  return path
end

--- Turns the sound or the text of a line into a string or a map of gender to string.
-- @param value [String/Map the value of the line definition]
-- @param cleaner=nil [Function applied to every string]
-- @return [String/Map the value, or nil if it holds no string]
local function clean_variants(value, cleaner)
  if isstring(value) then
    if cleaner then return cleaner(value) end

    value = value:strip()

    return value != '' and value or nil
  end

  if !istable(value) then return end

  local variants = {}
  local found = false

  for gender, variant in pairs(value) do
    variant = clean_variants(variant, cleaner)

    if isstring(gender) and isstring(variant) then
      variants[gender] = variant
      found = true
    end
  end

  return found and variants or nil
end

--- Picks the variant of a sound or text for a gender: that gender, else 'male', else any.
-- @param value [String/Map the sound or the text of a line]
-- @param gender=nil [String 'male', 'female' or 'no_gender']
-- @return [String]
local function pick_variant(value, gender)
  if !istable(value) then return value end

  if isstring(gender) and value[gender] then
    return value[gender]
  end

  if value.male then return value.male end

  for _gender, variant in SortedPairs(value) do
    return variant
  end
end

--- Returns the gender of a player's character for picking the variant of a line.
-- @param target [Player]
-- @return [String 'male', 'female' or 'no_gender']
function VoiceLines:get_gender(target)
  if !IsValid(target) or !isfunction(target.get_gender) then return 'no_gender' end
  if SERVER and !target:get_character() then return 'no_gender' end

  return target:get_gender() or 'no_gender'
end

--- Turns a message into the form it is matched in: lower case, single spaces, and without
-- the punctuation and the quotes at its ends.
-- ```
-- VoiceLines:normalize('  Try not to dwell on it... ') -- 'try not to dwell on it'
-- VoiceLines:normalize('Dwell?!') -- 'dwell'
-- ```
-- @param text [String]
-- @return [String an empty string if nothing is left or if the text is not a string]
function VoiceLines:normalize(text)
  if !isstring(text) then return '' end

  text = text:utf8lower():gsub('\226\128\152', "'"):gsub('\226\128\153', "'"):gsub('%s+', ' ')

  local previous

  repeat
    previous = text
    text = text:strip()
      :gsub('^[\'"]+', ''):gsub('^\194[\161\191]', '')
      :gsub('[%.,!%?;:%-\'"]+$', ''):gsub('\226\128\166$', '')
  until text == previous

  return text
end

--- Checks whether the text of a line is an action, which starts and ends with an asterisk.
-- @param text [String]
-- @return [Boolean]
function VoiceLines:is_action(text)
  return isstring(text) and text:start_with('*') and text:end_with('*')
end

--- Adds a category of voice lines, or changes a category that exists: the fields that are
-- given replace its own, and the lines are added to its lines.
-- @param id [String unique ID of the category]
-- @param data [Map name (String language phrase or text, the ID by default), order (Number
--   categories with a lower order are listed and matched first, 100 by default), factions
--   (List<String> IDs of the factions whose members may use the lines; a category without
--   factions is open to every character), ranks (Map faction ID to the ID of the rank that
--   members of that faction need at least) and lines (Map line ID to line data, see
--   `VoiceLines:register_line`)]
-- @return [Map the category, or nil if the ID or the data are not valid]
function VoiceLines:register_category(id, data)
  if !isstring(id) or id == '' or !istable(data) then
    ErrorNoHalt(
      "[Flux - Voice Lines] Not adding the '"..tostring(id).."' category! Its ID or its data are not valid!\n"
    )

    return
  end

  local category = categories[id] or { id = id, name = id, order = 100, factions = {}, ranks = {}, lines = {} }

  if isstring(data.name) and data.name != '' then
    category.name = data.name
  end

  if tonumber(data.order) then
    category.order = tonumber(data.order)
  end

  if istable(data.factions) then
    category.factions = {}

    for _k, faction_id in ipairs(data.factions) do
      if isstring(faction_id) then
        table.insert(category.factions, faction_id)
      end
    end
  end

  if istable(data.ranks) then
    category.ranks = {}

    for faction_id, rank_id in pairs(data.ranks) do
      if isstring(faction_id) and isstring(rank_id) then
        category.ranks[faction_id] = rank_id
      end
    end
  end

  categories[id] = category
  mark_changed()

  if istable(data.lines) then
    for line_id, line_data in pairs(data.lines) do
      self:register_line(id, line_id, line_data)
    end
  end

  return category
end

--- Adds a voice line to a category, or replaces the line of that category with the same ID.
-- @param category_id [String ID of a category that has been added]
-- @param id [String the command that says the line, unique within the category]
-- @param data [Map sound (String path relative to the sound folder, or Map of gender
--   ('male', 'female') to path), text (String what the character says, or Map of gender to
--   text; a text between asterisks is said as an action) and aliases (List<String> other
--   phrases that say the line, optional)]
-- @return [Map the line, or nil if the category does not exist or the data are not valid]
function VoiceLines:register_line(category_id, id, data)
  local category = categories[category_id]

  if !category or !isstring(id) or id == '' or !istable(data) then
    ErrorNoHalt(
      "[Flux - Voice Lines] Not adding the '"..tostring(id).."' line to the '"..tostring(category_id)..
        "' category! The category does not exist, or the ID or the data of the line are not valid!\n"
    )

    return
  end

  local sound_variants = clean_variants(data.sound, clean_sound)
  local text = clean_variants(data.text)

  if !sound_variants or !text then
    ErrorNoHalt(
      "[Flux - Voice Lines] Not adding the '"..id.."' line to the '"..category_id..
        "' category! It needs a sound and a text!\n"
    )

    return
  end

  local aliases = {}

  if istable(data.aliases) then
    for _k, alias in ipairs(data.aliases) do
      if isstring(alias) and alias:strip() != '' then
        aliases[#aliases + 1] = alias:strip()
      end
    end
  end

  local line = { id = id, category = category_id, sound = sound_variants, text = text, aliases = aliases }

  category.lines[id] = line
  mark_changed()

  return line
end

--- Removes a category with all of its lines.
-- @param id [String category ID]
function VoiceLines:remove_category(id)
  categories[id] = nil
  mark_changed()
end

--- Removes a line from a category.
-- @param category_id [String category ID]
-- @param id [String line ID]
function VoiceLines:remove_line(category_id, id)
  local category = categories[category_id]

  if category then
    category.lines[id] = nil
    mark_changed()
  end
end

--- Returns a category.
-- @param id [String category ID]
-- @return [Map the category, nil if there is none with that ID]
function VoiceLines:find_category(id)
  return categories[id]
end

--- Returns a line of a category.
-- @param category_id [String category ID]
-- @param id [String line ID]
-- @return [Map the line, nil if there is none]
function VoiceLines:find_line(category_id, id)
  local category = categories[category_id]

  return category and category.lines[id] or nil
end

local function category_before(a, b)
  if a.order != b.order then
    return a.order < b.order
  end

  return a.id < b.id
end

--- Returns every category in the order they are listed and matched in.
-- @return [List<Map> categories: id, name, order, factions, ranks and lines]
function VoiceLines:get_categories()
  local list = {}

  for _id, category in pairs(categories) do
    list[#list + 1] = category
  end

  table.sort(list, category_before)

  return list
end

--- Returns the lines of a category, sorted by their IDs.
-- @param category [Map/String the category or its ID]
-- @return [List<Map> lines: id, category (the ID of the category), sound, text and aliases]
function VoiceLines:get_lines(category)
  if isstring(category) then
    category = categories[category]
  end

  local list = {}

  if !category then return list end

  for _id, line in pairs(category.lines) do
    list[#list + 1] = line
  end

  table.sort(list, |a, b| -> a.id < b.id)

  return list
end

--- Counts the categories and the lines.
-- @return [Number categories, Number lines]
function VoiceLines:count()
  local category_count, line_count = 0, 0

  for _id, category in pairs(categories) do
    category_count += 1
    line_count += table.Count(category.lines)
  end

  return category_count, line_count
end

--- Returns the sound of a line for a gender: the sound of that gender, else the male one,
-- else any.
-- @param line [Map]
-- @param gender=nil [String 'male', 'female' or 'no_gender']
-- @return [String path relative to the sound folder]
function VoiceLines:get_sound(line, gender)
  return pick_variant(line.sound, gender)
end

--- Returns the text of a line for a gender: the text of that gender, else the male one, else
-- any.
-- @param line [Map]
-- @param gender=nil [String 'male', 'female' or 'no_gender']
-- @return [String]
function VoiceLines:get_text(line, gender)
  return pick_variant(line.text, gender)
end

--- Checks whether a player belongs to the factions of a category and holds the rank it
-- requires in their faction, if any.
-- @param target [Player]
-- @param category [Map]
-- @return [Boolean true as well for a category without factions]
function VoiceLines:is_member(target, category)
  local factions = category.factions

  if !istable(factions) or #factions == 0 then return true end

  local faction_id = target:get_faction_id()

  if !table.HasValue(factions, faction_id) then return false end

  local rank_id = category.ranks and category.ranks[faction_id]

  if isstring(rank_id) then
    return target:is_rank(rank_id)
  end

  return true
end

--- Checks whether a player may use a line, or the lines of a category. Runs on both realms;
-- the server decides.
-- @param target [Player]
-- @param category [Map/String the category or its ID]
-- @param line=nil [Map/String the line or its ID; without it the category as a whole is
--   checked]
-- @return [Boolean]
function VoiceLines:can_use(target, category, line)
  if !IsValid(target) or !target:IsPlayer() then return false end

  if isstring(category) then
    category = categories[category]
  end

  if !category then return false end

  if isstring(line) then
    line = category.lines[line]

    if !line then return false end
  end

  --- Decides whether a player may use a voice line. Called on both realms: on the server
  -- before a line is said, on the client to list the lines on the Voice Lines page.
  -- @param target [Player the player]
  -- @param category [Map the category: id, name, order, factions, ranks and lines]
  -- @param line [Map the line (id, category, sound, text and aliases), nil when the whole
  --   category is being checked]
  -- @return [Boolean return false to forbid the line, true to allow it whatever the factions
  --   and ranks of the category; nothing leaves the decision to them]
  local allowed = hook.Run('PlayerCanUseVoiceLine', target, category, line)

  if allowed != nil then
    return allowed == true
  end

  return self:is_member(target, category)
end

--- Builds the lookup table of the commands, the texts and the aliases of all lines, so that
-- a message is matched without going through every line. A phrase that belongs to several
-- lines goes to the command of a line first, then to a text, then to an alias, and among
-- equals to the category that comes first and then to the line ID that sorts first. A text
-- that is an action is left out, as a message that is an action never says a line.
local function build_index()
  index = {}

  local function add(phrase, line, category, kind)
    phrase = VoiceLines:normalize(phrase)

    if phrase == '' then return end

    local entries = index[phrase] or {}

    for _k, entry in ipairs(entries) do
      if entry.line == line then
        entry.kind = math.min(entry.kind, kind)

        return
      end
    end

    entries[#entries + 1] = { line = line, category = category, kind = kind }
    index[phrase] = entries
  end

  for _id, category in pairs(categories) do
    for line_id, line in pairs(category.lines) do
      add(line_id, line, category, 1)

      local texts = istable(line.text) and line.text or { line.text }

      for _key, text in pairs(texts) do
        if !VoiceLines:is_action(text) then
          add(text, line, category, 2)
        end
      end

      for _k, alias in ipairs(line.aliases) do
        add(alias, line, category, 3)
      end
    end
  end

  for _phrase, entries in pairs(index) do
    table.sort(entries, function(a, b)
      if a.kind != b.kind then
        return a.kind < b.kind
      end

      if a.category != b.category then
        return category_before(a.category, b.category)
      end

      return a.line.id < b.line.id
    end)
  end

  index_dirty = false
end

--- Finds the line that a message says for a player: the first line they may use whose
-- command, text (of any gender, unless it is an action) or alias is the whole message, see
-- `VoiceLines:normalize`.
-- ```
-- local line, category = VoiceLines:match(actor, 'Dwell!')
-- ```
-- @param target [Player the speaker]
-- @param text [String the message, without any markup]
-- @param no_actions=false [Boolean leave out the lines whose text is an action]
-- @return [Map the line, Map its category; nothing if the message does not say a line]
function VoiceLines:match(target, text, no_actions)
  if index_dirty then
    build_index()
  end

  local entries = index[self:normalize(text)]

  if !entries then return end

  local gender = self:get_gender(target)

  for _k, entry in ipairs(entries) do
    local line, category = entry.line, entry.category

    if (!no_actions or !self:is_action(self:get_text(line, gender))) and self:can_use(target, category, line) then
      return line, category
    end
  end
end

--- Returns the lines a player may use, by category.
-- @param target [Player]
-- @return [List<Map> in the order of the categories: category (Map) and lines (List<Map>
--   sorted by ID); categories without a line the player may use are left out]
function VoiceLines:get_available(target)
  local available = {}

  for _k, category in ipairs(self:get_categories()) do
    local lines = {}

    for _k2, line in ipairs(self:get_lines(category)) do
      if self:can_use(target, category, line) then
        lines[#lines + 1] = line
      end
    end

    if #lines > 0 then
      available[#available + 1] = { category = category, lines = lines }
    end
  end

  return available
end

--- Checks whether a line contains a search query in its command, its text or its aliases,
-- ignoring letter case.
-- @param line [Map]
-- @param query [String lower case query, an empty one matches every line]
-- @return [Boolean]
function VoiceLines:line_matches_query(line, query)
  if !isstring(query) or query == '' then return true end

  local function has(value)
    return isstring(value) and value:utf8lower():find(query, 1, true) != nil
  end

  if has(line.id) then return true end

  if istable(line.text) then
    for _gender, text in pairs(line.text) do
      if has(text) then return true end
    end
  elseif has(line.text) then
    return true
  end

  for _k, alias in ipairs(line.aliases) do
    if has(alias) then return true end
  end

  return false
end

--- Returns the lines a player may use that contain a search query.
-- @param target [Player]
-- @param query=nil [String text to look for in the commands, the texts and the aliases,
--   letter case is ignored; every line matches without it]
-- @return [List<Map> category (Map) and line (Map) of every match, in the order of the
--   categories and then of the line IDs]
function VoiceLines:search(target, query)
  query = isstring(query) and query:strip():utf8lower() or ''

  local results = {}

  for _k, group in ipairs(self:get_available(target)) do
    for _k2, line in ipairs(group.lines) do
      if self:line_matches_query(line, query) then
        results[#results + 1] = { category = group.category, line = line }
      end
    end
  end

  return results
end

--- Adds the categories and lines of a data table: a categories map of category ID to
-- category data, see `VoiceLines:register_category`.
-- @param data [Map the data, nothing is added if it is not a table]
function VoiceLines:load_data(data)
  if !istable(data) or !istable(data.categories) then return end

  for id, category_data in pairs(data.categories) do
    self:register_category(id, category_data)
  end
end

local function read_file(path)
  local contents = file.Read(path, 'LUA')

  if !contents then
    ErrorNoHalt('[Flux - Voice Lines] Unable to read '..path..'!\n')

    return
  end

  local success, data = pcall(YAML.eval, contents)

  if !success or !istable(data) then
    ErrorNoHalt('[Flux - Voice Lines] Unable to parse '..path..': '..tostring(data)..'\n')

    return
  end

  return data
end

--- Adds the categories and lines of a YAML file. The server reads the file and passes what it
-- holds on to the clients through `Flux.shared`, so the file is loaded on both realms with
-- the same path, from the `RegisterVoiceLines` hook, which runs before the shared data is
-- sent to the clients. The file holds a `categories` map of category ID to the fields of
-- `VoiceLines:register_category`, and every category a `lines` map of the command that says
-- a line to the fields of `VoiceLines:register_line`:
-- ```
-- function SCHEMA:RegisterVoiceLines(voice_lines)
--   voice_lines:load_file(self:get_path()..'/voicelines.yml')
-- end
-- ```
-- ```yaml
-- categories:
--   citizens:
--     name: ui.voice_lines.category.citizens
--     order: 10
--     factions:
--       - citizen
--     lines:
--       dwell:
--         sound:
--           male: vo/npc/male01/answer04.wav
--           female: vo/npc/female01/answer04.wav
--         text: Try not to dwell on it.
--         aliases:
--           - dwell on it
-- ```
-- @param path [String path of the file in the Lua search path, such as
--   'myschema/voicelines.yml']
-- @return [Boolean true if the file has been read]
function VoiceLines:load_file(path)
  local files = Flux.shared.voice_line_files

  if SERVER then
    files = files or {}
    files[path] = read_file(path)
    Flux.shared.voice_line_files = files
  end

  local data = files and files[path]

  self:load_data(data)

  return data != nil
end

--- Lets the other plugins and the schema add their categories and lines once all of them are
-- loaded, and logs how many there are in development.
function VoiceLines:OnSchemaLoaded()
  --- Lets plugins and the schema add voice line categories and lines with
  -- `VoiceLines:load_file`, `VoiceLines:register_category` and `VoiceLines:register_line`.
  -- Called on both realms once all plugins and the schema have been loaded, and again on
  -- every code refresh, before the shared data is sent to the clients. Do not return
  -- anything from the handler, or the plugins after it are not asked.
  -- @param voice_lines [Map the VoiceLines library]
  hook.Run('RegisterVoiceLines', self)

  local category_count, line_count = self:count()

  Flux.dev_print('Loaded '..line_count..' voice lines in '..category_count..' categories.')
end

require_relative 'cl_plugin'
require_relative 'cl_nethooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
require_relative 'sv_nethooks'
