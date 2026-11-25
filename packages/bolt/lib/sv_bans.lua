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
-- Runs the BanAdded hook afterwards.
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
  hook.Run('BanAdded', steam_id, obj)

  return obj
end

--- Puts a ban record into the ban cache without touching the database.
-- @param id [String SteamID the ban belongs to]
-- @param obj [Ban]
function Bolt:record_ban(id, obj)
  bans[id] = obj
end

--- Bans a player or a SteamID and saves the ban to the database, replacing a ban the SteamID
-- has already. The banned player is kicked if they are on the server, whether they were given
-- as a player or as a SteamID, unless prevent_kick is set. Does not check who may change an
-- existing ban; `Bolt:place_ban` does that for a ban placed on behalf of a player. The owner
-- of the SteamID does not have to be on the server, or to have ever joined it.
-- ```
-- -- Ban an online player for a day.
-- Bolt:ban(target, 60 * 60 * 24, 'Prop spam')
-- -- Permanently ban somebody by SteamID.
-- Bolt:ban('STEAM_0:1:12345', 0, 'Cheating')
-- -- The same on behalf of a player, who has to be allowed to change an earlier ban.
-- Bolt:place_ban(actor, 'STEAM_0:1:12345', 0, 'Cheating')
-- ```
-- @param target [Player/String the player to ban, or a SteamID in any case and with any
--   universe digit; anything else raises an error]
-- @param duration=0 [Number ban length in seconds, 0 for a permanent ban]
-- @param reason='N/A' [String text or language phrase]
-- @param prevent_kick=false [Boolean do not kick the banned player]
-- @param admin=nil [Player the player who issues the ban, stored with it]
-- @param name=nil [String name to store with the ban of a SteamID whose owner is not on
--   the server; the name of an earlier ban of that SteamID or else the SteamID itself by
--   default]
-- @return [Ban the ban record, or nil if target is an invalid player]
function Bolt:ban(target, duration, reason, prevent_kick, admin, name)
  if isstring(target) then
    target = player.normalize_steam_id(target)

    if !player.is_steam_id(target) then
      error("Bolt:ban takes a player or a SteamID, not '"..target.."'")
    end
  elseif !isentity(target) then
    error('Bolt:ban takes a player or a SteamID, not '..type(target))
  elseif !IsValid(target) then
    return
  end

  duration = duration or 0
  reason = reason or 'N/A'

  local steam_id = target

  if isstring(target) then
    local online = player.find(target)

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

--- Checks whether a timed ban has run out and may be lifted.
-- @param steam_id [String SteamID the ban belongs to]
-- @param entry [Ban]
-- @param ip [String address its owner connects from, nil when they are not connecting]
-- @param name [String name of its owner]
-- @return [Boolean]
local function should_expire(steam_id, entry, ip, name)
  local unban_time = time_from_timestamp(entry.unban_time)

  return tonumber(entry.duration) != 0 and unban_time != nil and unban_time <= os_time() and
    --- Called on the server when a timed ban has expired and Bolt is about to lift it: when
    -- its owner connects or joins, and for every expired ban once the bans have been loaded.
    -- @param steam_id [String SteamID the ban belongs to]
    -- @param ip [String Address the player connects from; nil for a ban that expires while
    --   the bans are loaded]
    -- @param name [String Name of the player, or the name stored with the ban]
    -- @return [Boolean Return false to keep the ban, so that the player is rejected with
    --   the reason of the ban]
    Plugin.call('ShouldExpireBan', steam_id, ip, name) != false
end

--- Finds the ban that keeps a SteamID off the server. A timed ban that has expired is lifted
-- instead, see the ShouldExpireBan hook.
-- @param steam_id [String SteamID of the player who connects or joins]
-- @param ip [String address the player connects from]
-- @param name [String player name]
-- @return [Ban the ban to enforce, nil if there is none]
function Bolt:get_enforced_ban(steam_id, ip, name)
  local entry = bans[steam_id]

  --- Called on the server when a player who connects or joins has a ban on record, before
  -- the ban is enforced or lifted.
  -- @param steam_id [String SteamID the ban belongs to]
  -- @param ip [String Address the player connects from]
  -- @param name [String Name of the player]
  -- @return [Boolean Return false to ignore the ban, so that Bolt neither
  --   rejects the player nor lifts the ban]
  if !entry or Plugin.call('ShouldCheckBan', steam_id, ip, name) == false then return end

  if should_expire(steam_id, entry, ip, name) then
    self:remove_ban(steam_id)

    return
  end

  return entry
end

--- Kicks a player who is on the server if their SteamID, or that of the owner of the game
-- they play through family sharing, has a ban to enforce, see `Bolt:get_enforced_ban`. This
-- catches the players who were banned while they were still connecting, those who connected
-- before the bans had been loaded and those who borrow the game of a banned player.
-- @param target [Player]
-- @return [Boolean true if the player has been kicked]
function Bolt:kick_if_banned(target)
  if !IsValid(target) or target:IsBot() then return false end

  local ip, name = target:IPAddress(), target:steam_name()
  local entry = self:get_enforced_ban(target:SteamID(), ip, name)
  local owner_id64 = target:OwnerSteamID64()

  if !entry and owner_id64 != '0' and owner_id64 != target:SteamID64() then
    entry = self:get_enforced_ban(util.SteamIDFrom64(owner_id64), ip, name)
  end

  if !entry then return false end

  target:Kick(self:get_ban_message(entry, Flux.Lang:get_player_lang(target)))

  return true
