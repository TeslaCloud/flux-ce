--- Server side of the `Entity` extensions. `Entity:notify` lets code that notifies whoever runs
-- a command, which is an invalid entity for the server console, call `actor:notify` without
-- checking for the console first; `Player` has its own `notify`.

local ent_meta = FindMetaTable('Entity')

--- Sends a notification to the entity, which only reaches anyone when the entity is the
-- server console: the message is then written to the server log, translated. Serverside
-- only.
-- ```
-- -- in a command that can be run from the server console
-- actor:notify('error.invalid_amount')
-- ```
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @param color=nil [Color]
-- @see [Flux.Player#notify]
function ent_meta:notify(message, arguments, color)
  if IsValid(self) then return end

  Flux.Player:notify(self, message, arguments, color)
end
