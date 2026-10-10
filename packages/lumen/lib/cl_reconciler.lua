--- The reconciler of Lumen: it mounts a tree of elements into a panel, creating a vgui panel
-- for every intrinsic element and rendering every component, and later brings the panels in
-- line with a new tree, updating the props of the panels that are still there, creating the
-- ones that are new and removing the ones that are gone. Elements of a list are matched by
-- their `key` prop, or by their position when they have none. Components whose state changes
-- are rendered again on the next frame, and only their part of the tree is reconciled.
-- ```
-- local root = Lumen.mount(Lumen.element(Lumen.component('help')), parent_panel)
--
-- root:update(Lumen.element(Lumen.component('help'), { page = 'credits' }))
-- root:unmount()
-- ```
-- @module [Lumen.Reconciler]

mod 'Lumen::Reconciler'

local IsValid    = IsValid
local isstring   = isstring
local isnumber   = isnumber
local isfunction = isfunction
local istable    = istable
local tostring   = tostring
local pcall      = pcall

local dirty = {}
local effects = {}
local scheduled = false

local instantiate, update, reconcile, reconcile_children, unmount

--- Turns what a component returned or what a child is into an element: strings and numbers
-- become `text` elements, lists become fragments, nil and booleans become nil.
-- @param value [Any]
-- @return [Map an element, or nil]
local function normalize(value)
  if Lumen.is_element(value) then
    return value
  elseif isstring(value) or isnumber(value) then
    return Lumen.element('text', nil, { value })
  elseif istable(value) then
    return Lumen.element(Lumen.Fragment, nil, value)
  end

  return nil
end

--- Works out what an element stands for.
-- @param element [Map]
-- @return [String 'host', 'component' or 'fragment', or nil if the type is unknown, Any the
--   element definition of a host or the function of a component]
local function resolve(element)
  local kind = element.type

  if kind == Lumen.Fragment then
    return 'fragment'
  elseif isfunction(kind) then
    return 'component', kind
  elseif istable(kind) and isfunction(kind.render) then
    return 'component', kind.render
  elseif isstring(kind) then
    local def = Lumen.find_element(kind)

    if def then
      return 'host', def
    end

    if Lumen.find_template(kind) then
      local component = Lumen.component(kind)

      if isfunction(component) then
        return 'component', component
      elseif istable(component) and isfunction(component.render) then
        return 'component', component.render
      end
    end
  end

  return nil
end

--- Finds the closest host above an instance.
-- @param instance [Map]
-- @return [Map the host instance, or nil at the root]
local function nearest_host(instance)
  local parent = instance.parent

  while parent do
    if parent.kind == 'host' then
      return parent
    end

    parent = parent.parent
  end

  return nil
end

