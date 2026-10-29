--- Server side of the bans: the ban records in the database and in the ban cache, the time
-- a ban has left, the message a banned player is shown when they are kicked or turned away,
-- and the pages of bans sent to the ban list page of the admin panel.
-- Only players with the permission of the Ban command (`ban`) are told when a ban is added
-- or lifted, so that an open page can refresh itself.

local IsValid = IsValid
local isstring = isstring
local os_time = os.time

local bans = Bolt.bans
local bans_per_page = 25
local max_reason_length = 512
local max_search_length = 256

Cable.check_networked_string('fl_bolt_bans')
Cable.check_networked_string('fl_bolt_bans_changed')

--- Creates or updates the ban record for a SteamID, saves it to the database and caches it.
-- Runs the OnBanAdded hook afterwards.
-- @warning [Internal] Use Bolt:ban to ban somebody.
-- @param steam_id [String SteamID of the banned player]
-- @param name [String name stored with the ban]
-- @param unban_time [Number unix timestamp at which the ban ends]
-- @param duration [Number ban length in seconds, 0 for a permanent ban]
-- @param reason [String]
-- @param admin=nil [Player the player who issued the ban; nothing is stored for the server
--   console or for a ban made by code]
-- @return [Ban the saved ban record]
function Bolt:add_ban(steam_id, name, unban_time, duration, reason, admin)
  local obj = bans[steam_id] or Ban.new()
    obj.name = name
    obj.steam_id = steam_id
    obj.reason = reason
    obj.duration = duration
    obj.unban_time = to_datetime(unban_time)
    obj.admin_name = IsValid(admin) and admin:steam_name() or nil
    obj.admin_steam_id = IsValid(admin) and admin:SteamID() or nil
  self:record_ban(steam_id, obj:save())

  --- Called on the server after a ban has been created or an existing ban of the same
  -- SteamID has been replaced, when the record is in the ban cache and is being saved.
  -- @param steam_id [String SteamID that has been banned]
  -- @param ban [Ban The ban record: name, steam_id, reason, duration (seconds, 0 for a
  --   permanent ban), unban_time, admin_name and admin_steam_id]
  hook.Run('OnBanAdded', steam_id, obj)

  return obj
end

--- Puts a ban record into the ban cache without touching the database.
-- @param id [String SteamID the ban belongs to]
-- @param obj [Ban]
function Bolt:record_ban(id, obj)
  bans[id] = obj
end

--- Bans a player or a SteamID and saves the ban to the database. The banned player is
-- kicked if they are on the server, whether they were given as a player or as a SteamID,
-- unless prevent_kick is set. The owner of the SteamID does not have to be on the server,
-- or to have ever joined it.
-- ```
-- -- Ban an online player for a day.
-- Bolt:ban(target, 60 * 60 * 24, 'Prop spam')
-- -- Permanently ban somebody by SteamID, on behalf of an admin.
-- Bolt:ban('STEAM_0:1:12345', 0, 'Cheating', false, actor)
-- ```
-- @param target [Player/String the player to ban, or a SteamID]
-- @param duration=0 [Number ban length in seconds, 0 for a permanent ban]
-- @param reason='N/A' [String text or language phrase]
-- @param prevent_kick=false [Boolean do not kick the banned player]
-- @param admin=nil [Player the player who issues the ban, stored with it]
-- @param name=nil [String name to store with the ban of a SteamID whose owner is not on
--   the server; the name of an earlier ban of that SteamID or else the SteamID itself by
--   default]
-- @return [Ban the ban record, or nil if target is neither a valid player nor a string]
function Bolt:ban(target, duration, reason, prevent_kick, admin, name)
  if !isstring(target) and !IsValid(target) then return end

  duration = duration or 0
  reason = reason or 'N/A'

  local steam_id = target

  if isstring(target) then
    local online = player.is_steam_id(target) and player.find(target)

    if IsValid(online) then
      target = online
    else
      name = name or (bans[steam_id] and bans[steam_id].name) or steam_id
    end
  end

  if !isstring(target) then
    name = target:steam_name()
    steam_id = target:SteamID()
  end

  local obj = self:add_ban(steam_id, name, os_time() + duration, duration, reason, admin)

  if !isstring(target) and !prevent_kick then
    target:Kick(self:get_ban_message(obj, Flux.Lang:get_player_lang(target)))
  end

  return obj
end

--- Deletes the ban record of a SteamID from the database and from the ban cache, so that
-- the player can connect again right away and a later ban gets a record of its own. Runs
-- the OnBanRemoved hook if there was a ban.
-- @param steam_id [String]
-- @return [Boolean whether a ban record was found and deleted, Map the deleted record's
--   column values (only when found)]
function Bolt:remove_ban(steam_id)
  local obj = bans[steam_id]

  if obj then
    local dump = obj:dump()
    obj:destroy()

    bans[steam_id] = nil

    --- Called on the server after a ban has been lifted: by the `ban remove` command, from
    -- the ban list of the admin panel, or because it has expired by the time its owner
    -- tried to join.
    -- @param steam_id [String SteamID that is no longer banned]
    -- @param data [Map Column values of the deleted ban record]
    hook.Run('OnBanRemoved', steam_id, dump)

    return true, dump
  end

  return false
