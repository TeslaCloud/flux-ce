--- Elements, the building blocks of Lumen trees. An element is a plain table that describes a
-- panel or a component with its props, nothing is created until the reconciler mounts it. The
-- compiler turns every piece of markup into a call to `Lumen.element`; code that renders
-- without templates calls it directly.
-- ```
-- -- The same as <view style={{ gap = 4 }}><text>Hello</text>{items}</view>
-- Lumen.element('view', { style = { gap = 4 } }, {
--   Lumen.element('text', nil, { 'Hello' }),
--   items
-- })
-- ```
-- @module [Lumen]

local istable    = istable
local isstring   = isstring
local isnumber   = isnumber

--- Flattens a list of children into the list that elements carry: nested lists are unrolled,
-- elements, strings and numbers are kept, and nil and booleans become false. The false entries
-- keep the children after a `{condition and <element/>}` at the same positions whether or not
-- the condition holds, so that they are matched between renders without keys.
-- @param children [List children as given in markup or code]
-- @param into=nil [List list to add the children to]
-- @return [List the flattened children]
function Lumen.flatten(children, into)
  into = into or {}

  if !istable(children) then return into end

  for i = 1, table.maxn(children) do
    local child = children[i]

    if istable(child) then
      if child.lumen_element then
        into[#into + 1] = child
      else
        Lumen.flatten(child, into)
      end
    elseif isstring(child) or isnumber(child) then
      into[#into + 1] = child
    else
      into[#into + 1] = false
    end
  end

  return into
end

--- Creates an element. Children given here are flattened and stored as `props.children`.
-- @param kind [String/Function/Map the type of the element: the name of an intrinsic element
--   or of a template, a component function or `Lumen.Fragment`]
-- @param props=nil [Map props of the element; `key` tells elements of a list apart between
--   renders, `style` is its style, `ref` receives the panel]
-- @param children=nil [List children: elements, strings, numbers or lists of these]
-- @return [Map the element]
function Lumen.element(kind, props, children)
  props = props or {}

  if children != nil then
    props.children = Lumen.flatten(children)
  elseif props.children != nil and (!istable(props.children) or props.children.lumen_element) then
    props.children = Lumen.flatten({ props.children })
  end

  return {
    lumen_element = true,
    type = kind,
    props = props,
    key = props.key
  }
end

--- Checks whether a value is an element.
-- @param value [Any]
-- @return [Boolean]
function Lumen.is_element(value)
  return istable(value) and value.lumen_element == true
end

--- Checks whether an element is a fragment.
-- @param element [Map]
-- @return [Boolean]
function Lumen.is_fragment(element)
  return Lumen.is_element(element) and element.type == Lumen.Fragment
end

--- Joins the text children of an element into one string, as the `text` and `button` elements
-- do. Numbers are converted, elements and other values are skipped. The `text` prop, if the
-- element has one, takes the place of the children.
-- @param props [Map props of the element]
-- @return [String]
function Lumen.text_of(props)
  if props.text != nil then
    return tostring(props.text)
  end

  local children = props.children

  if !istable(children) then return '' end

  local parts = {}

  for k, child in ipairs(children) do
    if isstring(child) then
      parts[#parts + 1] = child
    elseif isnumber(child) then
      parts[#parts + 1] = tostring(child)
    end
  end

  return table.concat(parts)
end

--- Compares two lists shallowly, as the dependencies of effects are compared.
-- @param a [List]
-- @param b [List]
-- @return [Boolean true if both have the same values at the same positions]
function Lumen.shallow_equal(a, b)
  if a == b then return true end
  if !istable(a) or !istable(b) then return false end

  local count_a, count_b = table.maxn(a), table.maxn(b)

  if count_a != count_b then return false end

  for i = 1, count_a do
    if a[i] != b[i] then return false end
  end

  return true
end
