Package:describe(function(s)
  s.name        = 'LLM'
  s.version     = '1.0.0'
  s.date        = '2026-10-15'
  s.summary     = 'A small client for Anthropic and OpenAI-compatible LLM APIs.'
  s.description = 'Sends chat requests with tool definitions to the Anthropic Messages API or any '..
                  'OpenAI-compatible chat completions endpoint and returns the replies in one '..
                  'provider-neutral shape.'
  s.authors     = { 'TeslaCloud Studios', 'Luna Fox' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'lib/install.lua'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'
  s.serverside  = true
end)
