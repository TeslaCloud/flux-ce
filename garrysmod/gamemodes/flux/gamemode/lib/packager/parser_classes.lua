local indent_level = 0

class 'ASTBase'

function ASTBase:inspect()
  local str = '('..self.class_name:gsub('AST', '')

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
  [TK_number]     = 'number',
  [TK_false]      = 'bool',
  [TK_true]       = 'bool'
}

function ASTLiteral:inspect()
  if self.what.tk == TK_string then
    return '"'..tostring(self.what and self.what.val)..'"'
  elseif self.what.tk == TK_nil then
    return tostring(self.what and self.what.val)
  else
    return tostring(lit_to_prefix[self.what.tk])..'('..tostring(self.what and self.what.val)..')'
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

class 'ASTReturn' extends 'ASTBase'
ASTReturn.what = nil

function ASTReturn:inspect()
  return '(return '..self.what:inspect()..')'
end
