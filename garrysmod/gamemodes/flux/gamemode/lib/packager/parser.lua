include 'lex.lua'

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

  if #self.chunks > 0 then
    for k, v in ipairs(self.chunks) do
      str = str..'\n  '..v:inspect()
    end
  end

  return str..')'
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
  else
    error('unexpected "'..self.current.val..'" on line '..self.current.line)
  end

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

  while self.current and (self.current.tk == TK_name or self.current.tk == string.byte('.') or self.current.tk == string.byte(':')) do
    if self.current.tk == TK_name then
      table.insert(field.fields, self.current)
    elseif self.current.tk == string.byte('.') then
      self:expect(TK_name, 1)
      self:next()
      table.insert(field.fields, self.current)
    elseif self.current.tk == string.byte(':') then
      self:expect(TK_name, 1)
      self:next()
      table.insert(field.fields, self.current)
      field.call = true
      self:next()
      break
    else
      break
    end
  
    self:next()
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
  func library.test:test(a, b)
  end

  func foo
  end
]])

print(parsed:inspect())
