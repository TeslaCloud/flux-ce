-- WIP WIP WIP

PLUGIN:set_name('Documentation Generator')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Generates documentation for Flux and/or your schema.')

if !Flux.development then return end
if !Settings.experimental then return end

local green, orange, red = Color(0, 255, 0), Color(255, 150, 0), Color(255, 0, 0)

local openers = {
  [TK_then] = true,
  [TK_do] = true
}

local function extract_functions(code)
  local tokens = LuaLexer:tokenize(code)
  local func_data = {}
  local opens = 0
  local skip_next = false
  local comments_stack = {}
  local i = 0

  while i < #tokens do
    i = i + 1
    local v = tokens[i]

    -- Ignore anything outside the global level.
    if openers[v.tk] then
      opens = opens + 1
      continue
    elseif opens > 0 and v.tk == TK_end then
      opens = opens - 1
      continue
    elseif opens > 0 then
      continue
    elseif v.tk == TK_comment then
      table.insert(comments_stack, v)
      continue
    end

    if v.tk == TK_local then
      if tokens[i + 1].tk == TK_function then
        opens = opens + 1
        continue
      end
    end

    if v.tk == TK_function then
      if tokens[i + 1].tk != TK_name then
        opens = opens + 1
        continue
      end

      opens = opens + 1
      i = i + 1
      v = tokens[i]

      local func_name = ''

      while v and v.tk != TK_lparen do
        func_name = func_name..v.val
        i = i + 1
        v = tokens[i]
      end

      func_data[func_name] = { name = func_name, comments = comments_stack }
    end

    comments_stack = {}
  end

  return func_data
end

local function extract_functions_from_files(folder)
  local stdlib, crates, plugins = {}, {}, {}
  local files = File.get_list(folder)

  for k, v in ipairs(files) do
    if v:ends('.lua') then
      if v:find('plugins/') then
        local plugin_name = v:match('plugins/([%w_%.]+)')
        if !plugin_name then continue end
        plugins[plugin_name] = plugins[plugin_name] or {}
        table.Merge(plugins[plugin_name], extract_functions(File.read(v)))
      elseif v:find('crates/') then
        local crate_name = v:match('crates/([%w_%.]+)/')
        if !crate_name then continue end
        crates[crate_name] = crates[crate_name] or {}
        table.Merge(crates[crate_name], extract_functions(File.read(v)))
      else
        table.Merge(stdlib, extract_functions(File.read(v)))
      end
    end
  end

  return stdlib, crates, plugins
end

local function render_html_for(name, data)
  local globals = {}
  local class_methods = {}
  local modules = {}
  local hooks = {}

  for k, v in SortedPairs(data) do
    if k:find('%.') then
      if k:find(':') then
        table.insert(class_methods, k)
      else
        table.insert(modules, k)
      end
    elseif k:find(':') then
      if k:find('^GM:') then
        table.insert(hooks, k)
      else
        table.insert(class_methods, k)
      end
    else
      table.insert(globals, k)
    end
  end

  local out = '<!DOCTYPE html><html lang="en"><head><style>.function { display: flex; flex-flow: row; padding: 4px; }'
  out = out..'.container { display: flex; flex-flow: column; font-family: Arial; }'
  out = out..'.category_title { font-size: 32px; font-weight: bold; padding: 8px; }'
  out = out..'</style><body>'
  out = out..'<div class="container">'

  out = out..'<div class="category_title">'..name..'</div>'
  out = out..'<div class="category_title">Globals</div>'
  for k, v in ipairs(globals) do
    out = out..'<div class="function">'..tostring(v)..'( ... )</div>'
  end

  out = out..'<div class="category_title">Class Methods</div>'
  for k, v in ipairs(class_methods) do
    out = out..'<div class="function">'..tostring(v)..'( ... )</div>'
  end

  out = out..'<div class="category_title">Module Methods</div>'
  for k, v in ipairs(modules) do
    out = out..'<div class="function">'..tostring(v)..'( ... )</div>'
  end

  out = out..'<div class="category_title">Hooks</div>'
  for k, v in ipairs(hooks) do
    out = out..'<div class="function">'..tostring(v)..'( ... )</div>'
  end

  out = out..'</div></body></html>'

  return out
end

function analyze_folder(folder)
  print('Analyzing: '..folder)

  local stdlib, crates, plugins = extract_functions_from_files(folder)
  local index_file = '<!DOCTYPE html><html lang="en"><body>'

  print 'Rendering HTML documentation...'
  print '  -> stdlib'
  File.write('gamemodes/flux/docs/stdlib/index.html', render_html_for('stdlib', stdlib))

  index_file = index_file..'<h2>Flux</h2><a href="stdlib/index.html">stdlib</a><br><h2>Crates</h2>'

  print '  -> crates'
  for name, data in SortedPairs(crates) do
    print('    '..name)
    File.write('gamemodes/flux/docs/crates/'..name:underscore()..'.html', render_html_for(name, data))
    index_file = index_file..'<a href="crates/'..name:underscore()..'.html">'..name..'</a><br>'
  end

  index_file = index_file..'<h2>Plugins</h2>'

  print '  -> plugins'
  for name, data in SortedPairs(plugins) do
    print('    '..name)
    File.write('gamemodes/flux/docs/plugins/'..name:underscore()..'.html', render_html_for(name, data))
    index_file = index_file..'<a href="plugins/'..name:underscore()..'.html">'..name..'</a><br>'
  end

  File.write('gamemodes/flux/docs/index.html', index_file..'</body></html>')
end

analyze_folder('gamemodes/flux/')
