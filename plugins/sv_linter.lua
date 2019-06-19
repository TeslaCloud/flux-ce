-- WIP WIP WIP

PLUGIN:set_name('Linter')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Yells at you for stylistic mistakes.')

if !Flux.development then return end
if !Settings.experimental then return end

local linter_options = {
  indent_size                 = 2,
  indent_spaces               = true,
  incorrent_indent            = 'error',
  final_newline               = true,
  logic_max_depth             = 6,
  logic_depth_exceeded        = 'warn',
  spaces_around_table_content = true,
  spaces_around_argument_list = 'error',
  spaces_around_table_index   = 'error',
  space_before_comma          = 'error',
  space_after_comma           = true,
  space_before_argument_list  = 'error',
  string_opener               = "'",
  incorrect_string_opener     = 'warn',
  empty_lines                 = 'warn',
  newline_before_return       = 'ignore',
  newline_after_local         = 'ignore',
  brackets_around_single      = 'ignore',
  max_function_name_length    = 24,
  function_name_exceeded      = 'warn',
  semicolons                  = 'error',
  max_line_length             = 175,
  allow_crlf                  = false
}

local status_colors = {
  ok    = Color(0, 255, 0),
  warn  = Color('orange'),
  error = Color(255, 0, 0)
}

local peek_length = 16

local function shoot_left(code, from_where)
  local str = ''

  for i = 1, peek_length do
    local v = code[from_where - i]

    if v == '\n' or (from_where - i) < 1 then
      break
    end

    str = v..str
  end

  return str
end

local function shoot_right(code, from_where)
  local str = ''

  for i = 1, peek_length do
    local v = code[from_where + i]

    if v == '\n' or (from_where + i) > code:len() then
      break
    end

    str = str..v
  end

  return str
end

local function point_at(source, token)
  local tk_begin = token.pos - string.len(token.val)
  local left, right = shoot_left(source, tk_begin), shoot_right(source, token.pos)
  local str = left..token.val..right
  local pointer = string.rep('-', left:len())..'^'..string.rep('-', right:len() + token.val:len() - 1)

  return str..'\n'..pointer
end

local function do_lint(file)
  local source = File.read(file)
  local tokens = LuaLexer:tokenize(source, true)
  local lines = source:split('\n')
  local error = false
  local issues = {}
  local line_len = 0
  local line_text = ''

  if linter_options.final_newline and !source:ends('\n') then
    table.insert(issues, file..':\nNo newline at the end of file.\n')
  end

  if !linter_options.allow_crlf and source:include('\r\n') then
    table.insert(issues, file..':\nWindows-style line endings (CRLF).\n')
  end

  for k, v in ipairs(lines) do
    if v:len() > linter_options.max_line_length then
      table.insert(issues, file..':\nMax line length exceeded (line '..k..')\n'..v:sub(1, linter_options.max_line_length)..'...\n')
    end
  end

  for i = 1, #tokens do
    local tk = tokens[i]

    if tk.tk == TK_comment then line_len = 0 continue end
    if tk.tk == TK_tab then
      table.insert(issues, file..':\nTabs\n'..point_at(source, tk))
      error = true
    end
  end

  if #issues > 0 then
    if error then
      return 'error', table.concat(issues, '\n'), #issues
    else
      return 'warn', table.concat(issues, '\n'), #issues
    end
  end

  return 'ok'
end

function lint_folder(folder)
  local files = File.get_list(folder)
  local issues = {}
  local total_files = 0
  local total_issues = 0

  print('Checking files in '..folder)

  for k, v in ipairs(files) do
    if v:starts('.') or !v:ends('.lua') or v:ends('.min.lua') then continue end

    local status, message, n_issues = do_lint(v)

    if message then
      table.insert(issues, { status, message })

      total_issues = total_issues + n_issues
    end
  
    MsgC(status_colors[status], '.')

    total_files = total_files + 1
  end

  print ''

  if #issues > 0 then
    for k, v in ipairs(issues) do
      MsgC(status_colors[v[1]], v[2]..'\n')
    end
  end

  print('Found total of '..total_issues..' issues in '..total_files..' files.')
end

--lint_folder('gamemodes/flux/')
