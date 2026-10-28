--- Shared side of the server transfer areas of the SrcdsProxy plugin: the `proxy_transfer`
-- area type. A transfer area keeps the name of a server of the proxy network in its `backend`
-- field and a number of seconds in its `delay` field; a player who stays in it for that long
-- is moved to that server.

if !SrcdsProxy then
  PLUGIN:set_global('SrcdsProxy')
end

SrcdsProxy.transfer_area_type = 'proxy_transfer'
SrcdsProxy.default_transfer_delay = 5
SrcdsProxy.max_transfer_delay = 300

--- Turns what a player typed as the name of a server of the network into one word that is
-- safe to pass to `Proxy.transfer`: whitespace, semicolons and double quotes are removed.
-- @param text [String server name as typed]
-- @return [String the server name, or nil if nothing is left of it]
function SrcdsProxy:server_name(text)
  local name = tostring(text or ''):gsub('[%s;"]', '')

  if name == '' then
    return
  end

  return name
end

--- Turns a value into the delay of a transfer area: a number of seconds from 0 to
-- `SrcdsProxy.max_transfer_delay`.
-- @param value [Any delay as a number or a text]
-- @return [Number the delay, `SrcdsProxy.default_transfer_delay` if the value is no number]
function SrcdsProxy:transfer_delay(value)
  return math.Clamp(tonumber(value) or self.default_transfer_delay, 0, self.max_transfer_delay)
end

--- Finds an ID for a new transfer area that moves players to a server: the server's name
-- made into an ID, with the first number that no area has yet. Both realms have the same
-- areas, so they find the same ID.
-- @param backend [String server name, as returned by `SrcdsProxy:server_name`]
-- @return [String]
function SrcdsProxy:new_transfer_area_id(backend)
  local base = 'proxy_'..backend:to_id()
  local stored = Areas.all()
  local count = 1

  while stored[base..'_'..count] != nil do
    count = count + 1
  end

  return base..'_'..count
end

Areas.register_type(
  SrcdsProxy.transfer_area_type,
  'Server Transfer Area',
  'Moves the players who stay in the area for its delay to another server of the proxy network.',
  Color(0, 170, 255),
  function(actor, area, has_entered)
    if CLIENT or !has_entered then return end

    SrcdsProxy:enter_transfer_area(actor, area)
  end
)
