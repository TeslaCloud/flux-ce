--- The compiler of Lumen templates. A template is Lua code in which markup may appear wherever
-- an expression may:
-- ```
-- local Card = Lumen.require('card')
--
-- return function(props)
--   return <view style={{ padding = 8, gap = 4 }}>
--     <text style={{ font = 'text_normal' }}>Hello, {props.name}!</text>
--     {Lumen.map(props.items, function(item)
--       return <Card key={item.id} item={item} />
--     end)}
--     {props.loading and <text>Loading...</text>}
--   </view>
-- end
-- ```
-- The compiler turns every piece of markup into a call to `Lumen.element` and leaves the rest of
-- the code as it is, newlines included, so that the line numbers in error messages match the
-- template. The rules are:
--
-- * A tag whose name starts with a lower case letter is an intrinsic element (`view`, `text`,
--   `button`, ...) or the ID of another template, and is passed on as a string. A tag whose name
--   starts with an upper case letter, or has a dot in it, is a component: a Lua expression such
--   as `Card` or `Flux.Panels.Card` that is in scope.
-- * `<>...</>` is a fragment: its children are put straight into the parent.
-- * An attribute is `name="text"`, `name='text'`, `name={expression}` or just `name`, which
--   stands for true. `{...expression}` among the attributes spreads a table of props into the
--   element, in the order written.
-- * Children are text, nested elements and `{expression}` splices. An expression may yield an
--   element, a string or a number (text), a list of any of these, or nil and false, which are
--   left out. Text that spans several lines is trimmed line by line and joined with spaces,
--   and the character entities `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;`,
--   `&#NN;` and `&#xHH;` are decoded.
-- * `<!-- ... -->` is a comment.
--
-- A `<` is taken as the start of markup when it is followed by a name or by `>` and the token
-- before it cannot end an operand: `a < b` and `#list < 3` remain comparisons, while
-- `return <view/>`, `{ <view/> }`, `x = cond and <view/>` and `f(<view/>)` are markup.
-- @module [Lumen.Compiler]

mod 'Lumen::Compiler'

local isstring      = isstring
local string_byte   = string.byte
local string_char   = string.char
local string_find   = string.find
local string_format = string.format
local string_match  = string.match
local string_rep    = string.rep
local string_sub    = string.sub
local table_concat  = table.concat
local tonumber      = tonumber

local keywords = {
  ['and'] = true, ['break'] = true, ['do'] = true, ['else'] = true, ['elseif'] = true,
  ['end'] = true, ['false'] = true, ['for'] = true, ['function'] = true, ['if'] = true,
  ['in'] = true, ['local'] = true, ['nil'] = true, ['not'] = true, ['or'] = true,
  ['repeat'] = true, ['return'] = true, ['then'] = true, ['true'] = true, ['until'] = true,
  ['while'] = true, ['continue'] = true, ['goto'] = true
}

local operand_keywords = {
  ['end'] = true, ['true'] = true, ['false'] = true, ['nil'] = true
}

local named_entities = {
  amp = '&', lt = '<', gt = '>', quot = '"', apos = "'", nbsp = ' '
}

local string_escapes = {
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t', ['"'] = '\\"', ['\\'] = '\\\\'
}

--- Returns the line a position of the source is on.
-- @param state [Map compiler state]
-- @param pos [Number position in the source]
-- @return [Number line number, starting at 1]
local function line_of(state, pos)
  local _, count = string_sub(state.src, 1, pos - 1):gsub('\n', '')

  return count + 1
end

--- Raises a compile error that names the template and the line.
-- @param state [Map compiler state]
-- @param pos [Number position in the source the error is at]
-- @param message [String what is wrong]
local function fail(state, pos, message)
  error(state.name..':'..line_of(state, pos)..': '..message, 0)
end

--- Counts the newlines in a piece of text.
-- @param text [String]
-- @return [Number]
local function count_newlines(text)
  local _, count = text:gsub('\n', '')

  return count
end

