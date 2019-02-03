include 'lex.lua'

LITERAL_TOKENS    = {
  [TK_name]       = true,
  [TK_number]     = true,
  [TK_string]     = true,
  [TK_nil]        = true,
  [TK_false]      = true,
  [TK_true]       = true
}

ASSIGNMENT_TOKENS = {
  [string.byte('=')]           = true,
  [TK_add_assign] = true,
  [TK_sub_assign] = true,
  [TK_mul_assign] = true,
  [TK_div_assign] = true,
  [TK_or_assign]  = true,
  [TK_and_assign] = true,
  [TK_con_assign] = true
}

local indent_level = 0

class 'ASTBase'

function ASTBase:inspect()
  local str = '('..self.class_name

  if self.name then
    str = str..'('..self.name:inspect()..') '
  else
    str = str..' '
  end

  if self.left then
    str = str..'['..self.left:inspect()

    if self.right then
      str = str..self.right:inspect()
    end

    str = str..'] '
  elseif self.args then
    str = str..'['

    for k, v in ipairs(self.args) do
      str = str..v.val

      if k != self.argc then
        str = str..', '
      end
    end

    str = str..'] '
  end

  if self.body then
    str = str..self.body:inspect()
  end

  return str..')'
end

class 'ASTBody' extends 'ASTBase'
ASTBody.body = nil

class 'ASTChunk' extends 'ASTBase'
ASTChunk.chunks = nil

function ASTChunk:init()
  self.chunks = {}
end

function ASTChunk:inspect()
  local str = '(begin '

  indent_level = indent_level + 1

  if #self.chunks > 0 then
    for k, v in ipairs(self.chunks) do
      str = str..'\n'..string.rep('  ', indent_level)..v:inspect()
    end
  end

  indent_level = indent_level - 1

  return str..'\n'..string.rep('  ', indent_level)..')'
end

class 'ASTNode' extends 'ASTBase'
ASTNode.op = nil
ASTNode.left = nil
ASTNode.right = nil

class 'ASTField' extends 'ASTBase'
ASTField.fields = nil
ASTField.call = false -- false for . true for :

function ASTField:init()
  self.fields = {}
end

function ASTField:inspect()
  local str = ''
  local n_fields = #self.fields

  for k, v in ipairs(self.fields) do
    str = str..v.val

    if k != n_fields then
      if k == n_fields - 1 and self.call then
        str = str..':'
      else
        str = str..'.'
      end
    end
  end

  return str
end

class 'ASTLiteral' extends 'ASTBase'
ASTLiteral.what = nil

function ASTLiteral:init(what)
  self.what = what
  return self
end

local lit_to_prefix = {
  [TK_name]       = 'var',
  [TK_number]     = 'number',
  [TK_string]     = 'string',
  [TK_false]      = 'bool',
  [TK_true]       = 'bool'
}

function ASTLiteral:inspect()
  if self.what.tk != TK_nil then
    return tostring(lit_to_prefix[self.what.tk])..'('..tostring(self.what and self.what.val)..')'
  else
    return tostring(self.what and self.what.val)
  end
end

class 'ASTFuncProto' extends 'ASTBase'
ASTFuncProto.name = nil
ASTFuncProto.args = nil
ASTFuncProto.argc = 0
ASTFuncProto.body = nil

class 'ASTConditionTree' extends 'ASTBase'
ASTConditionTree.body = nil

class 'ASTCondition' extends 'ASTBase'
ASTCondition.type = nil
ASTCondition.cond = nil
ASTCondition.body = nil

class 'ASTCall' extends 'ASTBase'
ASTCall.name = nil
ASTCall.args = nil

function ASTCall:inspect()
  local str = '(call ('..tostring(self.name:inspect())..' '

  for k, v in ipairs(self.args) do
    str = str..v:inspect()

    if k < #self.args then
      str = str..' '
    end
  end
  
  return str..'))'
end

local tree_openers = {
  [TK_if] = true, [TK_while] = true, [TK_unless] = true,
  [TK_function] = true, [TK_until] = true, [TK_func] = true,
  [TK_do] = true, [TK_class] = true, [TK_arrow] = true
}

class 'Packager::Parser'
Packager.Parser.tokens = nil
Packager.Parser.current = nil
Packager.Parser.current_pos = 1

function Packager.Parser:next(how_far)
  how_far = how_far or 1
  self.current = self.tokens[self.current_pos + how_far]
  self.current_pos = self.current_pos + how_far
  return self.current
end

function Packager.Parser:peek(how_far)
  return self.tokens[self.current_pos + (how_far or 1)]
end

function Packager.Parser:expect(token, how_far)
  local this_token = self.tokens[self.current_pos + (how_far or 0)].tk

  if this_token != token then
    error('syntax error, '..token..' expected, got '..this_token)
  end
end

function Packager.Parser:parse_if()
  return
end

function Packager.Parser:parse_do()
  return
end

function Packager.Parser:parse_for()
  return
end

