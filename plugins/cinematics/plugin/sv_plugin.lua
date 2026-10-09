--- Server side of the Cinematics plugin: sends cinematics to the clients, where they are
-- queued and drawn.

--- Shows a cinematic to one player, several players or everyone. It is added to the queue of
-- every receiver and played once the cinematics queued before it are over. Clients that have
-- not been initialized yet, or that have no character loaded, ignore it.
-- ```
-- Cinematics:show(nil, 'The curfew has begun.')
-- Cinematics:show(target, { title = 'City 17', subtitle = 'Trainstation', duration = 8 })
-- ```
-- @param targets [Player/List<Player> who to show the cinematic to; everyone if nil. Players
--   that are not valid any more are left out]
-- @param cinematic [String/Map caption text or language phrase, or a table with the fields
--   that `Cinematics:add` takes on the client: text, title, subtitle, arguments, color,
--   title_color, duration, delay, bar_size and replace]
-- @return [Boolean true if the cinematic has been sent, false if it is not valid]
-- @see [Cinematics:add]
function Cinematics:show(targets, cinematic)
  if isstring(cinematic) then
    cinematic = { text = cinematic }
  end

  if !istable(cinematic) then return false end

  Cable.send(targets, 'fl_cinematic_show', cinematic)

  return true
end

--- Takes the cinematic that is on screen away from one player, several players or everyone,
-- along with the ones they have queued. The text disappears at once and the bars slide out.
-- @param targets [Player/List<Player> whose cinematics to clear; everyone if nil. Players
--   that are not valid any more are left out]
function Cinematics:clear(targets)
  Cable.send(targets, 'fl_cinematic_clear')
end
