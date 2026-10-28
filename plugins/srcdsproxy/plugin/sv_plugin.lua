--- Server side of the SrcdsProxy plugin: the helpers its commands use to talk to the proxy
-- through the `Proxy` table of the backend addon. They check that the addon is there and
-- that the caller is connected through the proxy, build the proxy's commands (verbs) with
-- safely quoted arguments, send them, and turn a player argument into the IDs the proxy
-- knows. Every check notifies the caller when it fails.

--- Checks whether the srcdsproxy backend addon is installed, that is whether its
-- `Proxy` table exists.
-- @return [Boolean]
function SrcdsProxy:available()
  return istable(Proxy)
end

--- Checks whether the srcdsproxy backend addon is installed and tells the caller that it is
-- missing if it is not.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @return [Boolean]
function SrcdsProxy:check_available(actor)
  if self:available() then
    return true
  end

  Flux.Player:notify(actor, 'error.proxy.unavailable')

  return false
end

--- Checks whether the caller is connected through the proxy, which the proxy's commands
-- need, since the proxy only takes them from a player's session. The caller is told when the
-- addon is missing or they are not connected through the proxy; the server console never is.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @return [Boolean]
function SrcdsProxy:check_proxied(actor)
  if !self:check_available(actor) then
    return false
  end

  if !Proxy.is_proxied(actor) then
    Flux.Player:notify(actor, 'error.proxy.not_proxied')

    return false
  end

  return true
end

--- Checks whether the caller is a proxy admin: listed in the proxy's admins.toml and
-- verified by Steam. The proxy itself only takes whitelist and ban commands from them; this
-- check tells everybody else so right away. The caller is notified when the check fails.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @return [Boolean]
function SrcdsProxy:require_proxy_admin(actor)
  if !self:check_proxied(actor) then
    return false
  end

  if !Proxy.is_proxy_admin(actor) then
    Flux.Player:notify(actor, 'error.proxy.not_proxy_admin')

    return false
  end

  return true
end

--- Turns a text into one argument of a proxy command: in double quotes, so that names with
-- spaces stay together, and without the line breaks, semicolons and double quotes that the
-- command parser would act on.
-- ```
-- SrcdsProxy:quote('John "JD" Doe;')
-- -- '"John JD Doe"'
-- ```
-- @param text [Any text of the argument, converted with tostring]
-- @return [String]
function SrcdsProxy:quote(text)
  local clean = tostring(text):gsub('[\n\r;"]', '')

  return '"'..clean..'"'
end

