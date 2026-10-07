mod 'Flux::HTML'

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

--- Adds an HTML template.
-- @param id [String template ID]
-- @param contents [String source of the template]
function Flux.HTML:add_template(id, contents)
  self.templates[id] = contents
end

--- Adds a stylesheet.
-- @param id [String stylesheet ID]
-- @param contents [String CSS code]
function Flux.HTML:add_stylesheet(id, contents)
  self.stylesheets[id] = contents
end

--- Adds a script.
-- @param id [String script ID]
-- @param contents [String JavaScript code]
function Flux.HTML:add_js(id, contents)
  self.javascripts[id] = contents
end

--- Returns the contents of a stylesheet.
-- @param id [String stylesheet ID]
-- @return [String CSS code, or nil if there is no such stylesheet]
function Flux.HTML:get_stylesheet(id)
  return self.stylesheets[id]
end

--- Returns the source of a template.
-- @param id [String template ID]
-- @return [String source of the template, or nil if there is no such template]
function Flux.HTML:get_template(id)
  return self.templates[id]
end

--- Returns the contents of a script.
-- @param id [String script ID]
-- @return [String JavaScript code, or nil if there is no such script]
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

--- Renders a template to HTML. Templates can contain Lua code: '<? code ?>' runs the code,
-- and '<?= expression ?>' inserts the value of the expression into the output.
-- ```
-- -- With the 'greeting' template being: <p>Hello, <?= name ?>!</p>
-- -- this returns '<p>Hello, John!</p>'.
-- Flux.HTML:render_template('greeting', { name = 'John' })
-- ```
-- @param id [String template ID]
-- @param locals=nil [Map local variables to make available to the code of the template,
--   by name]
-- @return [String rendered HTML, empty if there is no such template]
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

--- Generates Lua code that adds all of the templates, to be sent to the clients.
-- @return [String Lua code]
function Flux.HTML:generate_html_file()
  return generate_file_from_table(self.templates, 'Flux.HTML.templates')
end

--- Generates Lua code that adds all of the stylesheets, to be sent to the clients.
-- @return [String Lua code]
function Flux.HTML:generate_css_file()
  return generate_file_from_table(self.stylesheets, 'Flux.HTML.stylesheets')
end

--- Generates Lua code that adds all of the scripts, to be sent to the clients.
-- @return [String Lua code]
function Flux.HTML:generate_js_file()
  return generate_file_from_table(self.javascripts, 'Flux.HTML.javascripts')
end

-- Template renderer
do
  local current_namespace = ''

  --- Sets the prefix that render_template adds to the template IDs.
  -- @param ns [String]
  -- @return [String the new namespace]
  function set_template_namespace(ns)
    current_namespace = ns
    return current_namespace
  end

  --- Returns the prefix that render_template adds to the template IDs.
  -- @return [String]
  function get_template_namespace()
    return current_namespace
  end

  --- Renders a template from the current template namespace to HTML.
  -- ```
  -- self.html:set_body(render_template('help'))
  -- ```
  -- @param id [String template ID]
  -- @param locals=nil [Map local variables to make available to the code of the template,
  --   by name]
  -- @return [String rendered HTML]
  -- @see [Flux.HTML#render_template]
  function render_template(id, locals)
    local prev_namespace = current_namespace

    if id:find('/') then
      current_namespace = prev_namespace..File.path(id)
    end

    local rendered = Flux.HTML:render_template(current_namespace..id, locals)
    current_namespace = prev_namespace

    return rendered
  end

  --- Renders a partial, a template whose name starts with an underscore. Meant to be called
  -- from other templates.
  -- ```
  -- -- Renders the '_credits' template.
  -- render_partial('credits')
  -- ```
  -- @param id [String ID of the partial without the leading underscore]
  -- @param locals=nil [Map local variables to make available to the code of the partial,
  --   by name]
  -- @return [String rendered HTML]
  function render_partial(id, locals)
    if id:find('/') then
      local path, name = File.path(id), File.name(id)
      id = path..'_'..name
    elseif !id:starts('_') then
      id = '_'..id
    end

    return render_template(id, locals)
  end

  --- Returns the contents of a stylesheet.
  -- @param id [String stylesheet ID]
  -- @return [String CSS code, or nil if there is no such stylesheet]
  function render_stylesheet(id)
    return Flux.HTML.stylesheets[id]
  end

  --- Returns the contents of a script.
  -- @param id [String script ID]
  -- @return [String JavaScript code, or nil if there is no such script]
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
    file_name = File.name(file_name):gsub('^([%w_]+)%..+$', '%1')
    Flux.HTML[pipe][file_name] = contents

    -- track the file
    Flux.HTML.file_paths[file_path] = { pipe = pipe, file_name = file_name }
  end
end)