--- Collects the panels an instance consists of at the top level: the panel of a host, or the
-- panels of the children of a fragment or of a component.
-- @param instance [Map]
-- @param into [List<Panel>]
-- @return [List<Panel>]
local function collect_panels(instance, into)
  if !instance then return into end

  if instance.kind == 'host' then
    if IsValid(instance.panel) then
      into[#into + 1] = instance.panel
    end
  elseif instance.kind == 'component' then
    collect_panels(instance.child, into)
  else
    for k, child in ipairs(instance.children) do
      collect_panels(child, into)
    end
  end

  return into
end

--- Puts the panels of a host in the order of its children, so that the layout engine and the
-- z-order follow the tree, and lays the host out again.
-- @param host [Map host instance]
local function apply_order(host)
  if !IsValid(host.panel) then return end

  local panels = {}

  for k, child in ipairs(host.children or {}) do
    collect_panels(child, panels)
  end

  for i, panel in ipairs(panels) do
    panel:SetZPos(i)
  end

  host.panel.lumen_children = panels
  host.panel:InvalidateLayout()
end

--- Renders a component: calls its function with its props between `Lumen.State.begin` and
-- `Lumen.State.finish`.
-- @param instance [Map component instance]
-- @return [Map the element it returned, normalized, or nil, Boolean false if the render failed]
local function render_component(instance)
  Lumen.State.begin(instance)

  local success, result = pcall(instance.component, instance.element.props)

  Lumen.State.finish()

  if !success then
    ErrorNoHalt('Lumen: a component has failed to render: '..tostring(result)..'\n')

    return nil, false
  end

  return normalize(result), true
end

--- Creates the instance of an element, with its panel or its rendered child, inside a
-- container panel.
-- @param element [Map]
-- @param container [Panel the panel that hosts are created in]
-- @param root [Map the root the instance belongs to]
-- @param parent [Map the parent instance, nil at the root]
-- @return [Map the instance, or nil if the element could not be created]
function instantiate(element, container, root, parent)
  local kind, payload = resolve(element)

  if !kind then
    ErrorNoHalt("Lumen: unknown element type '"..tostring(element.type).."'\n")

    return nil
  end

  local instance = {
    kind = kind,
    element = element,
    key = element.key,
    container = container,
    root = root,
    parent = parent
  }

  if kind == 'host' then
    if !IsValid(container) then return nil end

    local def = payload
    local props = element.props
    local panel = vgui.Create(def.class, container)

    if !IsValid(panel) then
      ErrorNoHalt("Lumen: could not create a '"..tostring(def.class).."' panel for '"..tostring(element.type).."'\n")

      return nil
    end

    instance.def = def
    instance.panel = panel
    panel.lumen_name = element.type
    panel.lumen_props = props

    if def.mount then
      local success, err = pcall(def.mount, panel, props)

      if !success then
        ErrorNoHalt("Lumen: mounting '"..tostring(element.type).."' has failed: "..tostring(err)..'\n')
      end
    end

    Lumen.apply_props(panel, props, nil, def, nearest_host(instance) == nil)

    if def.update then
      local success, err = pcall(def.update, panel, props, nil)

      if !success then
        ErrorNoHalt("Lumen: updating '"..tostring(element.type).."' has failed: "..tostring(err)..'\n')
      end
    end

    if def.children then
      instance.child_container = def.container and def.container(panel) or panel
      instance.children = reconcile_children(instance, {}, props.children)

      apply_order(instance)
    end
  elseif kind == 'component' then
    instance.component = payload
    instance.hooks = {}

    local rendered = render_component(instance)

    if rendered then
      instance.child = instantiate(rendered, container, root, instance)
    end
  else
    instance.children = reconcile_children(instance, {}, element.props.children)
  end

  return instance
end

--- Brings an instance in line with a new element of the same type.
-- @param instance [Map]
-- @param element [Map]
function update(instance, element)
  instance.element = element
  instance.key = element.key

  if instance.kind == 'host' then
    local panel = instance.panel

    if !IsValid(panel) then return end

    local def = instance.def
    local props, old_props = element.props, panel.lumen_props

    panel.lumen_props = props

    Lumen.apply_props(panel, props, old_props, def, nearest_host(instance) == nil)

    if def.update then
      local success, err = pcall(def.update, panel, props, old_props)

      if !success then
        ErrorNoHalt("Lumen: updating '"..tostring(element.type).."' has failed: "..tostring(err)..'\n')
      end
    end

    if def.children then
      instance.children = reconcile_children(instance, instance.children, props.children)

      apply_order(instance)
    end
  elseif instance.kind == 'component' then
    instance.dirty = false

    local rendered, success = render_component(instance)

    if success then
      instance.child = reconcile(instance.child, rendered, instance.container, instance.root, instance)
    end
  else
    instance.children = reconcile_children(instance, instance.children, element.props.children)
  end
end

--- Reconciles one slot of the tree: updates the instance if the element is of the same type
-- and key, replaces it otherwise.
-- @param instance [Map the instance in the slot, or nil]
-- @param element [Map the element for the slot, or nil to empty it]
-- @param container [Panel]
-- @param root [Map]
-- @param parent [Map]
-- @return [Map the instance now in the slot, or nil]
function reconcile(instance, element, container, root, parent)
  element = normalize(element)

  if !element then
    if instance then unmount(instance) end

    return nil
  end

  if instance and instance.element.type == element.type and instance.key == element.key then
    update(instance, element)

    return instance
  end

  if instance then unmount(instance) end

  return instantiate(element, container, root, parent)
end

--- Reconciles the children of a host, a fragment or the root against a list of elements,
-- matching them by key or by position.
-- @param parent [Map the instance whose children they are]
-- @param old_children [List<Map> the current instances]
-- @param children [List the new children: elements, text and false for left out children]
-- @return [List<Map> the instances now there]
function reconcile_children(parent, old_children, children)
  local container = parent.child_container or parent.container
  local by_key = {}
  local result = {}

  for k, instance in ipairs(old_children or {}) do
    by_key[instance.list_key] = instance
  end

  if istable(children) then
    for i = 1, table.maxn(children) do
      local element = normalize(children[i])

      if element then
        local list_key = element.key != nil and ('k:'..tostring(element.key)) or ('i:'..i)
        local old = by_key[list_key]

        by_key[list_key] = nil

        local instance = reconcile(old, element, container, parent.root, parent)

        if instance then
          instance.list_key = list_key
          result[#result + 1] = instance
        end
      end
    end
  end

  for list_key, instance in pairs(by_key) do
    unmount(instance)
  end

  return result
end

--- Takes an instance down: runs the effect cleanups of its components, clears its refs and
-- removes its panels.
-- @param instance [Map]
function unmount(instance)
  if !instance or instance.unmounted then return end

  instance.unmounted = true

  if instance.kind == 'host' then
    for k, child in ipairs(instance.children or {}) do
      unmount(child)
    end

    local panel = instance.panel

    if IsValid(panel) then
      Lumen.release_ref(panel, panel.lumen_props)
      panel:Remove()
    end
  elseif instance.kind == 'component' then
    Lumen.State.cleanup(instance)

    if instance.child then
      unmount(instance.child)
    end
  else
    for k, child in ipairs(instance.children or {}) do
      unmount(child)
    end
  end
end

--- Runs the effects that renders have queued, in order, skipping those of instances that
-- have been unmounted since.
local function run_effects()
  local queue = effects

  effects = {}

  for k, entry in ipairs(queue) do
    if !entry[1].unmounted then
      Lumen.State.run_effect(entry[2])
    end
  end
end

--- Queues an effect to run once the current render has been committed.
-- @param instance [Map the component instance the effect belongs to]
-- @param slot [Map the hook slot of the effect]
function Lumen.Reconciler.queue_effect(instance, slot)
  effects[#effects + 1] = { instance, slot }
end

--- Marks a component for a render on the next frame. Called when its state changes.
-- @param instance [Map component instance]
function Lumen.Reconciler.schedule(instance)
  if instance.unmounted or instance.dirty then return end

  instance.dirty = true
  dirty[#dirty + 1] = instance

  if !scheduled then
    scheduled = true

    timer.Simple(0, Lumen.Reconciler.flush)
  end
end

--- Renders the components whose state has changed since the last frame and runs the effects
-- that follow. Runs by itself on the frame after a change; call it to apply changes at once.
function Lumen.Reconciler.flush()
  scheduled = false

  local queue = dirty

  dirty = {}

  for k, instance in ipairs(queue) do
    if instance.dirty and !instance.unmounted then
      local root = instance.root

      if root and !root:is_valid() then
        instance.dirty = false
      else
        update(instance, instance.element)

        local host = nearest_host(instance)

        if host then
          apply_order(host)
        elseif root then
          root:invalidate()
        end
      end
    end
  end

  run_effects()
end

--- Checks whether a render is pending.
-- @return [Boolean]
function Lumen.Reconciler.is_pending()
  return #dirty > 0 or #effects > 0
end

--- A mounted tree: what `Lumen.mount` returns. It keeps the element at its top, the panel it
-- was mounted into and the instances in between.
class 'LumenRoot'

--- Creates a root inside a container panel. Use `Lumen.mount` instead.
-- @param container [Panel the panel the tree is mounted into]
function LumenRoot:init(container)
  self.container = container
  self.instance = nil
  self.element = nil
end

--- Checks whether the tree is mounted and its container still exists.
-- @return [Boolean]
function LumenRoot:is_valid()
  return IsValid(self.container) and self.instance != nil
end

--- Reconciles the tree against an element, or renders it again with the element it has.
-- Unmounts the tree if the container is gone.
-- @param element=nil [Map the new element at the top; the current one if nil]
-- @return [Boolean false if the container is gone]
function LumenRoot:update(element)
  if !IsValid(self.container) then
    self:unmount()

    return false
  end

  element = element or self.element

  if !element then return false end

  self.element = element
  self.instance = reconcile(self.instance, element, self.container, self, nil)

  run_effects()
  self:invalidate()

  return true
end

--- Takes the whole tree down and removes its panels. The container stays.
function LumenRoot:unmount()
  if self.instance then
    unmount(self.instance)
    self.instance = nil
  end
end

--- Returns the panels at the top of the tree.
-- @return [List<Panel>]
function LumenRoot:get_panels()
  return collect_panels(self.instance, {})
end

--- Returns the first panel at the top of the tree.
-- @return [Panel, or nil if the tree has none]
function LumenRoot:get_panel()
  return self:get_panels()[1]
end

--- Lays the whole tree out again.
function LumenRoot:invalidate()
  for k, panel in ipairs(self:get_panels()) do
    panel:InvalidateLayout()
    panel:InvalidateChildren(true)
  end
end

--- Mounts an element into a panel and returns the root of the tree.
-- ```
-- local Greeting = Lumen.load([[
--   return function(props) return <text>Hello, {props.name}!</text> end
-- ]])
--
-- self.root = Lumen.mount(Lumen.element(Greeting, { name = 'John' }), self)
-- ```
-- @param element [Map the element at the top of the tree]
-- @param container [Panel the panel to mount into]
-- @return [LumenRoot the root, or nil if the container is not valid]
function Lumen.mount(element, container)
  if !IsValid(container) then
    ErrorNoHalt('Lumen: cannot mount into an invalid panel\n')

    return nil
  end

  local root = LumenRoot.new(container)

  root:update(element)

  return root
end

--- Mounts the component of a template into a panel.
-- @param id [String template ID]
-- @param props=nil [Map props for the component]
-- @param container [Panel the panel to mount into]
-- @return [LumenRoot the root, or nil if there is no such template or the container is not
--   valid]
function Lumen.render(id, props, container)
  local component = Lumen.component(id)

  if !component then return nil end

  return Lumen.mount(Lumen.element(component, props), container)
end
