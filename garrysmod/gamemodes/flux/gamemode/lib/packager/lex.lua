--
-- A lot of ideas and principles are taken from LuaJIT's
-- source code, which is released under the following license:
-- https://github.com/LuaJIT/LuaJIT/blob/master/COPYRIGHT
--
-- Lexer. Convert input into a stream of tokens.
--

class 'Packager::Lexer'

local char = include 'char.lua'
local LUA_TOKENS = {
  ['and']      = 'and',         ['in']       = 'in',          ['..']        = 'concat',
  ['break']    = 'break',       ['local']    = 'local',       ['...']       = 'dots',
  ['do']       = 'do',          ['nil']      = 'nil',         ['==']        = 'eq',
  ['else']     = 'else',        ['not']      = 'not',         ['>=']        = 'ge',
  ['elseif']   = 'elseif',      ['or']       = 'or',          ['<=']        = 'le',
  ['end']      = 'end',         ['return']   = 'return',      ['!=']        = 'ne',
  ['false']    = 'false',       ['then']     = 'then',        ['<number>']  = 'number',
  ['for']      = 'for',         ['true']     = 'true',        ['<name>']    = 'name',
  ['function'] = 'function',    ['while']    = 'while',       ['<string>']  = 'string',
  ['if']       = 'if',          ['continue'] = 'continue',    ['<eof>']     = 'eof',
                                                              ['<comment>'] = 'comment',
  -- Luna
  ['import']   = 'import',      ['export']   = 'export',      ['class']     = 'class',
  ['func']     = 'func',        ['unless']   = 'unless',      ['until']     = 'until',
  ['+=']       = 'add_assign',  ['-=']       = 'sub_assign',  ['*=']        = 'mul_assign',
  ['/=']       = 'div_assign',  ['||=']      = 'or_assign',   ['&&=']       = 'and_assign',
  ['..=']      = 'con_assign',  ['->']       = 'arrow',
  ['elsif']    = 'elsif'
}
local TK_TO_REPRESENTATION = {}
local NAME_TO_ENUM = {}
local TK_TO_VISUAL = {}
local idx = 256

-- Generate enums
for k, v in pairs(LUA_TOKENS) do
  _G['TK_'..v] = idx
  TK_TO_REPRESENTATION[idx] = k
  NAME_TO_ENUM[k] = idx
  TK_TO_VISUAL[idx] = v
  idx = idx + 1
end

function Packager.Lexer:visualize(tk)
  if tk > 255 then
    return 'TK_'..TK_TO_VISUAL[tk]
  else
    return string.char(tk)
  end
end

