--- The conditions of doors, serverside: the check of the tree of conditions that the door
-- menu of a player sends before it is set on a door.

if !Doors then
  PLUGIN:set_global('Doors')
end

local istable = istable
local isstring = isstring
local pairs = pairs

--- How many levels of nodes the tree of conditions of a door may have. A schema may change it.
Doors.max_condition_depth = Doors.max_condition_depth or 8

--- How many condition nodes the tree of conditions of a door may have. A schema may change it.
Doors.max_condition_nodes = Doors.max_condition_nodes or 64

--- Copies the parameters of a condition node.
-- @param data [Any]
-- @return [Map the parameters, an empty Map for nil; nil if they are not a Map of string
--   keys to values that are not tables]
local function clean_data(data)
  if data == nil then return {} end
  if !istable(data) then return end

  local result = {}

  for key, value in pairs(data) do
    if !isstring(key) or istable(value) then return end

    result[key] = value
  end

  return result
end

--- Copies a list of condition nodes and the nodes below them.
-- @param nodes [Any]
-- @param depth [Number the level of the nodes in the list, 1 for the top-level list]
-- @param counter [Map the count of nodes copied so far, in its `nodes` field]
-- @return [List the nodes, nil if the list is not a valid one]
local function clean_nodes(nodes, depth, counter)
  if !istable(nodes) then return end
  if next(nodes) == nil then return {} end
  if depth > Doors.max_condition_depth then return end

  local registered = Conditions:get_all()
  local result = {}

  for _, node in pairs(nodes) do
    counter.nodes += 1

    if counter.nodes > Doors.max_condition_nodes then return end
    if !istable(node) or !isstring(node.id) or !registered[node.id] then return end

    local data = clean_data(node.data)
    local childs = clean_nodes(node.childs ?? {}, depth + 1, counter)

    if !data or !childs then return end

    result[#result + 1] = { id = node.id, data = data, childs = childs }
  end

  return result
end

--- Checks a tree of conditions that a client has sent for a door and copies the parts of it
-- that the Conditions package reads. Every node has to be a Map with the id of a registered
-- condition, parameters that are a Map of string keys to values other than tables, and a
-- list of child nodes; the tree may have at most `Doors.max_condition_depth` levels and at
-- most `Doors.max_condition_nodes` nodes.
-- @param conditions [Any the tree as it was received]
-- @return [List the checked copy of the tree, or nil if the tree is not valid]
function Doors:clean_conditions(conditions)
  return clean_nodes(conditions, 1, { nodes = 0 })
end
