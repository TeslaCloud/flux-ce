class 'PluginInstance'

function PluginInstance:init(id, data)
  self.name         = data.name         or 'Unknown Plugin'
  self.author       = data.author       or 'Unknown Author'
  self.folder       = data.folder       or name:to_id()
  self.path         = data.path         or self.folder
  self.description  = data.description  or 'This plugin has no description.'
  self.id           = id or data.id     or name:to_id() or 'unknown'

  table.safe_merge(self, data)
end

function PluginInstance:get_name()
  return self.name
end

function PluginInstance:get_folder()
  return self.folder
end

function PluginInstance:get_path()
  return self.path
end

function PluginInstance:get_author()
  return self.author
end

function PluginInstance:get_description()
  return self.description
end

function PluginInstance:set_name(name)
  self.name = name or self.name or 'Unknown Plugin'
end

function PluginInstance:set_author(author)
  self.author = author or self.author or 'Unknown'
end

function PluginInstance:set_description(desc)
  self.description = desc or self.description or 'No description provided!'
end

function PluginInstance:set_data(data)
  table.safe_merge(self, data)
end

function PluginInstance:set_global(alias)
  if isstring(alias) then
    if alias[1]:is_lower() then
      error('bad plugin alias ('..alias..')\nplugin globals must follow the ConstantStyle!\n')
    end

    if !istable(_G[alias]) then
      _G[alias] = self
      self.alias = alias
    end
  end
end

function PluginInstance:is_schema()
  return self._is_schema
end

function PluginInstance:__tostring()
  return 'Plugin ['..self.name..']'
end

function PluginInstance:register()
  Plugin.register(self)
end