end

--- Lifts the timed bans that have expired while their owners were away, see the
-- ShouldExpireBan hook.
function Bolt:remove_expired_bans()
  for steam_id, entry in pairs(bans) do
    if should_expire(steam_id, entry, nil, entry.name) then
      self:remove_ban(steam_id)
    end
  end
end

--- Decides whether a player may change the ban that a SteamID has, by lifting it or by
-- banning the SteamID again: the server console, a root player, the player who placed the
-- ban, or anybody who may act on that player, by `Bolt:check_immunity` while they are on the
-- server and `Bolt:check_offline_target` while they are not. A ban placed from the server
-- console or by code can only be changed by the console and by root players. Anybody may act
-- on a SteamID without a ban. When the ban is replaced while the answer is awaited, the
-- question is asked again for the new ban.
-- @param actor [Player the player who acts, an invalid entity for the server console]
-- @param steam_id [String SteamID whose ban is changed]
-- @param callback [Function called with true if the player may change the ban and false
--   otherwise, and with the ban, nil if there is none; not called if the player has left by
--   the time the answer arrives]
function Bolt:check_ban_access(actor, steam_id, callback)
  local entry = bans[steam_id]
  local admin_steam_id = entry and entry.admin_steam_id

  if !entry or !IsValid(actor) or actor:is_root() or actor:SteamID() == admin_steam_id then
    callback(true, entry)

    return
  end

  if !player.is_steam_id(admin_steam_id) then
    callback(false, entry)

    return
  end

  local admin = player.find(admin_steam_id)

  if IsValid(admin) then
    callback(self:check_immunity(actor, admin), entry)

    return
  end

  self:check_offline_target(actor, admin_steam_id, 'ban', function(allowed)
    if bans[steam_id] != entry then
      self:check_ban_access(actor, steam_id, callback)

      return
    end

    callback(allowed, entry)
  end)
end

--- Bans a player or a SteamID on behalf of a player, see `Bolt:ban`, unless the SteamID has a
-- ban already that the player may not change, see `Bolt:check_ban_access`, in which case the
-- player is told so. Does not check permissions or the immunity against the banned player. A
-- player who leaves while the answer is awaited is banned by their SteamID.
-- @param actor [Player the player who bans, an invalid entity for the server console]
-- @param target [Player/String the player to ban, or a SteamID]
-- @param duration=0 [Number ban length in seconds, 0 for a permanent ban]
-- @param reason='N/A' [String text or language phrase]
-- @param name=nil [String name to store with the ban of a SteamID whose owner is not on the
--   server, see Bolt#ban]
-- @param callback=nil [Function called with the ban record once the ban has been placed, or
--   with nil if the player may not change the existing ban]
function Bolt:place_ban(actor, target, duration, reason, name, callback)
  local is_player = !isstring(target) and IsValid(target)
  local steam_id = is_player and target:SteamID() or player.normalize_steam_id(target)

  self:check_ban_access(actor, steam_id, function(allowed, entry)
    local obj

    if allowed then
      obj = self:ban((is_player and !IsValid(target)) and steam_id or target, duration, reason, false, actor, name)
    else
      Flux.Player:notify(actor, 'error.ban_not_yours', { target = tostring(entry.name or steam_id) })
    end

    if callback then
      callback(obj)
    end
  end)
end

--- Lifts the ban of a SteamID on behalf of a player who may change it, see
-- `Bolt:check_ban_access`. Does not check permissions. The player is told when the SteamID is
-- not banned or when they may not lift the ban.
-- @param actor [Player the player who lifts the ban, an invalid entity for the server console]
-- @param steam_id [String SteamID whose ban to lift]
-- @param callback=nil [Function called with the column values of the deleted ban record once
--   the ban has been lifted]
function Bolt:lift_ban(actor, steam_id, callback)
  if !bans[steam_id] then
    Flux.Player:notify(actor, 'error.not_banned', { steam_id = steam_id })

    return
  end

  self:check_ban_access(actor, steam_id, function(allowed, entry)
    if !entry then
      Flux.Player:notify(actor, 'error.not_banned', { steam_id = steam_id })
    elseif !allowed then
      Flux.Player:notify(actor, 'error.ban_not_yours', { target = tostring(entry.name or steam_id) })
    else
      local _, data = self:remove_ban(steam_id)

      if callback then
        callback(data)
      end
    end
  end)
end

--- Deletes the ban record of a SteamID from the database and from the ban cache, so that
-- the player can connect again right away and a later ban gets a record of its own. Runs
-- the BanRemoved hook if there was a ban.
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
    -- the ban list of the admin panel, or because it has expired, which Bolt notices when its
    -- owner tries to join and when the bans are loaded.
    -- @param steam_id [String SteamID that is no longer banned]
    -- @param data [Map Column values of the deleted ban record]
    hook.Run('BanRemoved', steam_id, dump)

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
