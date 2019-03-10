include 'lex.lua'

class 'Packager::Minifier'

function Packager.Minifier:minify(source)
  local tokens = Packager.Lexer:tokenize(source)
  local result = ''

  for k, v in ipairs(tokens) do
    if v.tk != TK_comment then
      local val = v.val

      if v.tk == TK_false then
        val = '!1'
      elseif v.tk == TK_true then
        val = '!!1'
      elseif v.tk == TK_and then
        val = '&&'
      elseif v.tk == TK_or then
        val = '||'
      elseif v.tk == TK_not then
        val = '!'
      end

      if v.tk != TK_string and (val[1]:match('[%w_]') and result[#result]:match('[%w_]')) then
        result = result..' '
      end

      if v.tk == TK_string then
        result = result..'"'..val
          :gsub('\\', '\\\\')
          :gsub('\a', '\\a')
          :gsub('\b', '\\b')
          :gsub('\f', '\\f')
          :gsub('\n', '\\n')
          :gsub('\r', '\\r')
          :gsub('\t', '\\t')
          :gsub('\v', '\\n')
          :gsub('"', '\\"')
          ..'"'
      else
        result = result..val
      end
    end
  end

  return result
end

function Packager.Minifier:minify_folder(folder)
  local code = ''
  local files, dirs = file.Find(folder..'*', 'GAME')

  for k, v in ipairs(files) do
    if v:ends('.lua') then
      code = code..'function '..(folder..v):gsub('[/%s%.]', '_')..'(...)\n'..tostring(fileio.Read(folder..v))..'\nend'
    end
  end

  for k, v in ipairs(dirs) do
    if !v:starts('.') then
      code = code..'\n'..self:minify_folder(folder..v..'/')
    end
  end

  return Packager.Minifier:minify(code)
end
