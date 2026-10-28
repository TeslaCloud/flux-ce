--- Client-side network handlers of the Factions plugin: keeps the reason the server has sent
-- for refusing a character because of its faction, which the character creation screen then
-- shows.

Cable.receive('fl_faction_creation_refused', function(reason, arguments)
  if isstring(reason) then
    Factions.creation_refusal = t(reason, arguments)
  end
end)
