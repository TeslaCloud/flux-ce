Package:describe(function(s)
  s.name        = "Srlion's Fast Serializer"
  s.version     = '7.0.9'
  s.date        = '2026-05-24'
  s.summary     = "Srlion's Serialization Library"
  s.description = "A fast binary serializer for Garry's Mod made by Srlion."
  s.author      = 'Srlion'
  s.file        = 'lib/install.lua'
  s.website     = 'https://github.com/Srlion/sfs'
  s.license     = 'MIT'

  add_client_env('SFS_PATH', PACKAGE.__path__)
end)
