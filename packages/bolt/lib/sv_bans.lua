--- Server side of the ban list: the time a ban has left, the message a banned player is
-- shown when they are kicked or turned away, and the pages of bans sent to the ban list page
-- of the admin panel.
-- Only players with the permission of the Ban command (`ban`) are told when a ban is added
-- or lifted, so that an open page can refresh itself.

local bans_per_page = 25
local max_reason_length = 512
local max_search_length = 256

Cable.check_networked_string('fl_bolt_bans')
Cable.check_networked_string('fl_bolt_bans_changed')

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

  return math.max(unban_time - os.time(), 0)
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
