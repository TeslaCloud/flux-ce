class 'NewlineAtEndOfFileReader' extends 'BasicReader'

function NewlineAtEndOfFileReader:proofread(tokens, lines, source)
  return self.config['Enabled'] != false and source:ends('\n')
end

function NewlineAtEndOfFileReader:message()
  return 'No newline (\\n) at the end of file.'
end
