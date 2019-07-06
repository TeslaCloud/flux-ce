class 'Webhook'

Webhook.base_url  = 'https://discordapp.com/api/webhooks/{id}/{key}'
Webhook.url       = nil
Webhook.id        = nil
Webhook.key       = nil
Webhook.hooks     = {}

function Webhook:init(id, key, types)
  self.id     = id or ''
  self.key    = key or ''
  self.url    = self.base_url:gsub('{key}', self.key):gsub('{id}', self.id)
  self.types  = istable(types) and types or {}
end

function Webhook:push(message, data)
  if self.url and isstring(message) then
    data = data or {}

    http.Post(self.base_url, {
      content = message,
      username = data.username,
      avatar_url = data.avatar_url,
      tts = data.tts
    })
  end
end

function Webhook:add(id, hook)
  if istable(hook) then
    self.hooks[id] = hook
  elseif isfunction(hook) then
    self.hooks[id] = hook()
  else
    self.hooks[id] = Webhook.new('', '')
  end

  return self.hooks[id]
end

function Webhook:get(id)
  return self.hooks[id]
end

function Webhook:all()
  return self.hooks
end

function Webhook:get_type(type)
  local ret = {}

  for k, v in pairs(self.hooks) do
    if v:is_type(type) then
      table.insert(ret, v)
    end
  end

  return ret
end

function Webhook:present(id)
  return tobool(self.hooks[id])
end

function Webhook:is_type(type)
  for k, v in ipairs(self.types) do
    if v == type or v == 'all' then
      return true
    end
  end

  return false
end

Webhook.exists      = Webhook.present
Webhook.exist       = Webhook.present
Webhook.find        = Webhook.get
Webhook.find_by_id  = Webhook.get
