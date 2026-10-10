--- Lumen builds Derma interfaces from templates. A template is a `.lumen` file in the
-- `views/lumen` folder of Flux, of the schema or of a plugin: Lua code with markup in it that
-- returns a component, a function that takes a table of props and returns a tree of elements
-- (see `Lumen.Compiler` for the markup). The server compiles the templates to Lua and sends
-- them to the clients, where `Lumen.component` gives the component of a template by its ID,
-- the file name without the extension, and `Lumen.render` mounts it into a panel:
-- ```
-- -- views/cl_help.lua
-- function PANEL:Init()
--   self.root = Lumen.render('help', { pages = Flux.Help:get_pages() }, self)
-- end
--
-- function PANEL:rebuild()
--   self.root:update()
-- end
-- ```
-- Elements are mapped to real vgui panels by the reconciler (`Lumen.mount`, `Lumen.Reconciler`):
-- intrinsic elements such as `view`, `text`, `button` and `scroll` become Lumen's own panels,
-- `image`, `input`, `checkbox`, `combo`, `slider`, `avatar` and `model` become the stock Derma
-- controls, and the registry in `Lumen.register_element` takes more. Components keep state
-- with `Lumen.use_state` and friends, and `view` lays its children out with flexbox
-- (`Lumen.Layout`) from the `style` prop (`Lumen.Style`).
--
-- This file holds the registry of templates. `Lumen.define` stores a compiled template under
-- its ID, on the server when the `lumen` pipeline reads the file and on the client when the
-- generated files are loaded; `Lumen.load` compiles and runs a template from a string, which is
-- handy in the console and in tests.
-- @module [Lumen]

local templates = istable(Lumen) and Lumen.templates or {}
local file_paths = istable(Lumen) and Lumen.file_paths or {}

mod 'Lumen'

Lumen.templates = templates
Lumen.file_paths = file_paths

--- The type of a fragment element, whose children are put straight into the parent. The
-- compiler uses it for `<>...</>`.
Lumen.Fragment = { lumen_fragment = true }

local isstring   = isstring
local istable    = istable
local isfunction = isfunction
local tostring   = tostring
local pcall      = pcall

local chunk_header = 'local use_state, use_effect, use_ref, use_memo = '..
  'Lumen.use_state, Lumen.use_effect, Lumen.use_ref, Lumen.use_memo '

--- Compiles a template to Lua code without raising errors.
-- @param source [String template source]
-- @param name='lumen' [String name used in error messages]
-- @return [String Lua code, or nil if the template is malformed, String the error message in
--   that case]
function Lumen.compile(source, name)
  local success, result = pcall(Lumen.Compiler.compile, source, name)

  if !success then
    return nil, tostring(result)
  end

  return result
end

--- Turns compiled template code into the value the template returns: its component, usually.
-- The code is run with the hooks `use_state`, `use_effect`, `use_ref` and `use_memo` in scope.
-- @param code [String Lua code, as returned by Lumen.compile]
-- @param name='lumen' [String name used in error messages]
-- @return [Any what the template returns, or nil if it does not compile or fails to run, String
--   the error message in that case]
function Lumen.evaluate(code, name)
  name = name or 'lumen'

  local chunk = CompileString(chunk_header..code, name, false)

  if !isfunction(chunk) then
    return nil, tostring(chunk)
  end

  local success, result = pcall(chunk, name)

  if !success then
    return nil, tostring(result)
  end

  return result
end

--- Compiles and runs a template given as a string, and returns its component. Templates in
-- files go through `Lumen.component` instead; this is for the console and for tests.
-- ```
-- local Greeting = Lumen.load([[
--   return function(props)
--     return <text>Hello, {props.name}!</text>
--   end
-- ]])
--
-- Lumen.mount(Lumen.element(Greeting, { name = 'John' }), parent)
-- ```
-- @param source [String template source]
-- @param name='lumen' [String name used in error messages]
-- @return [Any what the template returns, or nil if it is malformed or fails to run, String the
--   error message in that case]
function Lumen.load(source, name)
  local code, err = Lumen.compile(source, name)

  if !code then return nil, err end

  return Lumen.evaluate(code, name)
end

--- Stores a compiled template under an ID. Replaces the template that has the same ID and
-- forgets its component, so that the next `Lumen.component` call evaluates the new code.
-- @param id [String template ID]
-- @param path [String path of the template file, used in error messages]
-- @param code [String compiled Lua code, nil if the template did not compile]
-- @param err=nil [String why the template did not compile]
-- @return [Map the stored template]
function Lumen.define(id, path, code, err)
  local template = {
    id = id,
    path = path,
    code = code,
    error = err
  }

  templates[id] = template

  return template
end

--- Returns a stored template.
-- @param id [String template ID]
-- @return [Map the template: id, path, code and error, or nil if there is no such template]
function Lumen.find_template(id)
  return templates[id]
end

--- Returns every stored template.
-- @return [Map templates keyed by ID]
function Lumen.all_templates()
  return templates
end

--- Returns what the template with the given ID returns, usually its component. The template
-- is evaluated the first time it is asked for and the result is kept. A template that did not
-- compile or that fails to run is reported in the console once and gives nil.
-- @param id [String template ID: the file name without the extension]
-- @return [Function/Map the component, or nil if there is no such template or it is broken]
function Lumen.component(id)
  local template = templates[id]

  if !template then
    ErrorNoHalt("Lumen: there is no '"..tostring(id).."' template!\n")

    return
  end

  if template.evaluated then
    return template.component
  end

  template.evaluated = true

  if !template.code then
    ErrorNoHalt("Lumen: the '"..id.."' template did not compile: "..tostring(template.error)..'\n')

    return
  end

  local component, err = Lumen.evaluate(template.code, template.path or id)

  if component == nil then
    ErrorNoHalt("Lumen: the '"..id.."' template has failed to run: "..tostring(err)..'\n')

    return
  end

  template.component = component

  return component
