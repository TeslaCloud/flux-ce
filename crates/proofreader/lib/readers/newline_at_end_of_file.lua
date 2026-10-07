class 'NewlineAtEndOfFileReader' extends 'BasicReader'

--- Checks that the code ends with a newline character.
-- @param tokens [Array<Hash> unused]
-- @param lines [Array<String> unused]
-- @param source [String the code]
-- @return [Boolean true if the code ends with a newline]
function NewlineAtEndOfFileReader:proofread(tokens, lines, source)
  return self.config['Enabled'] != false and source:ends('\n')
end

--- Returns the message that describes a missing newline at the end of the file.
-- @return [String]
function NewlineAtEndOfFileReader:message()
  return 'No newline (\\n) at the end of file.'
end