--- Builds a proxy command from a verb and its arguments, each quoted with
-- `SrcdsProxy:quote`. Arguments that are nil or empty are left out, so optional arguments
-- go last.
-- ```
-- SrcdsProxy:verb('send', '76561198000000001', 'lobby', '')
-- -- 'send "76561198000000001" "lobby"'
-- ```
-- @param name [String the verb, such as 'info' or 'whitelist add', sent as it is]
-- @param ... [Vararg arguments of the verb]
-- @return [String]
function SrcdsProxy:verb(name, ...)
  local pieces = { name }

  for i = 1, select('#', ...) do
    local argument = select(i, ...)

    if argument != nil and tostring(argument) != '' then
      pieces[#pieces + 1] = self:quote(argument)
    end
  end

  return table.concat(pieces, ' ')
end

--- Checks whether a text has the form of an IPv4 or IPv6 address, or of a subnet written as
-- an address followed by a slash and a prefix length.
-- ```
-- SrcdsProxy:is_address('203.0.113.0/24') -- true
-- SrcdsProxy:is_address('2001:db8::1')    -- true
-- SrcdsProxy:is_address('STEAM_0:1:123')  -- false
-- ```
-- @param text [Any]
-- @return [Boolean]
function SrcdsProxy:is_address(text)
  if !isstring(text) then
    return false
  end

  local address = text:match('^(.-)/%d+$') or text

  if address:match('^%d+%.%d+%.%d+%.%d+$') then
    return true
  end

  local _, colons = address:gsub(':', '')

  return colons >= 2 and address:match('^[%x:%.]+$') != nil
end

--- Checks whether a text is a ban duration the way the proxy reads one: a number of
-- minutes, amounts with the units `s`, `m`, `h`, `d` and `w` written together (`1h30m`), or
-- `0`, `perm`, `permanent`, `forever` or `never` for a permanent ban. Case is ignored.
-- ```
-- SrcdsProxy:is_duration('1h30m') -- true
-- SrcdsProxy:is_duration('rude')  -- false
-- ```
-- @param text [Any]
-- @return [Boolean]
function SrcdsProxy:is_duration(text)
  if !isstring(text) or text == '' then
    return false
  end

  local lower = text:lower()

  if lower == 'perm' or lower == 'permanent' or lower == 'forever' or lower == 'never' or
     lower:match('^%d+$') then
    return true
  end

  local rest, count = lower:gsub('%d+[smhdw]', '')

  return count > 0 and rest == ''
end

--- Finds the player on this server whom the proxy knows by a SteamID64 or by a SteamID3
-- (`[U:1:123]`).
-- @param argument [String]
-- @return [Player the player, or nil if the argument is neither or nobody here has it]
function SrcdsProxy:find_local_steam_id(argument)
  local account_id = argument:match('^%[U:1:(%d+)%]$')

  if !account_id and !argument:match('^7656%d%d%d%d%d%d%d%d%d%d%d%d%d$') then
    return
  end

  for _, candidate in player.Iterator() do
    if Proxy.is_proxied(candidate) then
      if account_id and candidate:AccountID() == tonumber(account_id) or
         !account_id and Proxy.claimed_steamid64(candidate) == argument then
        return candidate
      end
    end
  end
end

--- Sends one or more commands to the proxy on behalf of the caller, who has to be connected
-- through the proxy. The proxy answers in the caller's console, which the caller is told
-- once all of the commands have been sent.
-- ```
-- SrcdsProxy:run(actor, 'glist')
-- ```
-- @param actor [Player the caller, an invalid entity for the server console]
-- @param verbs [String/List<String> proxy commands, as built by `SrcdsProxy:verb`]
-- @return [Boolean whether the commands have been sent]
function SrcdsProxy:run(actor, verbs)
  if !self:check_proxied(actor) then
    return false
  end

  if isstring(verbs) then
    verbs = { verbs }
  end

  for _, verb in ipairs(verbs) do
    Proxy.command(actor, verb)
  end

  Flux.Player:notify(actor, 'notification.proxy.console')

  return true
end

--- Finds whom a player argument of a proxy command targets, as IDs the proxy understands.
-- An argument that has the form of an IP address or a subnet goes to the proxy as it is, and
-- so does one that starts with `#` (a session ID from GList). Otherwise the players on this
-- server are looked up by their SteamID64 or SteamID3 and with `Flux.Command:str_to_player`,
-- which matches their names exactly and makes the target selectors work for them, and each
-- of them stands for the SteamID64 the proxy knows them by. A name that several players here
-- have targets nobody, and the caller is told to use a SteamID. Those who are not connected
-- through the proxy, or have no SteamID there, are left out and the caller is told about each
-- of them. When nobody on this server matches, the argument goes to the proxy as it is, which
-- finds players on every server of the network by name, SteamID or `#id`.
-- With check_immunity the caller has to pass the immunity check against every player found
-- on this server, unless the command is run from the server console; if any of them is
-- immune, nobody is targeted. Since a `#id` may belong to a player on this server whose
-- immunity cannot be checked, players are not allowed to use one then.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @param argument [String player name, target selector, SteamID, `#id`, address or subnet]
-- @param check_immunity=false [Boolean check the immunity of the players on this server]
-- @return [List<Map> entries with the `id` (String) to give to the proxy and the `player`
--   (Player) on this server it stands for, if any; nil if nobody is left, after the caller
--   has been notified]
function SrcdsProxy:find_targets(actor, argument, check_immunity)
  argument = tostring(argument or '')

  if argument == '' then
    Flux.Player:notify(actor, 'error.command.player_invalid', { player = argument })

    return
  end

  if self:is_address(argument) then
    return { { id = argument } }
  end

  if argument:sub(1, 1) == '#' then
    if check_immunity and IsValid(actor) then
      Flux.Player:notify(actor, 'error.proxy.session_id_unchecked', { target = argument })

      return
    end

    return { { id = argument } }
  end

  local by_steam_id = self:find_local_steam_id(argument)
  local found, kind

  if by_steam_id then
    found = { by_steam_id }
  else
    found, kind = Flux.Command:str_to_player(actor, argument)
  end

  if kind == 'ambiguous' then
    Flux.Player:notify(actor, 'error.command.player_ambiguous', { player = argument })

    return
  end

  local locals, listed = {}, {}

  if istable(found) then
    for _, target in ipairs(found) do
      if IsValid(target) and !listed[target] then
        listed[target] = true

        locals[#locals + 1] = target
      end
    end
  end

  if #locals == 0 then
    return { { id = argument } }
  end

  if check_immunity and IsValid(actor) then
    for _, target in ipairs(locals) do
      --- Run by the proxy commands that act on players (Transfer, `netban add` and
      -- `netban addip`) for every player on this server they are about to affect, the same
      -- way the command interpreter runs it for a command with `immunity` set.
      -- @param actor [Player Player who runs the command]
      -- @param target [Player Player the command targets]
      -- @param can_equal [Boolean Whether a target of the same standing may be affected]
      -- @return [Boolean Return false if the target is immune to the actor]
      if hook.Run('CommandCheckImmunity', actor, target, false) == false then
        Flux.Player:notify(actor, 'error.command.higher_immunity', { target = get_player_name(target) })

        return
      end
    end
  end

  local entries = {}

  for _, target in ipairs(locals) do
    local id = Proxy.is_proxied(target) and Proxy.claimed_steamid64(target) or ''

    if id != '' and id != '0' then
      entries[#entries + 1] = { id = id, player = target }
    else
      Flux.Player:notify(actor, 'error.proxy.target_not_proxied', { target = get_player_name(target) })
    end
  end

  if #entries == 0 then
    return
  end

  return entries
end

--- Turns the entries of `SrcdsProxy:find_targets` into a readable list for a notification:
-- the names of the players on this server and the IDs of everyone else.
-- @param entries [List<Map> entries of SrcdsProxy:find_targets]
-- @return [String]
function SrcdsProxy:targets_to_string(entries)
  return util.list_to_string(function(entry)
    return IsValid(entry.player) and get_player_name(entry.player) or entry.id
  end, nil, unpack(entries))
end

--- Has the proxy ban targets from the whole network on behalf of the caller, who has to be a
-- proxy admin. Players on this server are found by `SrcdsProxy:find_targets` and have to
-- pass the caller's immunity check. A duration that `SrcdsProxy:is_duration` accepts (such
-- as `30m`, `2h`, `7d` or `1w`) is passed on as one; anything else is the first word of the
-- reason. The proxy kicks whoever the ban covers and answers in the caller's console.
-- @param actor [Player the caller]
-- @param name [String the verb: 'ban' to ban SteamIDs, addresses or subnets, 'banip' to ban
--   the addresses of players]
-- @param target [String player name, target selector, SteamID, `#id`, address or subnet]
-- @param duration=nil [String ban duration, or the first word of the reason]
-- @param reason=nil [String the rest of the reason]
-- @return [List<Map> the entries of SrcdsProxy:find_targets that have been banned, or nil if
--   nothing has been sent, after the caller has been notified]
function SrcdsProxy:ban(actor, name, target, duration, reason)
  if !self:require_proxy_admin(actor) then return end

  local entries = self:find_targets(actor, target, true)

  if !entries then return end

  if duration and !self:is_duration(duration) then
    reason = (duration..' '..(reason or '')):strip()
    duration = nil
  end

  local verbs = {}

  for _, entry in ipairs(entries) do
    verbs[#verbs + 1] = self:verb(name, entry.id, duration, reason)
  end

  if !self:run(actor, verbs) then return end

  return entries
end
