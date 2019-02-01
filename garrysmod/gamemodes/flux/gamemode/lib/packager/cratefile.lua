-- Still an experimental feature...
if !Settings.experimental then return end

-- Flux packager.
Packager = Packager or {}

include 'lex.lua'
include 'parser.lua'
include 'code_generator.lua'
