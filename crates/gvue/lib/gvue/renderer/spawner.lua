local aliases = {}

function Gvue.alias(id, real_panel)
  aliases[id] = real_panel
end

function Gvue.get_panel_name(id)
  local resolved = aliases[id]

  while aliases[id] do
    resolved = aliases[id]
    id = resolved
  end

  return resolved
end

function Gvue.spawn_panel(id, parent)
  local pane = vgui.Create(Gvue.get_panel_name(id), parent)
  pane.html.element_name = id
  return pane
end
