Crate:describe(function(s)
  s.name        = 'Proof Reader'
  s.version     = '0.0.1'
  s.date        = '2019-10-25'
  s.summary     = 'Flux linter.'
  s.description = 'Flux linting system that notifies you of stylistic mistakes in your code, and performs static analysis.'
  s.authors     = { 'TeslaCloud Studios', 'Meow the Cat' }
  s.email       = 'support@teslacloud.net'
  s.files       = { 'lib/proofreader.lua' }
  s.global      = 'PR'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'
  s.serverside  = true

  s.depends     'lex_tools'
end)