end

local function ban_row(ban)
  local time_left = Bolt:get_ban_time_left(ban)
  local steam_id = tostring(ban.steam_id)

  return {
    steam_id = steam_id,
    name = tostring(ban.name or steam_id),
    reason = string.sub(tostring(ban.reason or 'ui.no_reason'), 1, max_reason_length),
    admin = ban.admin_name and tostring(ban.admin_name) or nil,
    permanent = time_left == false,
    time_left = time_left or 0
  }
end

--- Checks whether a ban matches the text typed into the search field of the ban list.
-- @param ban [Ban]
-- @param needle [String lowercase text to look for in the name, the SteamID and the reason]
-- @return [Boolean]
local function ban_matches(ban, needle)
  return string.find(tostring(ban.name):utf8lower(), needle, 1, true) != nil
    or string.find(tostring(ban.steam_id):utf8lower(), needle, 1, true) != nil
    or string.find(tostring(ban.reason):utf8lower(), needle, 1, true) != nil
end

--- Returns how long a ban still lasts.
-- @param ban [Ban ban record, or a table with its duration and unban_time fields]
-- @return [Number/Boolean seconds until the ban ends, 0 if it has already run out; false
--   for a permanent ban and for a ban whose end time cannot be read]
function Bolt:get_ban_time_left(ban)
  local unban_time = time_from_timestamp(ban.unban_time)

  if tonumber(ban.duration) == 0 or !unban_time then
    return false
  end

  return math.max(unban_time - os_time(), 0)
end

--- Builds the message a banned player reads when they are kicked or turned away: the reason
-- of the ban and, unless it is permanent, the time it has left. The text comes from the
-- 'error.banned.temporary' and 'error.banned.permanent' phrases.
-- @param ban [Ban ban record, or a table with its reason, duration and unban_time fields]
-- @param lang=nil [String language code to write the message in; the language set by the
--   bolt_ban_message_language config by default, since the language of a player who is still
--   connecting is not known]
-- @return [String]
function Bolt:get_ban_message(ban, lang)
  if !isstring(lang) then
    lang = Config.get('bolt_ban_message_language')
  end

  if !isstring(lang) or lang == '' then
    lang = 'en'
  end

  local reason = (t(tostring(ban.reason or 'ui.no_reason'), nil, lang))
  local time_left = self:get_ban_time_left(ban)

  if !time_left then
    return (t('error.banned.permanent', { reason = reason }, lang))
  end

  return (t('error.banned.temporary', {
    reason = reason,
    time = Flux.Lang:duration(math.max(time_left, 1))
  }, lang))
end

--- Sends a page of the ban list to a player: the bans sorted by name, 25 to a page, with
-- the time each has left at this moment. Does not check permissions.
-- @param target [Player player to send the page to]
-- @param page=1 [Number page to send; brought into the range of existing pages]
-- @param search_text=nil [String only list the bans that have this text in their name,
--   SteamID or reason, in any case]
function Bolt:send_ban_list(target, page, search_text)
  if !IsValid(target) then return end

  if !isnumber(page) or page != page then
    page = 1
  end

  if !isstring(search_text) then
    search_text = ''
  end

  search_text = string.sub(search_text, 1, max_search_length):utf8lower()

  local matching = {}

  for _, ban in pairs(self:get_bans()) do
    if search_text == '' or ban_matches(ban, search_text) then
      matching[#matching + 1] = ban
    end
  end

  local sort_names = {}

  for i = 1, #matching do
    local ban = matching[i]

    sort_names[ban] = tostring(ban.name):utf8lower()
  end

  table.sort(matching, function(first, second)
    local first_name, second_name = sort_names[first], sort_names[second]

    if first_name == second_name then
      return tostring(first.steam_id) < tostring(second.steam_id)
    end

    return first_name < second_name
  end)

  local pages = math.max(math.ceil(#matching / bans_per_page), 1)
  local rows = {}

  page = math.Clamp(math.floor(page), 1, pages)

  for i = (page - 1) * bans_per_page + 1, math.min(page * bans_per_page, #matching) do
    rows[#rows + 1] = ban_row(matching[i])
  end

  Cable.send({ target }, 'fl_bolt_bans', {
    page = page,
    pages = pages,
    total = #matching,
    bans = rows
  })
end

--- Tells the players who may see the ban list that it has changed, so that a ban list page
-- that is open asks for its bans again.
function Bolt:send_ban_list_changed()
  local viewers = {}

  for _, client in player.Iterator() do
    if client:can('ban') then
      viewers[#viewers + 1] = client
    end
  end

  if #viewers > 0 then
    Cable.send(viewers, 'fl_bolt_bans_changed')
  end
end