--- Encodes a code point as UTF-8.
-- @param code [Number code point]
-- @return [String the encoded character, or an empty string for an invalid code point]
local function utf8_char(code)
  if utf8 and utf8.char then
    return utf8.char(code)
  end

  if code < 0x80 then
    return string_char(code)
  elseif code < 0x800 then
    return string_char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
  elseif code < 0x10000 then
    return string_char(
      0xE0 + math.floor(code / 0x1000),
      0x80 + math.floor(code / 0x40) % 0x40,
      0x80 + code % 0x40
    )
  elseif code < 0x110000 then
    return string_char(
      0xF0 + math.floor(code / 0x40000),
      0x80 + math.floor(code / 0x1000) % 0x40,
      0x80 + math.floor(code / 0x40) % 0x40,
      0x80 + code % 0x40
    )
  end

  return ''
end

--- Replaces the character entities in a text with the characters they stand for.
-- @param text [String]
-- @return [String]
local function decode_entities(text)
  if !string_find(text, '&', 1, true) then return text end

  return (text:gsub('&(#?)(x?)([%w]+);', function(hash, hex, body)
    if hash == '' then
      return named_entities[body] or ('&'..body..';')
    end

    local code = tonumber(body, hex == 'x' and 16 or 10)

    if !code then
      return '&'..hash..hex..body..';'
    end

    return utf8_char(code)
  end))
end

--- Turns a text into a Lua string literal.
-- @param text [String]
-- @return [String double quoted literal]
local function lua_string(text)
  return '"'..text:gsub('[%c"\\]', function(char)
    return string_escapes[char] or string_format('\\%03d', string_byte(char))
  end)..'"'
end