function Packager.Parser:parse_function()
  self:next() -- eat 'function'

  local func_proto = ASTFuncProto.new()

  func_proto.name = self:expr_field()
  func_proto.args = {}
  func_proto.argc = 0

  -- Function has arguments!
  if self.current.tk == string.byte('(') then
    self:next() -- eat '('

    while self.current and (self.current.tk == TK_name or self.current.tk == string.byte(',') or self.current.tk == string.byte(')')) do
      if self.current.tk == TK_name then
        table.insert(func_proto.args, self.current)
        func_proto.argc = func_proto.argc + 1
        self:next()
      elseif self.current.tk == string.byte(',') then
        self:next() continue
      elseif self.current.tk == string.byte(')') then
        self:next() -- eat ')'
        break
      end
    end
  end

  func_proto.body = self:parse_body()

  return func_proto
end

function Packager.Parser:parse_chunk()
  local ast = ASTChunk.new()

  while self.current do
    if self.current.tk == TK_end then
      self:next()
      break
    end

    table.insert(ast.chunks, self:parse_expr())
  end

  return ast
end

function Packager.Parser:parse_body()
  local parsed = self:parse_chunk()

  return parsed
end

-- Just a variable on it's own
function Packager.Parser:parse_call_assign()
  if self.current.tk == TK_name then
    local name = self:expr_field()

    -- call with arguments
    if LITERAL_TOKENS[self.current.tk] or self.current.tk == string.byte('(') then
      return self:parse_call(name)
    elseif ASSIGNMENT_TOKENS[self.current.tk] then -- assignment
      return self:parse_assignment(name)
    else
      error('unexpected "'..self.current.val..'" on line '..self.current.line)
    end
  else
    error('unexpected "'..self.current.val..'" on line '..self.current.line)
  end

  return
end

function Packager.Parser:parse_call(name)
  local call = ASTCall.new()
  call.name = name
  call.args = {}

  if self.current.tk == string.byte('(') then
    self:next() -- eat '('
  end

  while LITERAL_TOKENS[self.current.tk] or self.current.tk == string.byte(')')
     or self.current.tk == string.byte(',') do
    local tk = self.current.tk

    if tk == string.byte(',') then
      tk = self:next().tk
    end

    if tk != TK_name then
      table.insert(call.args, ASTLiteral.new(self.current))
    else
      if self:peek(1) == string.byte('(') then
        table.insert(call.args, self:parse_call())
      else
        table.insert(call.args, ASTLiteral.new(self.current))
      end
    end

    self:next()

    if self.current.tk != string.byte(',') then break end
  end

  if self.current.tk == string.byte(')') then self:next() end

  return call
end

function Packager.Parser:parse_assignment(name)
  return
end

function Packager.Parser:parse_while()
  return
end

function Packager.Parser:parse_until()
  return
end

function Packager.Parser:parse_arrow()
  return
end

function Packager.Parser:parse_local()
  return
end

function Packager.Parser:parse_break()
  return
end

function Packager.Parser:parse_class()
  return
end

function Packager.Parser:parse_import()
  return
end

function Packager.Parser:parse_export()
  return
end

function Packager.Parser:parse_unless()
  return
end

function Packager.Parser:parse_return()
  return
end

function Packager.Parser:parse_continue()
  return
end

function Packager.Parser:expr_string()
  return
end

function Packager.Parser:expr_field()
  local field = ASTField.new()
  local expecting_name = true

  while self.current and (self.current.tk == TK_name or self.current.tk == string.byte('.') or self.current.tk == string.byte(':')) do
    if expecting_name and self.current.tk == TK_name then
      table.insert(field.fields, self.current)
      self:next() -- eat name
      expecting_name = false
    elseif self.current.tk == string.byte('.') then
      self:expect(TK_name, 1)
      self:next() -- eat '.'
      table.insert(field.fields, self.current)
      self:next() -- eat name
    elseif self.current.tk == string.byte(':') then
      self:expect(TK_name, 1)
      self:next() -- eat ':'
      table.insert(field.fields, self.current)
      field.call = true
      self:next() -- eat name
      break
    else
      break
    end
  end

  return field
end

function Packager.Parser:expr_bracket()
  return
end

function Packager.Parser:expr_table()
  return
end

function Packager.Parser:parse_expr()
  if !self.current then return end

  -- Skip all comments.
  while self.current and self.current.tk == TK_comment do
    self:next()

    if !self.current then return end
  end

  local switch = {
    [TK_if]       = self.parse_if,
    [TK_do]       = self.parse_do,
    [TK_for]      = self.parse_for,
    [TK_func]     = self.parse_function,
    [TK_while]    = self.parse_while,
    [TK_until]    = self.parse_until,
    [TK_arrow]    = self.parse_arrow,
    [TK_local]    = self.parse_local,
    [TK_break]    = self.parse_break,
    [TK_class]    = self.parse_class,
    [TK_import]   = self.parse_import,
    [TK_export]   = self.parse_export,
    [TK_unless]   = self.parse_unless,
    [TK_return]   = self.parse_return,
    [TK_function] = self.parse_function,
    [TK_continue] = self.parse_continue
  }

  local parser = switch[self.current.tk] or self.parse_call_assign

  if parser then
    return parser(self)
  end
end

function Packager.Parser:parse(tokens)
  if isstring(tokens) then
    tokens = Packager.Lexer:tokenize(tokens)
  end

  if !istable(tokens) then return false end

  self.tokens = tokens
  self.current = tokens[1]

  return self:parse_chunk()
end

local parsed = Packager.Parser:parse([[
  func hello.world(a, b)
  end

  func foo
    print "Hello I'm a shitty parser!"
    print true, false, nil
  end
]])

print(parsed:inspect())
