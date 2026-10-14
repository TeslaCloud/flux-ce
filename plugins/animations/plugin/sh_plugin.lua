--- Animations lets players put their character into a stance or make it perform a gesture,
-- picked from a panel in the context menu.
-- An animation is registered with `Animations:register_anim` and is made of sequences of
-- the player's model: an optional enter sequence, the main sequence and an optional exit
-- sequence. A stance holds its main sequence until the player presses a movement key or
-- picks an animation again; a one-shot gesture plays it once and ends by itself. For as
-- long as the animation lasts the player cannot move, jump, crouch or attack, is rendered
-- at the angle they started it at and, with the `animations_third_person` config on, sees
-- themselves in third person. The panel only lists the animations that the model of the
-- local player has the sequences of.
--
-- The server runs everything: it checks the request (`Animations:can_play`), plays the
-- sequences with `Player:set_animation`, which shows them to every client, and ends the
-- animation when the framework drops the sequence because the player has died, spawned or
-- got another model, as well as when they switch characters, leave, are ragdolled, enter a
-- vehicle or noclip, or are moved away. Clients only read the two networked variables of
-- the player: `fl_animation`, the ID of the animation they are playing, and
-- `fl_animation_angle`, the angle they are rendered at.
--
-- Plugins can veto an animation with the server hook `PlayerCanPlayAnimation`. The
-- `animations_cooldown` config sets how soon a player may start another animation.
-- @module [Animations]

PLUGIN:set_global('Animations')

local stored = Animations.stored or {}
local order = Animations.order or {}
Animations.stored = stored
Animations.order = order

local leave_keys = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP)
local blocked_keys = bit.bor(IN_JUMP, IN_DUCK, IN_ATTACK, IN_ATTACK2)
local client_blocked_keys = bit.bor(IN_DUCK, IN_ATTACK, IN_ATTACK2)
local keep_jump_out = bit.bnot(IN_JUMP)
local band = bit.band

--- Registers an animation that players can play from the context menu. Registering an ID
-- again replaces the animation and keeps its place in the list.
-- ```
-- Animations:register_anim({
--   id = 'sit_ground',
--   name = 'animation.sit_ground.name',
--   enter = 'idle_to_sit_ground',
--   anim = 'sit_ground',
--   exit = 'sit_ground_to_idle'
-- })
-- ```
-- @param data [Map animation data: id (String), name (String text or phrase), anim (String
--   name of the main sequence, or a List of names, of which one that the model has is picked
--   at random), enter and exit (String optional sequences played before and after it),
--   one_shot (Boolean the main sequence is played once and the animation ends by itself),
--   duration (Number seconds the main sequence is kept for: for a stance 0 or nil keeps it
--   until the player leaves, for a one-shot it replaces the length of the sequence), wall
--   ('behind' or 'front': the player has to stand with their back or their face against a
--   wall and is turned to it) and wall_height (Number height above the feet at which the
--   wall is looked for, the eyes if nil)]
-- @return [Map the registered animation data]
function Animations:register_anim(data)
  if !stored[data.id] then
    table.insert(order, data.id)
  end

  stored[data.id] = data

  return data
end

--- Returns a registered animation.
-- @param id [String ID of the animation]
-- @return [Map animation data, nil if it is not registered]
function Animations:get(id)
  return stored[id]
end

--- Returns all registered animations.
-- @return [Map animation data by ID]
function Animations:all()
  return stored
end

--- Returns all registered animations in the order they were registered in, which is the
-- order the context menu lists them in.
-- @return [List<Map> animation data]
function Animations:get_list()
  local result = {}

  for i = 1, #order do
    local data = stored[order[i]]

    if data then
      result[#result + 1] = data
    end
  end

  return result
end

--- Returns the sequences that the model of a player has out of the specified ones.
-- @param target [Player]
-- @param names [String name of a sequence, or List<String> of names]
-- @return [List<String> names of the sequences the model has, in the order given]
function Animations:find_sequences(target, names)
  local found = {}

  if isstring(names) then
    names = { names }
  end

  if !istable(names) then return found end

  for i = 1, #names do
    local name = names[i]

    if target:LookupSequence(name) != -1 then
      found[#found + 1] = name
    end
  end

  return found
end

--- Works out which sequences a player would play for an animation. The model of the player
-- has to have the enter and the exit sequence, if the animation has them, and at least one
-- of its main sequences.
-- @param target [Player]
-- @param data [Map animation data]
-- @return [Map sequences: enter (String or nil), variants (List<String> main sequences the
--   model has) and exit (String or nil); nil if the model cannot play the animation]
function Animations:get_sequences(target, data)
  local variants = self:find_sequences(target, data.anim)

  if #variants == 0 then return end
  if data.enter and target:LookupSequence(data.enter) == -1 then return end
  if data.exit and target:LookupSequence(data.exit) == -1 then return end

  return {
    enter = data.enter,
    variants = variants,
    exit = data.exit
  }
end

--- Returns the animation a player is playing.
-- @param target [Player]
-- @return [String ID of the animation, nil if the player is not playing one]
function Animations:get_playing(target)
  return target:get_nv('fl_animation')
end

--- Checks whether a player is playing an animation of this plugin.
-- @param target [Player]
-- @return [Boolean]
function Animations:is_playing(target)
  return target:get_nv('fl_animation') != nil
end

require_relative 'sh_default_animations'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Takes the movement, jump, crouch and attack input out of the commands of a player who
-- is playing an animation. On the server, a movement or jump key that is pressed during the
-- animation makes the player leave it; keys that were already held down when it started do
-- not count until they have been let go of. The client leaves the jump key in the commands
-- it builds, since a command reaches the server the way the client has left it and the
-- server could not tell that the key was pressed otherwise; the jump itself is taken out
-- of the movement in the `Move` handler on both sides.
-- @param actor [Player]
-- @param user_cmd [CUserCmd]
function Animations:StartCommand(actor, user_cmd)
  if !actor:get_nv('fl_animation') then return end

  user_cmd:ClearMovement()

  if CLIENT then
    user_cmd:RemoveKey(client_blocked_keys)

    return
  end

  local state = actor.animation_data

  if state then
    local pressed = band(user_cmd:GetButtons(), leave_keys)
    local held = band(state.held_keys or leave_keys, pressed)

    state.held_keys = held

    if pressed != held then
      self:leave(actor)
    end
  end

  user_cmd:RemoveKey(blocked_keys)
end

--- Stops a player who is playing an animation where they stand: the speed they had when it
-- started and the speed other plugins ask for are dropped, and so is the jump key, which
-- the client keeps in its commands (see the `StartCommand` handler). The vertical speed is
-- kept, so that the player still falls when the ground under them is gone.
-- @param actor [Player player being moved]
-- @param move_data [CMoveData movement data of the player]
function Animations:Move(actor, move_data)
  if !actor:get_nv('fl_animation') then return end

  local velocity = move_data:GetVelocity()

  velocity.x = 0
  velocity.y = 0

  move_data:SetVelocity(velocity)
  move_data:SetForwardSpeed(0)
  move_data:SetSideSpeed(0)
  move_data:SetUpSpeed(0)
  move_data:SetButtons(band(move_data:GetButtons(), keep_jump_out))
end

--- Keeps an animating player rendered at the angle they started the animation at.
-- @param actor [Player player being animated]
function Animations:UpdateAnimation(actor)
  local angle = actor:get_nv('fl_animation_angle')

  if angle then
    actor:SetRenderAngles(angle)
  end
end
