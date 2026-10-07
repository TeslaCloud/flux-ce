local aliases = {}

--- Makes an HTML tag name create a certain VGUI panel.
-- @param id [String tag name]
-- @param real_panel [String registered panel class name, or another alias]
function Gvue.alias(id, real_panel)
  aliases[id] = real_panel
end

--- Resolves an HTML tag name to the VGUI panel class it is an alias of, following
-- chains of aliases.
-- @param id [String tag name]
-- @return [String panel class name, or nil if the tag name is not an alias]
function Gvue.get_panel_name(id)
  local resolved = aliases[id]

  while aliases[id] do
    resolved = aliases[id]
    id = resolved
  end

  return resolved
end

--- Creates the panel for an HTML tag.
-- @param id [String tag name]
-- @param parent=nil [Panel panel to parent the new element to]
-- @return [Panel the created element]
function Gvue.spawn_panel(id, parent)
  local pane = vgui.Create(Gvue.get_panel_name(id), parent)
  pane.html.element_name = id
  return pane
end
