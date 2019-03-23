--- A simple code generator designed for some simple aliases.
-- Luna 0.0.1

require_relative 'lex'
require_relative 'parse'

class 'Luna'
class 'Luna::SimpleCompiler'

function Luna.SimpleCompiler:init(source)
  self.source = source
  self.tokens = Packager.Lexer:tokenize(source)
end

function Luna.SimpleCompiler:compile()
  local tokens = self.tokens -- for quicker access
  local level = 0 -- current indent level

end
