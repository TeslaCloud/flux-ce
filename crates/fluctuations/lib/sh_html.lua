library 'Flux::HTML'

Flux.HTML.templates       = Flux.HTML.templates   or {}
Flux.HTML.stylesheets     = Flux.HTML.stylesheets or {}
Flux.HTML.javascripts     = Flux.HTML.javascripts or {}
Flux.HTML.file_paths      = Flux.HTML.file_paths  or {}

local common_file_header  = [[Flux = Flux or {}
Flux.HTML = Flux.HTML or {}

Flux.HTML.templates = Flux.HTML.templates or {}
Flux.HTML.stylesheets = Flux.HTML.stylesheets or {}
Flux.HTML.javascripts = Flux.HTML.javascripts or {}

]]

function Flux.HTML:add_template(id, contents)
  self.templates[id] = contents
end

function Flux.HTML:add_stylesheet(id, contents)
  self.stylesheets[id] = contents
end

function Flux.HTML:add_js(id, contents)
  self.javascripts[id] = contents
end

function Flux.HTML:get_stylesheet(id)
  return self.stylesheets[id]
end

function Flux.HTML:get_template(id)
  return self.templates[id]
end

function Flux.HTML:get_javascript(id)
  return self.javascripts[id]
end

local function val_to_str(val)
  if isstring(val) then
    return '"'..val:gsub('"', '\\"')..'"'
  elseif istable(val) then
    return 'table.deserialize("'..table.serialize(val)..'")'
  else
    return tostring(val)
  end
end

function Flux.HTML:render_template(id, locals)
  local header = ''

  if istable(locals) then
    for k, v in pairs(locals) do
      if isstring(k) then
        header = header..'local '..k..' = '..val_to_str(v)..'\n'
      end
    end
  end

  local contents = self:get_template(id) or ''
  contents = contents:gsub('<%?([^%?]*)%?>', function(code_block)
    code_block = code_block:trim()
    local len = code_block:len()

    if code_block:starts('=') then
      return ']]..('..code_block:sub(2, len)..')..[['
    elseif code_block:starts('-') then
      return ']]\n'..code_block:sub(2, len)..'\n_html = _html..[['
    else
      return ']]\n'..code_block..'\n_html = _html..[['
    end
  end)

  contents = header..'local _html = [['..contents..']] return _html'

  local compiled = CompileString(contents, 'Template: '..id)

  return compiled()
end

local function generate_file_from_table(t, tab_name)
  local final_file = common_file_header

  for k, v in pairs(t) do
    final_file = final_file..tab_name..'["'..k..'"] = [['..v..']]\n'
  end

  return final_file
end

function Flux.HTML:generate_html_file()
  return generate_file_from_table(self.templates, 'Flux.HTML.templates')
end

function Flux.HTML:generate_css_file()
  return generate_file_from_table(self.stylesheets, 'Flux.HTML.stylesheets')
end

function Flux.HTML:generate_js_file()
  return generate_file_from_table(self.javascripts, 'Flux.HTML.javascripts')
end

-- Template renderer
do
  local current_namespace = ''

  function set_template_namespace(ns)
    current_namespace = ns
    return current_namespace
  end

  function get_template_namespace()
    return current_namespace
  end

  function render_template(id, locals)
    local prev_namespace = current_namespace

    if id:find('/') then
      current_namespace = prev_namespace..File.path(id)
    end

    local rendered = Flux.HTML:render_template(current_namespace..id, locals)
    current_namespace = prev_namespace

    return rendered
  end

  function render_partial(id, locals)
    if id:find('/') then
      local path, name = File.path(id), File.name(id)
      id = path..'_'..name
    elseif !id:starts('_') then
      id = '_'..id
    end

    return render_template(id, locals)
  end

  function render_stylesheet(id)
    return Flux.HTML.stylesheets[id]
  end

  function render_javascript(id)
    return Flux.HTML.javascripts[id]
  end
end

Pipeline.register('html', function(id, file_name, pipe)
  local pipe = 'templates'

  if file_name:ends('.js') then
    pipe = 'javascripts'
  elseif file_name:ends('css') then
    pipe = 'stylesheets'
  end

  local file_path = 'gamemodes/'..file_name
  local contents = File.read(file_path)

  if contents then
    file_name = File.name(file_name:gsub('/([%w_]+)%..+$', '%1'))
    Flux.HTML[pipe][file_name] = contents

    -- track the file
    Flux.HTML.file_paths[file_path] = { pipe = pipe, file_name = file_name }
  end
end)
