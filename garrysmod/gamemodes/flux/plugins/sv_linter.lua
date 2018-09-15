-- WIP WIP WIP

PLUGIN:set_name('Linter')
PLUGIN:set_author('Mr. Meow')
PLUGIN:set_description('Yells at you for stylistic mistakes.')

if !fl.development then return end

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
  semicolons                  = 'error'
}

local TK_KEYWORD      = 0
local TK_LITERAL      = 1
local TK_PUNCTUATION  = 2
local TK_SEPARATOR    = 3
local TK_SPACE        = 4
local TK_IDENTIFIER   = 5
local TK_COMMENT      = 6
local TK_EOF          = 7

local tokens = wk'if elseif else or and then end do for in local return while break continue function not nil false true && || ! > >= < <= == = .. ... ~= !='
local literals = wk'nil false true'
local separators = wk'| & . , ( ) [ ] { } = > < ! ~'

function read_space(code, pos, cur_char, tokens)
  local space = ''

  while cur_char:match('%s') do
    space = space + cur_char
    cur_char = code[pos + space:len()]
  end

  table.insert(tokens, { tk = space, type = TK_SPACE })

  return space:len() - 1
end

function read_number(code, pos, cur_char, tokens)
  local n = ''

  while cur_char:match('[%dx]') do
    n = n + cur_char
    cur_char = code[pos + n:len()]
  end

  table.insert(tokens, { tk = n, type = TK_LITERAL })

  return n:len() - 1
end

function read_string(code, pos, cur_char, tokens)
  local str = cur_char
  local opener = cur_char
  local skip = 0
  cur_char = code[pos + 1]

  if cur_char == opener then
    return read_long_string(code, pos + 1, cur_char, tokens)
  end

  str = str + cur_char

  while cur_char != opener do
    if skip > 0 then
      skip = skip - 1
      str = str + cur_char
      cur_char = code[pos + str:len()]
      continue
    end

    if cur_char == '\\' then
      skip = 1
      continue
    end

    str = str + cur_char
    cur_char = code[pos + str:len()]
  end

  table.insert(tokens, { tk = str, type = TK_LITERAL })

  return str:len() - 1
end

function read_comment(code, pos, cur_char, tokens)

end

function read_token(code, pos, cur_char, tokens)

end

local function lex(code, pos, tokens)
  local cur_char = code[pos]
  local next_char = code[pos + 1]

  if cur_char:match('%s') then
    return read_space(code, pos, cur_char, tokens)
  elseif cur_char:match('%d') then
    return read_number(code, pos, cur_char, tokens)
  elseif cur_char == "'" or cur_char == '"' or (cur_char == '[' and next_char == '[') then
    return read_string(code, pos, cur_char, tokens)
  elseif cur_char == '-' and next_char == '-' then
    return read_comment(code, pos, cur_char, tokens)
  elseif cur_char == '\n' then
    table.insert(tokens, { tk = '\n', type = TK_SEPARATOR })
    return 1
  else
    return read_token(code, pos, cur_char, tokens)
  end
end

local function tokenize(input)
  local tokens = {}
  local cur_buffer = ''
  local skip = 0

  for i = 1, input:len() do
    if skip > 0 then skip = skip - 1 continue end
    skip = lex(input, i, tokens) or 0
  end

  return tokens
end
