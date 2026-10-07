class 'BasicReader'

--- Class constructor. Takes this reader's own section out of the proofreader config.
-- @param config=nil [Hash proofreader config, keyed by reader class name]
function BasicReader:init(config)
  self.config = config and config[self.class_name] or {}
  self.point = true
  self._message = nil
end

--- Called by the class system when a class extends BasicReader. Adds the new class to
-- the proofreader's list of readers.
-- @param new_class [BasicReader the class that extends this one]
function BasicReader:class_extended(new_class)
  PR:add_reader(new_class)
end

--- Checks the code for offenses. To be overridden: the base reader accepts everything.
-- An override returns a falsy status for an offense, optionally followed by the character
-- position and the line number of the offense.
-- @param tokens [Array<Hash> tokens from LuaLexer:tokenize]
-- @param lines [Array<String> the code split into lines]
-- @param source [String the code]
-- @return [Boolean always true in the base reader]
function BasicReader:proofread(tokens, lines, source)
  return true
end

--- Checks whether the offending code should be pointed at in the message.
-- @return [Boolean]
function BasicReader:should_point()
  return self.point
end

--- Returns the severity of this reader's offenses.
-- @return [String 'generic', 'ok', 'warn', 'critical' or 'fatal'; 'warn' by default]
function BasicReader:severity()
  return 'warn'
end

--- Returns the message that describes the last offense.
-- @return [String the message, or nil if none has been set]
function BasicReader:message()
  return self._message
end
