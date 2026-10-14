--- Shared hook handlers of the Stats plugin: the effects of stats that have to be worked
-- out the same way on the server and on the client.

--- Weakens the slowdown, the lower jumps and the aim drift that hurt limbs cause by the
-- `stats_determination_pain` config for every level of the player's determination, and
-- strengthens them for every level below zero. Movement is predicted, which is why this
-- handler is shared: both realms read the same networked level and config.
-- Returning a strength keeps the handlers of the schema and of the plugins loaded later
-- from being asked, so nothing is returned for a player whose determination changes
-- nothing.
-- @param target [Player player the effect applies to]
-- @param effect [String 'run', 'jump' or 'aim']
-- @param fraction [Number strength from the damage of the limbs, above 0 and up to 1]
-- @return [Number strength to use instead, from 0 to 1; nil to keep it]
function Stats:AdjustLimbEffect(target, effect, fraction)
  local scale = self:get_player_effect_scale(target, 'determination', 'stats_determination_pain', true)

  if scale != 1 then
    return math.Clamp(fraction * scale, 0, 1)
  end
end
