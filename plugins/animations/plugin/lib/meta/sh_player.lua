--- Player extensions of the Animations plugin: starting and leaving an animation, and asking
-- which one a player is playing. The server does the work; a client can only ask the server
-- on behalf of its own local player.
-- @module [Player]

local player_meta = FindMetaTable('Player')

--- Makes the player play a registered animation, see `Animations:play`. Clientside it asks
-- the server to start the animation for the local player, or to make them leave the one
-- they are playing, as the context menu does; the server notifies the player if it refuses.
-- Does nothing clientside when called on another player.
-- @param id [String ID of the registered animation]
-- @return [Boolean whether the animation has started, String phrase that says why not,
--   Map arguments of the phrase or nil; nothing clientside]
function player_meta:play_animation(id)
  if CLIENT then
    if self == LocalPlayer() then
      Cable.send('fl_animations_play', id)
    end

    return
  end

  return Animations:play(self, id)
end

--- Makes the player leave the animation they are playing, with its exit sequence if it has
-- one, see `Animations:leave`. Clientside it asks the server to do so for the local player
-- and does nothing when called on another player.
-- @return [Boolean false if the player is not playing an animation; nothing clientside]
function player_meta:leave_animation()
  if CLIENT then
    if self == LocalPlayer() then
      Cable.send('fl_animations_leave')
    end

    return
  end

  return Animations:leave(self)
end

--- Returns the animation of the Animations plugin that the player is playing.
-- @return [String ID of the animation, nil if the player is not playing one]
function player_meta:get_played_animation()
  return self:get_nv('fl_animation')
end
