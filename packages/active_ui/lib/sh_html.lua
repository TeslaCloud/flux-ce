--- HTML templates, stylesheets and scripts for the panels that display web content. The files
-- in the `views/html`, `views/assets/stylesheets` and `views/assets/javascripts` folders of
-- Flux, the schema and the plugins are read on the server, stored in this library under their
-- file name without extensions, and sent to the clients as generated Lua code. Templates can
-- contain Lua code between `<?` and `?>`, as described under `Flux.HTML:render_template`. The
-- global functions `render_template`, `render_partial`, `render_stylesheet` and
-- `render_javascript` are the usual way to get their contents, both from Lua, as in
-- `self.html:set_body(render_template('help'))`, and from inside of other templates, as in
-- `<?= render_partial('credits') ?>`.
-- @module [Flux.HTML]

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

local html_entities = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['"'] = '&quot;',
  ["'"] = '&#39;'
}

--- Makes a text safe to put into HTML, as the contents of an element or as the value of a
-- quoted attribute, by replacing the characters that HTML gives a meaning to (&, <, >,
-- " and ') with their entities. Templates insert values as they are, so use it there for
-- every text that is not meant to be markup.
-- ```
-- -- In a template: <div class="name"><?= Flux.HTML:escape(target:name()) ?></div>
-- Flux.HTML:escape('<target> [reason]') -- '&lt;target&gt; [reason]'
-- ```
-- @param text [Any text to escape; anything but a string is converted to one first]
-- @return [String the escaped text, empty if the text is nil]
function Flux.HTML:escape(text)
  if text == nil then return '' end

  return (tostring(text):gsub('[&<>"\']', html_entities))
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
  local header = {}

  if istable(locals) then
    for k, v in pairs(locals) do
      if isstring(k) then
        header[#header + 1] = 'local '..k..' = '..val_to_str(v)..'\n'
      end
    end
  end

  local contents = self:get_template(id) or ''
  contents = contents:gsub('<%?([^%?]*)%?>', function(code_block)
    code_block = code_block:strip()
    local len = code_block:len()

    if code_block:start_with('=') then
      return ']]..('..code_block:sub(2, len)..')..[['
    elseif code_block:start_with('-') then
      return ']]\n'..code_block:sub(2, len)..'\n_html = _html..[['
    else
      return ']]\n'..code_block..'\n_html = _html..[['
    end
  end)

  contents = table.concat(header)..'local _html = [['..contents..']] return _html'

  local compiled = CompileString(contents, 'Template: '..id)

  return compiled()
end

local function generate_file_from_table(t, tab_name)
  local lines = { common_file_header }

  for k, v in pairs(t) do
    lines[#lines + 1] = tab_name..'["'..k..'"] = [['..v..']]\n'
  end

  return table.concat(lines)
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
    elseif !id:start_with('_') then
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

  if file_name:end_with('.js') then
    pipe = 'javascripts'
  elseif file_name:end_with('css') then
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

if SERVER then
  --- Writes the templates, the stylesheets and the scripts for the clients: a file for each
  -- of them in development, one compiled file in production.
  local function write_html()
    if IS_DEVELOPMENT then
      Flux.write_client_file('3_html.lua', Flux.HTML:generate_html_file() or '-- .keep')
      Flux.write_client_file('4_css.lua', Flux.HTML:generate_css_file() or '-- .keep')
      Flux.write_client_file('5_js.lua', Flux.HTML:generate_js_file() or '-- .keep')
    else
      print 'Compiling clientside assets...'

      local contents = (Flux.HTML:generate_html_file() or '')..' '
      contents = contents..(Flux.HTML:generate_css_file() or '')..' '
      contents = contents..(Flux.HTML:generate_js_file() or '')

      Flux.write_client_file('3_production.lua', contents)
    end
  end

  --- Hook handlers of the HTML library, registered as `FLHTMLHooks`.
  local hooks = {}

  --- Writes the HTML, CSS and JavaScript assets along with the other files that get sent to
  -- the clients.
  function hooks:FLWriteClientFiles()
    write_html()
  end

  Plugin.add_hooks('FLHTMLHooks', hooks)

  concommand.Add('fl_reload_html', function(actor)
    if !IsValid(actor) then
      print('Reloading HTML...')

      local total = tostring(table.Count(Flux.HTML.file_paths))
      local len = total:len()
      local i = 0

      Msg('  -> 0 / '..total)

      for k, v in pairs(Flux.HTML.file_paths) do
        i = i + 1
        Msg('\r  -> '..i..' / '..total)
        Flux.HTML[v.pipe][v.file_name] = File.read(k)
      end

      write_html()

      Msg ' (done)\n'
    end
  end)
end