end

--- Returns what a template returns, for templates that use other templates. The same as
-- `Lumen.component`.
-- ```
-- local Card = Lumen.require('card')
--
-- return function(props)
--   return <Card title={props.title} />
-- end
-- ```
-- @param id [String template ID]
-- @return [Function/Map the component, or nil if there is no such template or it is broken]
function Lumen.require(id)
  return Lumen.component(id)
end

--- Merges tables of props into one, later tables overriding earlier ones. The compiler calls
-- it for elements with `{...spread}` attributes; nil arguments are skipped.
-- @param ... [Vararg Map tables of props]
-- @return [Map]
function Lumen.props(...)
  local merged = {}

  for i = 1, select('#', ...) do
    local props = select(i, ...)

    if istable(props) then
      for k, v in pairs(props) do
        merged[k] = v
      end
    end
  end

  return merged
end

--- Calls a function for every item of a list and collects what it returns, leaving out nil
-- and false. This is the way to render a list of elements inside of markup.
-- ```
-- <view>
--   {Lumen.map(props.items, function(item, index)
--     return <text key={item.id}>{index..'. '..item.name}</text>
--   end)}
-- </view>
-- ```
-- @param list [List items to go through; nothing happens if it is not a table]
-- @param callback [Function receives the item and its index, returns what to collect]
-- @return [List what the callback returned, in order]
function Lumen.map(list, callback)
  local results = {}

  if !istable(list) then return results end

  for i = 1, #list do
    local result = callback(list[i], i)

    if result != nil and result != false then
      results[#results + 1] = result
    end
  end

  return results
end

if SERVER then
  --- Reads a template file, compiles it and stores it under the given ID. Templates whose
  -- compilation fails are stored with their error, so that the clients can report it.
  -- @param id [String template ID]
  -- @param file_name [String path of the file relative to the Lua search path, such as
  --   'flux/packages/active_ui/views/lumen/help.lumen']
  -- @return [Map the stored template, or nil if the file could not be read]
  function Lumen.include_file(id, file_name)
    local path = 'gamemodes/'..file_name
    local source = File.read(path)

    if !source then
      ErrorNoHalt("Lumen: could not read the '"..file_name.."' template!\n")

      return
    end

    local existing = templates[id]

    if existing and existing.path and existing.path != file_name then
      ErrorNoHalt("Lumen: the '"..id.."' template of '"..file_name.."' replaces the one of '"..existing.path.."'!\n")
    end

    local code, err = Lumen.compile(source, file_name)

    if err then
      ErrorNoHalt('Lumen: '..err..'\n')
    end

    file_paths[file_name] = id

    return Lumen.define(id, file_name, code, err)
  end

  --- Picks a level of long brackets that does not occur in a text.
  -- @param text [String]
  -- @return [String the equals signs of the level, from none upwards]
  local function bracket_level(text)
    local level = ''

    while text:find(']'..level..']', 1, true) do
      level = level..'='
    end

    return level
  end

  --- Generates the Lua code that gives a template to the clients. The clients include the
  -- generated files before Lumen itself loads, so the code only fills `Flux.lumen_sources`,
  -- which Lumen reads once it is there.
  -- @param template [Map a stored template]
  -- @return [String Lua code]
  function Lumen.generate_client_code(template)
    local lines = {
      'Flux.lumen_sources = Flux.lumen_sources or {}\n',
      'Flux.lumen_sources['..string.format('%q', template.id)..'] = {\n',
      '  path = '..string.format('%q', template.path or template.id)..',\n'
    }

    if template.code then
      local level = bracket_level(template.code)

      lines[#lines + 1] = '  code = ['..level..'[\n'..template.code..']'..level..']'
    else
      lines[#lines + 1] = '  error = '..string.format('%q', tostring(template.error))
    end

    lines[#lines + 1] = '\n}\n'

    return table.concat(lines)
  end

  --- Writes one file per template for the clients, named after the template.
  local function write_client_files()
    for id, template in pairs(templates) do
      Flux.write_client_file('3_lumen_'..id..'.lua', Lumen.generate_client_code(template))
    end
  end

  Pipeline.register('lumen', function(id, file_name, pipe)
    Lumen.include_file(id, file_name)
  end)

  --- Hook handlers of Lumen, registered as `LumenHooks`.
  local hooks = {}

  --- Writes the compiled templates along with the other files that get sent to the clients.
  function hooks:FLWriteClientFiles()
    write_client_files()
  end

  Plugin.add_hooks('LumenHooks', hooks)

  concommand.Add('lumen_reload', function(actor)
    if IsValid(actor) then return end

    print('Recompiling Lumen templates...')

    for file_name, id in pairs(file_paths) do
      Lumen.include_file(id, file_name)
    end

    write_client_files()

    print('Done. Clients get the new templates when they reconnect.')
  end)
else
  if istable(Flux) and istable(Flux.lumen_sources) then
    for id, source in pairs(Flux.lumen_sources) do
      Lumen.define(id, source.path, source.code, source.error)
    end
  end
end
