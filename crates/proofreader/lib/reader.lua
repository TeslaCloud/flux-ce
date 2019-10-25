PR.readers = {}
PR.messages = {}

enumerate 'PR_GENERIC PR_OK PR_WARN PR_CRITICAL PR_FATAL'

local status_colors = {
  [PR_GENERIC]  = Color 'white',
  [PR_OK]       = Color 'white',
  [PR_WARN]     = Color 'yellow',
  [PR_CRITICAL] = Color 'orange',
  [PR_FATAL]    = Color 'red'
}

local status_symbols = {
  [PR_GENERIC]  = '.',
  [PR_OK]       = '.',
  [PR_WARN]     = 'W',
  [PR_CRITICAL] = 'C',
  [PR_FATAL]    = 'F'
}

local severity_to_status = {
  generic  = PR_GENERIC,
  ok       = PR_OK,
  warn     = PR_WARN,
  critical = PR_CRITICAL,
  fatal    = PR_FATAL
}

function PR:add_reader(reader_class)
  table.insert(self.readers, reader_class)
end

function PR:add_message(severity, filename, line, msg)
  local message = ''

  if severity then
    message = message..'['..severity:upper()..'] '
  end

  message = message..filename

  if line then
    message = message..':'..line..':\n  '
  else
    message = message..':\n  '
  end

  message = message..msg

  table.insert(self.messages, { message = message, severity = severity_to_status[severity] })
end

function PR:proofread_file(filename)
  local contents = File.read(filename)
  local tokens = LuaLexer:tokenize(contents, true)
  local lines = contents:split('\n')
  local overall_status = PR_GENERIC

  for _, reader in ipairs(self.readers) do
    local reader_instance = reader.new(self.config)
    local status, pos, line

    repeat
      status, pos, line = reader_instance:proofread(tokens, lines, contents)

      if !status then
        local severity = reader_instance:severity()
    
        self:add_message(severity, filename, line, reader_instance:message())
        overall_status = severity_to_status[severity]

        if isnumber(pos) then
          contents = contents:sub(pos + lines[line]:len(), #contents)
          pos = 0
        end

        if isnumber(line) then
          lines = table.slice(lines, line + 1, #lines)
          line = 0
        end
      end
    until !pos or status
  end

  return overall_status
end

function PR:proofread_folder(folder)
  return self:proofread(File.get_list(folder))
end

function PR:proofread(files)
  files = files or {}
  self.messages = {}

  if !istable(files) then return end

  for _, filename in ipairs(files) do
    local status = self:proofread_file(filename)

    MsgC(status_colors[status], status_symbols[status])
  end

  print ''

  for id, msg in ipairs(self.messages) do
    MsgC(status_colors[msg.severity], msg.message..'\n\n')
  end

  print ''

  print('Proofreading done, '..#self.messages..' offenses in '..#files..' files.')
end
