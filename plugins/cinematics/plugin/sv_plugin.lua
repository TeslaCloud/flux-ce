--- Server side of the Cinematics plugin: sends cinematics to the clients, where they are
-- queued and drawn.

--- Works out who to send a message to from the targets given to `Cinematics:show` or
-- `Cinematics:clear`. Players that are not valid any more are left out of a list, and a single
-- player that is not valid gives no receivers, so that `Cable.send` does not turn the message
-- into a broadcast.
-- @param targets [Player/List<Player> receivers, or nil for everyone]
-- @return [Boolean true if there is anyone to send to, Player/List<Player> the valid receivers
--   to give to `Cable.send`; nil for everyone]
local function get_receivers(targets)
  if targets == nil then
    return true
  elseif istable(targets) then
    local receivers = {}

    for k, v in ipairs(targets) do
      if isentity(v) and IsValid(v) and v:IsPlayer() then
        table.insert(receivers, v)
      end
    end

    return #receivers > 0, receivers
  elseif isentity(targets) and IsValid(targets) and targets:IsPlayer() then
    return true, targets
  end

  return false
end

--- Shows a cinematic to one player, several players or everyone. It is added to the queue of
-- every receiver and played once the cinematics queued before it are over. Clients that have
-- not been initialized yet, or that have no character loaded, ignore it.
-- ```
-- Cinematics:show(nil, 'The curfew has begun.')
-- Cinematics:show(target, { title = 'City 17', subtitle = 'Trainstation', duration = 8 })
-- ```
-- @param targets [Player/List<Player> who to show the cinematic to; everyone if nil]
-- @param cinematic [String/Map caption text or language phrase, or a table with the fields
--   that `Cinematics:add` takes on the client: text, title, subtitle, arguments, color,
--   title_color, duration, delay, bar_size and replace]
-- @return [Boolean true if the cinematic has been sent, false if the cinematic is not valid
--   or none of the targets is a valid player]
-- @see [Cinematics:add]
function Cinematics:show(targets, cinematic)
  if isstring(cinematic) then
    cinematic = { text = cinematic }
  end

  local has_receivers, receivers = get_receivers(targets)

  if !istable(cinematic) or !has_receivers then return false end

  Cable.send(receivers, 'fl_cinematic_show', cinematic)

  return true
end

--- Takes the cinematic that is on screen away from one player, several players or everyone,
-- along with the ones they have queued. The text disappears at once and the bars slide out.
-- @param targets [Player/List<Player> whose cinematics to clear; everyone if nil]
-- @return [Boolean true if the request has been sent, false if none of the targets is a
--   valid player]
function Cinematics:clear(targets)
  local has_receivers, receivers = get_receivers(targets)

  if !has_receivers then return false end

  Cable.send(receivers, 'fl_cinematic_clear')

  return true
end
