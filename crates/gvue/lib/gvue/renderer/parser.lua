local function _is_text_node(node)
  return !node.child_nodes or node.tag_name == 'text_node'
end

local function _extract_value(node)
  local node = node.child_nodes and node.child_nodes[1] or node

  if !node then return '' end

  if _is_text_node(node) then
    return node.value
  else
    return node
  end
end

local function _spawn_node(node, parent)
  local pane = Gvue.spawn_panel(node.tag_name, parent)
  local attr = node.attr

  if _is_text_node(node) then
    pane.html.inner_html = _extract_value(node)
    pane.context.attributes.font_family = 'DermaLarge'

    print(pane.html.inner_html)
  else
    pane.draw_debug_overlay = true
  end

  if attr then
    local x, y = pane:GetPos()
    local w, h = pane:GetSize()

    if attr.x then
      x = tonumber(attr.x)
    end

    if attr.y then
      y = tonumber(attr.y)
    end

    if attr.width then
      w = tonumber(attr.width)
    end

    if attr.height then
      h = tonumber(attr.height)
    end

    pane:SetSize(w, h)
    pane:SetPos(x, y)
  end

  return pane
end

local function _process_node(node, parent, spaces)
  if !node then return parent end

  for k, v in ipairs(node) do
    print(string.rep(' ', spaces)..'<'..v.tag_name..'>')

    local this_node = _spawn_node(v, parent)

    if v.child_nodes then
      _process_node(v.child_nodes, this_node, spaces + 1)
    end

    this_node:rebuild()

    print(string.rep(' ', spaces)..'</'..v.tag_name..'>')
  end
end

function Gvue.render_html(html, parent)
  local parsed = HTMLParser:parse(html)
  local template, script, style

  PrintTable(parsed)

  for k, v in ipairs(parsed) do
    if v.tag_name == 'template' then
      template = v.child_nodes
    elseif v.tag_name == 'script' then
      script = _extract_value(v)
    elseif v.tag_name == 'style' then
      style = _extract_value(v)
    end
  end

  if template then
    if template[2] then
      error '<template> must contain only one base tag!\n'
    end

    print('<template>')

    local node_data = template[1]
    local root_node = _spawn_node(node_data)
    print(' <'..node_data.tag_name..'>')
    _process_node(node_data.child_nodes, root_node, 2)
    print(' </'..node_data.tag_name..'>')

    print('</template>')

    if script then
      CompileString(script, 'html_script')(root_node)
    end

    return root_node
  end
end

concommand.Add('gvue_test', function()
  if IsValid(__GVUE_PANE__) then
    __GVUE_PANE__:SetVisible(false)
    __GVUE_PANE__:Remove()
  end

  __GVUE_PANE__ = Gvue.render_html([[
    <template>
      <div x="128" y="64" width="512" height="256">
        <div x="16" y="40">Hey it works!</div>
        <div x="16" y="100">Sort of?</div>
      </div>
    </template>
  ]])
end)

concommand.Add('gvue_close', function()
  __GVUE_PANE__:SetVisible(false)
  __GVUE_PANE__:Remove()
end)