--- Cleans up the text between tags: text on a single line is kept as it is, text
-- that spans several lines is trimmed line by line, empty lines are dropped and the rest is
-- joined with single spaces.
-- @param raw [String text as written in the template]
-- @return [String]
local function clean_text(raw)
  if !string_find(raw, '\n', 1, true) then
    return raw
  end

  local lines = {}

  for line in (raw..'\n'):gmatch('([^\n]*)\n') do
    line = string_match(line, '^%s*(.-)%s*$')

    if line != '' then
      lines[#lines + 1] = line
    end
  end

  return table_concat(lines, ' ')
end

--- Finds the end of a long bracket (`[[...]]`, `[=[...]=]` and so on) that starts at a position.
-- @param src [String source]
-- @param pos [Number position of the opening bracket]
-- @return [Number position right after the closing bracket, or nil if the position does not
--   start a long bracket, or false if the long bracket is not closed]
local function long_bracket_end(src, pos)
  local level = string_match(src, '^%[(=*)%[', pos)

  if !level then return nil end

  local _, close = string_find(src, ']'..level..']', pos + #level + 2, true)

  if !close then return false end

  return close + 1
end

--- Finds the end of a quoted Lua string that starts at a position.
-- @param state [Map compiler state]
-- @param pos [Number position of the opening quote]
-- @return [Number position right after the closing quote]
local function quoted_string_end(state, pos)
  local src = state.src
  local quote = string_sub(src, pos, pos)
  local i = pos + 1

  while true do
    local char = string_sub(src, i, i)

    if char == '' or char == '\n' then
      fail(state, pos, 'unfinished string')
    elseif char == '\\' then
      i = i + 2
    elseif char == quote then
      return i + 1
    else
      i = i + 1
    end
  end
end

--- Finds the end of a comment that starts at a position: a Lua comment (`--`, `--[[ ]]`) or
-- one of the GLua kinds (`//`, `/* */`).
-- @param state [Map compiler state]
-- @param pos [Number position of the first character of the comment]
-- @return [Number position right after the comment, the newline of a line comment not included]
local function comment_end(state, pos)
  local src = state.src
  local start = string_sub(src, pos, pos + 1)

  if start == '--' then
    local close = long_bracket_end(src, pos + 2)

    if close then return close end

    if close == false then fail(state, pos, 'unfinished long comment') end
  elseif start == '/*' then
    local _, close = string_find(src, '*/', pos + 2, true)

    if !close then fail(state, pos, 'unfinished block comment') end

    return close + 1
  end

  return (string_find(src, '\n', pos, true) or #src + 1)
end

--- Finds the end of a number that starts at a position.
-- @param src [String source]
-- @param pos [Number position of the first character of the number]
-- @return [Number position right after the number]
local function number_end(src, pos)
  local i = pos
  local hex = string_match(src, '^0[xX]', pos) != nil

  while true do
    local char = string_sub(src, i, i)

    if char == '' then return i end

    if string_match(char, '[%w_%.]') then
      i = i + 1
    elseif (char == '+' or char == '-') and string_match(string_sub(src, i - 1, i - 1), hex and '[pP]' or '[eE]') then
      i = i + 1
    else
      return i
    end
  end
end

--- Checks whether a `<` at a position starts markup rather than being the less-than operator.
-- @param src [String source]
-- @param pos [Number position of the `<`]
-- @param last [String kind of the token before it: 'operand', 'operator' or nil at the start]
-- @return [Boolean]
local function starts_markup(src, pos, last)
  local next_char = string_sub(src, pos + 1, pos + 1)

  if next_char != '>' and !string_match(next_char, '[%a_]') then
    return false
  end

  return last != 'operand'
end

local transform
local parse_element

--- Copies Lua code from the current position, replacing every piece of markup with a call to
-- `Lumen.element`. Stops at the end of the source, or at the `}` that closes the expression
-- when asked to.
-- @param state [Map compiler state; `pos` is where to start and is left at the `}` when
--   stopping there]
-- @param stop_at_brace [Boolean stop at the first `}` that is not matched by a `{` of its own]
-- @return [String the transformed code, Number how many tokens other than comments and spaces
--   it has]
function transform(state, stop_at_brace)
  local src, len = state.src, state.len
  local buf = {}
  local last = nil
  local depth = 0
  local tokens = 0
  local pos = state.pos

  while pos <= len do
    local char = string_sub(src, pos, pos)
    local pair = string_sub(src, pos, pos + 1)

    if string_match(char, '%s') then
      local stop = string_match(src, '^%s+()', pos)

      buf[#buf + 1] = string_sub(src, pos, stop - 1)
      pos = stop
    elseif pair == '--' or pair == '//' or pair == '/*' then
      local stop = comment_end(state, pos)

      buf[#buf + 1] = string_sub(src, pos, stop - 1)
      pos = stop
    elseif char == '"' or char == "'" then
      local stop = quoted_string_end(state, pos)

      buf[#buf + 1] = string_sub(src, pos, stop - 1)
      pos = stop
      last = 'operand'
      tokens = tokens + 1
    elseif char == '[' then
      local stop = long_bracket_end(src, pos)

      if stop == false then
        fail(state, pos, 'unfinished long string')
      elseif stop then
        buf[#buf + 1] = string_sub(src, pos, stop - 1)
        pos = stop
        last = 'operand'
      else
        buf[#buf + 1] = char
        pos = pos + 1
        last = 'operator'
      end

      tokens = tokens + 1
    elseif string_match(char, '%d') or (char == '.' and string_match(string_sub(src, pos + 1, pos + 1), '%d')) then
      local stop = number_end(src, pos)

      buf[#buf + 1] = string_sub(src, pos, stop - 1)
      pos = stop
      last = 'operand'
      tokens = tokens + 1
    elseif string_match(char, '[%a_]') then
      local stop = string_match(src, '^[%w_]+()', pos)
      local word = string_sub(src, pos, stop - 1)

      buf[#buf + 1] = word
      pos = stop
      tokens = tokens + 1

      if keywords[word] then
        last = operand_keywords[word] and 'operand' or 'operator'
      else
        last = 'operand'
      end
    elseif char == '<' and starts_markup(src, pos, last) then
      state.pos = pos
      buf[#buf + 1] = parse_element(state)
      pos = state.pos
      last = 'operand'
      tokens = tokens + 1
    elseif char == '{' then
      depth = depth + 1
      buf[#buf + 1] = char
      pos = pos + 1
      last = 'operator'
      tokens = tokens + 1
    elseif char == '}' then
      if stop_at_brace and depth == 0 then
        state.pos = pos

        return table_concat(buf), tokens
      end

      depth = depth - 1
      buf[#buf + 1] = char
      pos = pos + 1
      last = 'operand'
      tokens = tokens + 1
    elseif char == ')' or char == ']' then
      buf[#buf + 1] = char
      pos = pos + 1
      last = 'operand'
      tokens = tokens + 1
    elseif string_sub(src, pos, pos + 2) == '...' then
      buf[#buf + 1] = '...'
      pos = pos + 3
      last = 'operand'
      tokens = tokens + 1
    else
      buf[#buf + 1] = char
      pos = pos + 1
      last = 'operator'
      tokens = tokens + 1
    end
  end

  if stop_at_brace then
    fail(state, state.pos, "unfinished expression: '}' expected")
  end

  state.pos = pos

  return table_concat(buf), tokens
end

--- Skips spaces at a position.
-- @param src [String source]
-- @param pos [Number]
-- @return [Number position of the first character that is not a space, Number how many
--   newlines were skipped]
local function skip_spaces(src, pos)
  local stop = string_match(src, '^%s*()', pos)

  return stop, count_newlines(string_sub(src, pos, stop - 1))
end

--- Turns an attribute name into the key of a table constructor.
-- @param name [String]
-- @return [String `name = ` for plain identifiers, `['name'] = ` otherwise]
local function table_key(name)
  if string_match(name, '^[%a_][%w_]*$') and !keywords[name] then
    return name..' = '
  end

  return '['..lua_string(name)..'] = '
end

--- Parses one element, with its attributes and children, starting at its `<`, and returns
-- the Lua code that creates it. Newlines inside of the markup are kept in the code at the
-- places where they were, so that the lines of embedded expressions do not move.
-- @param state [Map compiler state; `pos` is at the `<` and is left right after the element]
-- @return [String Lua code]
function parse_element(state)
  local src, len = state.src, state.len
  local start = state.pos
  local pos = start + 1
  local pending = 0

  --- Returns the newlines that were skipped since the last time, so that they can be put
  -- in front of the next piece of code.
  -- @return [String]
  local function flush()
    local newlines = string_rep('\n', pending)

    pending = 0

    return newlines
  end

  local tag, type_code

  if string_sub(src, pos, pos) == '>' then
    type_code = 'Lumen.Fragment'
    pos = pos + 1
  else
    tag = string_match(src, '^[%a_][%w_%.%-]*', pos)

    if !tag then
      fail(state, start, 'tag name expected')
    end

    pos = pos + #tag

    if string_match(tag, '^[%l_]') then
      type_code = lua_string(tag)
    elseif string_find(tag, '-', 1, true) then
      fail(state, start, "the name of the '"..tag.."' component must be a Lua expression and can not have '-' in it")
    else
      type_code = tag
    end
  end

  local groups = {}
  local attributes = nil
  local self_closing = false

  if tag then
    while true do
      local skipped

      pos, skipped = skip_spaces(src, pos)
      pending = pending + skipped

      local char = string_sub(src, pos, pos)

      if char == '' then
        fail(state, start, "unfinished tag '<"..tag.."'")
      elseif char == '/' then
        if string_sub(src, pos + 1, pos + 1) != '>' then
          fail(state, pos, "'>' expected after '/'")
        end

        pos = pos + 2
        self_closing = true

        break
      elseif char == '>' then
        pos = pos + 1

        break
      elseif string_sub(src, pos, pos + 3) == '{...' then
        state.pos = pos + 4

        local code, tokens = transform(state, true)

        if tokens == 0 then
          fail(state, pos, 'spread expression expected after ...')
        end

        pos = state.pos + 1
        attributes = nil
        groups[#groups + 1] = flush()..'('..code..')'
      else
        local name = string_match(src, '^[%a_][%w_%-%.]*', pos)

        if !name then
          fail(state, pos, "attribute name expected in '<"..tag.."'")
        end

        pos = pos + #name
        pos, skipped = skip_spaces(src, pos)

        local value = 'true'

        if string_sub(src, pos, pos) == '=' then
          pending = pending + skipped
          pos, skipped = skip_spaces(src, pos + 1)
          pending = pending + skipped

          local opener = string_sub(src, pos, pos)

          if opener == '"' or opener == "'" then
            local close = string_find(src, opener, pos + 1, true)

            if !close then
              fail(state, pos, "unfinished value of the '"..name.."' attribute")
            end

            local text = string_sub(src, pos + 1, close - 1)

            value = lua_string(decode_entities(text))
            pos = close + 1
            pending = pending + count_newlines(text)
          elseif opener == '{' then
            state.pos = pos + 1

            local code, tokens = transform(state, true)

            if tokens == 0 then
              fail(state, pos, "the '"..name.."' attribute has an empty expression")
            end

            value = '('..code..')'
            pos = state.pos + 1
          else
            fail(state, pos, "the value of the '"..name.."' attribute must be quoted or in { }")
          end
        else
          pending = pending + skipped
        end

        if !attributes then
          attributes = {}
          groups[#groups + 1] = attributes
        end

        attributes[#attributes + 1] = flush()..table_key(name)..value
      end
    end
  end

  local children = {}

  if !self_closing then
    while true do
      if pos > len then
        fail(state, start, tag and ("'<"..tag..">' is never closed") or 'the fragment is never closed')
      end

      local char = string_sub(src, pos, pos)

      if string_sub(src, pos, pos + 3) == '<!--' then
        local _, close = string_find(src, '-->', pos + 4, true)

        if !close then
          fail(state, pos, 'unfinished comment')
        end

        pending = pending + count_newlines(string_sub(src, pos, close))
        pos = close + 1
      elseif string_sub(src, pos, pos + 1) == '</' then
        local skipped

        pos, skipped = skip_spaces(src, pos + 2)
        pending = pending + skipped

        if tag then
          local name = string_match(src, '^[%a_][%w_%.%-]*', pos)

          if name != tag then
            fail(state, pos, "'</"..tag..">' expected, got '</"..(name or string_sub(src, pos, pos)).."'")
          end

          pos = pos + #name
          pos, skipped = skip_spaces(src, pos)
          pending = pending + skipped
        end

        if string_sub(src, pos, pos) != '>' then
          fail(state, pos, "'>' expected in the closing tag of '"..(tag or 'the fragment').."'")
        end

        pos = pos + 1

        break
      elseif char == '<' then
        state.pos = pos
        children[#children + 1] = flush()..parse_element(state)
        pos = state.pos
      elseif char == '{' then
        state.pos = pos + 1

        local code, tokens = transform(state, true)

        pos = state.pos + 1

        if tokens == 0 then
          pending = pending + count_newlines(code)
        else
          children[#children + 1] = flush()..'('..code..')'
        end
      else
        local stop = string_find(src, '[<{]', pos) or len + 1
        local raw = string_sub(src, pos, stop - 1)
        local text = clean_text(raw)

        if text != '' then
          children[#children + 1] = flush()..lua_string(decode_entities(text))
        end

        pending = pending + count_newlines(raw)
        pos = stop
      end
    end
  end

  state.pos = pos

  local props_code = 'nil'

  if #groups == 1 and groups[1] == attributes then
    props_code = '{ '..table_concat(attributes, ', ')..' }'
  elseif #groups > 0 then
    local parts = {}

    for k, group in ipairs(groups) do
      if isstring(group) then
        parts[k] = group
      else
        parts[k] = '{ '..table_concat(group, ', ')..' }'
      end
    end

    props_code = 'Lumen.props('..table_concat(parts, ', ')..')'
  end

  local code = 'Lumen.element('..type_code..', '..props_code

  if #children > 0 then
    code = code..', { '..table_concat(children, ', ')..' }'
  end

  return code..')'..flush()
end

--- Compiles a template to Lua code. The code is the template with every piece of markup
-- replaced by a call to `Lumen.element`; it has the same number of lines as the template.
-- Raises an error that names the template and the line when the markup is malformed.
-- ```
-- Lumen.Compiler.compile('return <text color="red">Hi, {name}</text>', 'greeting')
-- -- return Lumen.element("text", { color = "red" }, { "Hi, ", (name) })
-- ```
-- @param source [String template source]
-- @param name='lumen' [String name of the template, used in error messages]
-- @return [String Lua code]
function Lumen.Compiler.compile(source, name)
  local state = {
    src = source,
    len = #source,
    name = name or 'lumen',
    pos = 1
  }

  local code = transform(state, false)

  return code
end
