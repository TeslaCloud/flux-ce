class 'BasicReader'

function BasicReader:init(config)
  self.config = config and config[self.class_name] or {}
  self.point = true
  self._message = nil
end

function BasicReader:class_extended(new_class)
  PR:add_reader(new_class)
end

function BasicReader:proofread(tokens, lines, source)
  return true
end

function BasicReader:should_point()
  return self.point
end

function BasicReader:severity()
  return 'warn'
end

function BasicReader:message()
  return self._message
end
