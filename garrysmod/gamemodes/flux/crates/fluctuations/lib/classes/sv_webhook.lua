class 'Webhook'

Webhook.base_url  = 'https://discordapp.com/api/webhooks/{id}/{key}'
Webhook.url       = nil
Webhook.id        = nil
Webhook.key       = nil
Webhook.hooks     = {}

function Webhook:init(id, key)
  self.id = id or ''
  self.key = key or ''
  self.url = self.base_url:gsub('{key}', self.key):gsub('{id}', self.id)
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

function Webhook:present(id)
  return tobool(self.hooks[id])
end

Webhook.exists      = Webhook.present
Webhook.exist       = Webhook.present
Webhook.find        = Webhook.get
Webhook.find_by_id  = Webhook.get