function Packager.Lexer:tokenize(input)
  local tokens = {}
  local buf = ''
  local cur_pos = 1
  local line = 1

  local function peek()
    local char = input[cur_pos + 1]
    return char, string.byte(char)
  end

  local function next()
    local char = input[cur_pos + 1]
    cur_pos = cur_pos + 1
    return char, string.byte(char)
  end

  local function this()
    local char = input[cur_pos]
    return char, string.byte(char)
  end

  local function save()
    local char = input[cur_pos]
    buf = buf..char
    return char
  end

  local function save_next()
    save() return next()
  end

  local function save_manual(char)
    buf = buf..char
    return char, string.byte(char)
  end

  local function clear()
    local old_buf = buf
    buf = ''
    return old_buf
  end

  local function push(tk, val)
    table.insert(tokens, { tk = tk, val = val, line = line, pos = cur_pos })
  end

  local function lex_number(current, char_id)
    -- hex number
    if peek() == 'x' then
      save_next()

      while char.is_hex(char_id) do
        current, char_id = save_next()
      end

      push(TK_number, clear())
      return
    end

    while char.is_num(char_id) do
      current, char_id = save_next()
    end

    push(TK_number, clear())
  end

  local function read_long_string(current, char_id)
    local newlines = 0
    local buf = ''
    while true do
      current, char_id = next()
      if current == ']' and peek() == ']' then
        next() next() -- eat ] and then jump to the next fresh thing
        return buf, newlines
      elseif !current or !char_id then
        return buf, newlines
      end

      if current == '\n' then newlines = newlines + 1 end

      buf = buf..current
    end
  end

  local function read_string(current, char_id)
    local newlines = 0
    local opener = current

    current, char_id = next() -- eat opener

    while true do
      if current == opener then
        next() -- eat opener
        break
      end
  
      current, char_id = save_next()

      if current == '\\' then
        current, char_id = next()

        if     current == 'a' then save_manual('\a')
        elseif current == 'b' then save_manual('\b')
        elseif current == 'f' then save_manual('\f')
        elseif current == 'n' then save_manual('\n')
        elseif current == 'r' then save_manual('\r')
        elseif current == 't' then save_manual('\t')
        elseif current == 'v' then save_manual('\v')
        elseif current == '\n' or current == '\r' then
          save_manual('\n')
          newlines = newlines + 1
        elseif current == '\'' or current == '"' or current == '\\' then
          save_manual(current)
        end

        current, char_id = next()
      elseif current == '\n' then
        newlines = newlines + 1
      elseif !current or !char_id then
        break
      end
    end
    return clear(), newlines
  end

  -- Same basic principle as LuaJIT's lexer.
  local function lex()
    local current, char_id = this()

    if char.is_ident(char_id) and current != '!' and current != '?' then
      if char.is_num(char_id) then
        lex_number(current, char_id)
        return true
      end

      while char.is_ident(char_id) do
        current, char_id = save_next()
      end
      
      if LUA_TOKENS[buf] then
        push(NAME_TO_ENUM[buf], clear())
        return true
      end

      push(TK_name, clear())
      return true
    end

    if current == '\n' then
      line = line + 1
      next()
      return true
    elseif current == ' ' or current == '\t'
        or current == '\v' or current == '\f'
        or current == ';' then
        next()
        return true
    elseif current == '-' then
      current, char_id = next()
      -- comment
      if current == '-' then
        current, char_id = next()

        if current == '[' and next() == '[' then -- long comment
          current, char_id = next() -- eat [
          local buf, newlines = read_long_string(current, char_id)
          line = line + newlines
          push(TK_comment, buf)
          clear()
        else -- short comment
          while current != '\n' do
            current, char_id = save_next()
          end
          push(TK_comment, clear())
        end
        return true
      elseif current == '=' then
        push(TK_sub_assign, '-=')
        next() clear()
        return true
      elseif current == '>' then
        push(TK_arrow, '->')
        next() clear()
        return true
      end

      push(string.byte('-'), '-')
      return true
    elseif current == '+' then
      current, char_id = next()
      if current == '=' then
        push(TK_add_assign, '+=')
        next() clear()
        return true
      end

      push(string.byte('+'), '+')
      return true
    elseif current == '*' then
      current, char_id = next()
      if current == '=' then
        push(TK_mul_assign, '*=')
        next() clear()
        return true
      end

      push(string.byte('*'), '*')
      return true
    elseif current == '/' then
      current, char_id = next()
      if current == '=' then
        push(TK_div_assign, '/=')
        next() clear()
        return true
      elseif current == '/' then -- C-style comment (thanks garry)
        next() -- eat /
        while current != '\n' do
          current, char_id = save_next()
        end
        push(TK_comment, clear())
        return true
      elseif current == '*' then -- C-style long comment
        next() -- eat *
        while true do
          current, char_id = save_next()

          if current == '*' and peek() == '/' then
            next() -- eat *
            next() -- eat /
            break
          end
        end
        push(TK_comment, clear())
        return true
      end

      push(string.byte('/'), '/')
      return true
    elseif current == '|' then
      current, char_id = next()

      if current == '|' then
        current, char_id = next()

        if current == '=' then
          push(TK_or_assign, '||=')
          next()
          return true
        end

        push(TK_or, '||')
        return true
      end

      push(string.byte('|'), '|')
      return true
    elseif current == '&' then
      current, char_id = next()

      if current == '&' then
        current, char_id = next()

        if current == '=' then
          push(TK_and_assign, '&&=')
          next()
          return true
        end

        push(TK_and, '&&')
        return true
      end

      push(string.byte('&'), '&')
      return true
    elseif current == '>' then
      current, char_id = next()
      if current != '=' then push(string.byte('>'), '>')
      else next() push(TK_ge, '>=') end
      return true
    elseif current == '<' then
      current, char_id = next()
      if current != '=' then push(string.byte('<'), '<')
      else next() push(TK_le, '<=') end
      return true
    elseif current == '!' then
      current, char_id = next()
      if current != '=' then push(string.byte('!'), '!')
      else next() push(TK_ne, '!=') end
      return true
    elseif current == '~' then
      current, char_id = next()
      if current != '=' then push(string.byte('~'), '~')
      else next() push(TK_ne, '~=') end
      return true
    elseif current == '=' then
      current, char_id = next()
      if current != '=' then push(string.byte('='), '=')
      else next() push(TK_eq, '==') end
      return true
    elseif current == '\'' or current == '"' then
      push(TK_string, read_string(current, char_id))
      return true
    elseif current == '[' and peek() == '[' then
      next() -- eat [
      next() -- eat another [
      push(TK_string, read_long_string())
      return true
    elseif current == '.' then
      current, char_id = next()

      if current == '.' then
        current, char_id = next()

        if current == '.' then
          push(TK_dots, '...')
          next()
          return true
        elseif current == '=' then
          push(TK_con_assign, '..=')
          next()
          return true
        end

        push(TK_concat, '..')
        return true
      end

      push(string.byte('.'), '.')
      return true
    elseif current and char_id then -- single-char tokens
      push(char_id, current)
      current, char_id = next()
      clear()
      return true
    end

    return false
  end

  while lex() do
    -- just loop will ya...
  end

  return tokens
end
