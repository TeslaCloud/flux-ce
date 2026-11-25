--- Server side of the registry of templates: the `lumen` pipeline reads every template file,
-- compiles it and checks that the result is valid Lua, and `Lumen.write_client_files` turns the
-- templates into Lua files for the clients. A generated file holds the code of its template as
-- a function, so it reaches the clients like any other Lua file. `lumen_reload` in the server
-- console compiles every template again.
-- @module [Lumen]

local file_paths = Lumen.file_paths

--- Reads a template file, compiles it and stores it under the given ID. Templates whose
-- compilation fails, or whose code is not valid Lua, are stored with their error, so that the
-- clients can report it.
-- @param id [String template ID]
-- @param file_name [String path of the file relative to the Lua search path, such as
--   PACKAGE.__path__..'views/lumen/help.lumen']
-- @return [Map the stored template, or nil if the file could not be read]
function Lumen.include_file(id, file_name)
  local source = file.Read(file_name, 'LUA')

  if !source then
    ErrorNoHalt("Lumen: could not read the '"..file_name.."' template!\n")

    return
  end

  local existing = Lumen.find_template(id)

  if existing and existing.path and existing.path != file_name then
    ErrorNoHalt("Lumen: the '"..id.."' template of '"..file_name.."' replaces the one of '"..existing.path.."'!\n")
  end

  local code, err = Lumen.compile(source, file_name)

  if code then
    local chunk = CompileString(Lumen.chunk_header..code, file_name, false)

    if !isfunction(chunk) then
      code, err = nil, tostring(chunk)
    end
  end

  if err then
    ErrorNoHalt('Lumen: '..err..'\n')
  end

  file_paths[file_name] = id

  return Lumen.define(id, file_name, code, err)
end

--- Generates the Lua code that gives a template to the clients. The clients include the
-- generated files before Lumen itself loads, so the code only fills `Flux.lumen_sources`,
-- which Lumen reads once it is there. The code of the template becomes the body of a function
-- whose header is on the first line, so the lines of the file are the lines of the template.
-- @param template [Map a stored template]
-- @return [String Lua code]
function Lumen.generate_client_code(template)
  local head = 'Flux.lumen_sources = Flux.lumen_sources or {} '..
    'Flux.lumen_sources['..string.format('%q', template.id)..'] = { '..
    'path = '..string.format('%q', template.path or template.id)..', '

  if !template.code then
    return head..'error = '..string.format('%q', tostring(template.error))..' }\n'
  end

  return head..'code = function(...) '..Lumen.chunk_header..template.code..'\nend }\n'
end

--- Writes a client file for every stored template. Called while the files that get sent to
-- the clients are written.
function Lumen.write_client_files()
  for id, template in pairs(Lumen.templates) do
    Flux.write_client_file('3_lumen_'..id..'.lua', Lumen.generate_client_code(template))
  end
end

Pipeline.register('lumen', function(id, file_name, _pipe)
  Lumen.include_file(id, file_name)
end)

concommand.Add('lumen_reload', function(actor)
  if IsValid(actor) then return end

  print('Recompiling Lumen templates...')

  for file_name, id in pairs(file_paths) do
    Lumen.include_file(id, file_name)
  end

  Lumen.write_client_files()

  print('Done. Clients get the new templates when they reconnect.')
end)
