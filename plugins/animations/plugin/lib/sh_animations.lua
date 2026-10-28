--- An animation is registered with `Animations:register_anim` and is made of sequences of
-- the player's model: an optional enter sequence, the main sequence and an optional exit
-- sequence. A stance holds its main sequence until the player presses a movement key or
-- picks an animation again; a one-shot gesture plays it once and ends by itself. Clients
-- only read the two networked variables of the player: `fl_animation`, the ID of the
-- animation they are playing, and `fl_animation_angle`, the angle they are rendered at.

if !Animations then
  PLUGIN:set_global('Animations')
end

local stored = Animations.stored or {}
local order = Animations.order or {}
Animations.stored = stored
Animations.order = order

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
