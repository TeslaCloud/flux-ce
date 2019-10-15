local Lex = require_client 'lexer'
local _tks, _tree, _cur, _current_node, _previous_node
local parse_body, parse_class, parse_variable, parse_expression

local function next()
  _cur = _cur + 1
  return _tks[_cur]
end

local function this()
  return _tks[_cur]
end

local function lookup(offset)
  offset = offset or 1
  return _tks[_cur + offset]
end

local function open_node()
  _previous_node = _current_node
  _current_node = {}
  return _previous_node
end

local function close_node()
  local node = _current_node
  _current_node = _previous_node
  return node
end

local function push(what, value)
  if !value then
    table.insert(_current_node, what)
  else
    _current_node[what] = value
  end
end

local function push_if(what, value)
  if value != nil then
    push(what, value)
  end
end

local function expect(tk)
  if next() != tk then
    error('css - unexpected token! ("'..tk..'" expected, got "'..lookup()..'")')
  end
end

local function read_value()
  local value = ''

  while lookup() != ';' do
    value = value..next()..' '

    if !this() then break end
  end

  return value:trim()
end

local function parse_expr()
  local name = next()

  expect ':'

  push(name, read_value())

  expect ';'
end

local function parse_variable()
  local name = next()

  expect ':'

  _tree.variables[name] = read_value()

  expect ';'
  next()
end

local function parse_class()
  while lookup() != '}' do
    parse_expr()
  end
  expect '}'
  next()
end

local function parse_element()
  while lookup() != '}' do
    parse_expr()
  end
  expect '}'
  next()
end

local function parse_selector()
  local op = next()

  if op == 'media' then
    expect '('
    open_node()
      parse_expr()
    push(close_node())
    expect ')'
    expect '{'
    next()
    open_node()
      parse_body()
    push(close_node())
  end
end

parse_body = function()
  local tk = this()

  if tk == '.' then
    local name = next()
    local selector
    if lookup() == ':' then
      expect ':'
      selector = next()
    end
    expect '{'
    open_node()
      push_if('selector', selector)
      parse_class()
    table.insert(_tree.classes, { name = name, node = close_node() })
  elseif tk == '#' then
    local name = next()
    local selector
    if lookup() == ':' then
      expect ':'
      selector = next()
    end
    expect '{'
    open_node()
      push_if('selector', selector)
      parse_class()
    table.insert(_tree.ids, { name = name, node = close_node() })
  elseif tk == '$' then
    parse_variable()
  elseif tk == '@' then
    open_node()
      parse_selector()
    push(close_node())
  else
    local name = tk
    local selector
    if lookup() == ':' then
      expect ':'
      selector = next()
    end

    expect '{'

    open_node()
      push_if('selector', selector)
      parse_element()
    table.insert(_tree.elements, { name = name, node = close_node() })
  end

  if lookup() then
    parse_body()
  end
end

local function parse(text)
  _tks = Lex.tokenize(text)
  _cur = 1
  _tree = {
    variables   = {},
    classes     = {},
    ids         = {},
    elements    = {},
    conditions  = {}
  }
  _current_node = nil
  _previous_node = nil

  open_node()
    parse_body()
  close_node()

  PrintTable(_tree)

  return _tree
end

local tks = parse([[
.test {
  padding: 8px 0 100% 8vh;
  display: flex;
  line-height: 16px;
}

.test:hover {
  color: blue;
}

#test {
  font-family: Arial;
}

$test: red;

html {
  color: red;
}
]])
