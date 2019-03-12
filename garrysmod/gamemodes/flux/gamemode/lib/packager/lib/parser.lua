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
  [TK_assign]     = true,
  [TK_add_assign] = true,
  [TK_sub_assign] = true,
  [TK_mul_assign] = true,
  [TK_div_assign] = true,
  [TK_or_assign]  = true,
  [TK_and_assign] = true,
  [TK_con_assign] = true
}

BINARY_OPS = {
  [TK_add]        = true,
  [TK_sub]        = true,
  [TK_div]        = true,
  [TK_mul]        = true,
  [TK_pow]        = true,
  [TK_gt]         = true,
  [TK_lt]         = true,
  [TK_eq]         = true,
  [TK_ge]         = true,
  [TK_le]         = true,
  [TK_ne]         = true,
  [TK_concat]     = true,
  [TK_and]        = true,
  [TK_or]         = true
}

BINOP_PRIORITY = {
  [TK_add]  = 6,  [TK_mul]    = 7,
  [TK_sub]  = 6,  [TK_div]    = 7,
  [TK_mod]  = 7,
  [TK_pow]  = 10, [TK_concat] = 5,
  [TK_eq]   = 3,  [TK_ne]     = 3,
  [TK_lt]   = 3,  [TK_gt]     = 3,
  [TK_le]   = 3,  [TK_ge]     = 3,
  [TK_and]  = 2,  [TK_or]     = 1
}

include 'parser_classes.lua'

local tree_openers = {
  [TK_if] = true, [TK_while] = true, [TK_unless] = true,
  [TK_function] = true, [TK_until] = true, [TK_func] = true,
  [TK_do] = true, [TK_class] = true, [TK_arrow] = true
}

class 'Packager::Parser'
Packager.Parser.tokens = nil
Packager.Parser.current = nil
Packager.Parser.current_pos = 1

function Packager.Parser:throw_error(msg, where)
  if self.source and self.source != '' then
    print(self:point_at(where or self.current))
  end

  error(msg)
end

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
  local target_token = self.tokens[self.current_pos + (how_far or 0)] or {}

  if target_token.tk != token then
    self:throw_error('syntax error, '..Packager.Lexer:visualize(token)..' expected, got '..tostring(target_token.val))
  end
end

do
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

  function Packager.Parser:point_at(token)
    if !token then token = self.current end

    local tk_begin = token.pos - string.len(token.val)
    local left, right = shoot_left(self.source, tk_begin), shoot_right(self.source, token.pos)
    local str = left..token.val..right
    local pointer = string.rep('-', left:len())..'^'..string.rep('-', right:len() + token.val:len() - 1)

    return str..'\n'..pointer
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
  if self.current.tk == TK_lparen then
    self:next() -- eat '('

    while self.current and (self.current.tk == TK_name or self.current.tk == TK_comma or self.current.tk == TK_rparen) do
      if self.current.tk == TK_name then
        table.insert(func_proto.args, self.current)
        func_proto.argc = func_proto.argc + 1
        self:next()
      elseif self.current.tk == TK_comma then
        self:next() continue
      elseif self.current.tk == TK_rparen then
        self:next() -- eat ')'
        break
      end
    end
  end

  func_proto.body = self:parse_chunk()

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

-- Just a variable on it's own
function Packager.Parser:parse_call_assign()
  if self.current.tk == TK_name then
    local name = self:expr_field()

    -- implicit return of a variable
    if self.current.tk == TK_end then
      local ret_ast = ASTReturn.new()
      ret_ast.what = name
      return ret_ast
    end

    -- call with arguments
    if LITERAL_TOKENS[self.current.tk] or self.current.tk == TK_lparen then
      local call_ast = self:parse_call(name)

      -- implicit return
      if self.current.tk == TK_end then
        local ret_ast = ASTReturn.new()
        ret_ast.what = call_ast
        return ret_ast
      end

      return call_ast
    elseif ASSIGNMENT_TOKENS[self.current.tk] then -- assignment
      return self:parse_assignment(name)
    else
      self:throw_error('unexpected "'..self.current.val..'" on line '..self.current.line)
    end
  elseif LITERAL_TOKENS[self.current.tk] then -- implicit return
    if self:peek().tk == TK_end then
      local ret_ast = ASTReturn.new()
      ret_ast.what = ASTLiteral.new(self.current)

      self:next(2) -- eat literal and 'end'

      return ret_ast
    else
      self:throw_error('unexpected "'..self.current.val..'" on line '..self.current.line)
    end
  else
    self:throw_error('unexpected "'..self.current.val..'" on line '..self.current.line)
  end

  return
end

function Packager.Parser:parse_call(name)
  local call = ASTCall.new()
  call.name = name
  call.args = {}

  local expecting_name = true

  if self.current.tk == TK_lparen then
    self:next() -- eat '('
  end

  while LITERAL_TOKENS[self.current.tk] or self.current.tk == TK_comma do
    local tk = self.current.tk

    if tk == TK_comma then
      tk = self:next().tk
      expecting_name = true
    end

    if tk != TK_name then
      table.insert(call.args, ASTLiteral.new(self.current))
    elseif expecting_name then
      local name = self:expr_field()

      if self.current.tk == TK_lparen then
        table.insert(call.args, self:parse_call(name))
      else
        table.insert(call.args, name)
      end

      expecting_name = false

      continue
    elseif self.current.tk == TK_name then
      break
    end

    self:next()

    if self.current.tk != TK_comma then break end
  end

  if self.current.tk == TK_rparen then self:next() end

  return call
end

function Packager.Parser:parse_assignment(name)
  return
end

function Packager.Parser:parse_while()
  return
end

function Packager.Parser:parse_node()
  local node = ASTNode.new()
  local left

  if self.current.tk == TK_name then
    left = self:expr_field()
  elseif LITERAL_TOKENS[self.current.tk] then
    left = ASTLiteral.new(self.current)
    self:next() -- eat literal
  else
    return
  end

  if BINARY_OPS[self.current.tk] then
    node.op = self.current
    node.left = left

    self:next() -- eat operator

    node.right = self:parse_node()
  elseif self.current.tk == TK_end then
    node.left = left
  end

  return node
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
  local ret_ast = ASTReturn.new()

  self:next() -- eat 'return'

  if self.current and self.current.tk != TK_end then
    ret_ast.what = self:parse_node()
  end

  return ret_ast
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

  while self.current and (self.current.tk == TK_name or self.current.tk == TK_dot or self.current.tk == TK_colon) do
    if expecting_name and self.current.tk == TK_name then
      table.insert(field.fields, self.current)
      self:next() -- eat name
      expecting_name = false
    elseif self.current.tk == TK_dot then
      self:expect(TK_name, 1)
      self:next() -- eat '.'
      table.insert(field.fields, self.current)
      self:next() -- eat name
    elseif self.current.tk == TK_colon then
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
    self.source = tokens
    tokens = Packager.Lexer:tokenize(tokens)
  else
    self.source = ''
  end

  if !istable(tokens) then return false end

  self.tokens = tokens
  self.current = tokens[1]

  return self:parse_chunk()
end

if !Settings.experimental then return end

local parsed = Packager.Parser:parse([[
  func hello.world(a, b)
    foo()
    bar(a, b)
    baz a, b
    faz fez(1, false, true, nil, asdf)
  end

  func aaa
    print "Hello I'm a shitty parser!"
    print 123, a:gsub('%s+', ''), test, false
    return false
  end

  func a
    self.id
  end

  func b
    123 + 321
  end
]])

print(parsed:inspect())
