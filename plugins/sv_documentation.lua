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
  local func_data = {}
  local files = File.get_list(folder)

  for k, v in ipairs(files) do
    if v:ends('.lua') then
      table.Merge(func_data, extract_functions(File.read(v)))
    end
  end

  return func_data
end

function analyze_folder(folder)
  print('Analyzing: '..folder)

  local func_data = extract_functions_from_files(folder)

  local undocumented, partial, documented = 0, 0, 0

  for k, v in pairs(func_data) do
    if #v.comments == 0 then
      undocumented = undocumented + 1
    elseif v.comments[1].val:starts('-') then
      documented = documented + 1
    else
      partial = partial + 1
    end
  end

  print('Done! Found '..(table.Count(func_data))..' functions.')
  print('  -> '..(undocumented > 0 and undocumented or 'no')..' undocumented '..(undocumented != 1 and 'functions' or 'function'))
  print('  -> '..(partial > 0 and partial or 'no')..' partially documented '..(partial != 1 and 'functions' or 'function'))
  print('  -> '..(documented > 0 and documented or 'no')..' documented '..(documented != 1 and 'functions' or 'function'))
end

analyze_folder('gamemodes/flux/')
