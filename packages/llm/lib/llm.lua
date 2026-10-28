--- LLM is a small client for chat APIs of large language models. It speaks to the Anthropic
-- Messages API and to any OpenAI-compatible chat completions endpoint (OpenAI, OpenRouter, vLLM,
-- llama.cpp, Ollama and the like) through one provider-neutral format, so that the same
-- conversation can be sent to either kind of API.
--
-- `LLM.new` creates a client for a provider, and `Client:chat` sends a request and calls back
-- with the reply. A conversation is a list of messages with the roles `user`, `assistant`,
-- `tool` and `system`. The reply carries its text, the tool calls the model wants to make and
-- `response.message`, the assistant message to append to the conversation before the next
-- request. Requests that fail with a rate limit or a server error are retried, and requests to
-- Anthropic opt into server-side refusal fallbacks unless `fallbacks = false` is passed.
--
-- Requests go out through the `HTTP` function, which does not work until the server has
-- finished starting up. The package is serverside only.
-- ```
-- local client = LLM.new {
--   provider = 'anthropic',
--   api_key = string.Trim(file.Read('llm/anthropic_key.txt', 'DATA') or ''),
--   effort = 'low'
-- }
--
-- local history = { LLM.user('A citizen walks up and asks for directions to the plaza.') }
-- local tools = {
--   {
--     name = 'point_at',
--     description = 'Points at a place in the city.',
--     parameters = {
--       type = 'object',
--       properties = { place = { type = 'string' } },
--       required = { 'place' }
--     }
--   }
-- }
--
-- client:chat({
--   system = 'You are a Civil Protection officer in City 17. Stay in character and reply in '..
--     'one or two short sentences.',
--   messages = history,
--   tools = tools
-- }, function(response, err)
--   if !response then
--     return ErrorNoHalt('LLM request failed: '..err.message..'\n')
--   end
--
--   table.insert(history, response.message)
--   officer:say(response.text)
--
--   for _, call in ipairs(response.tool_calls) do
--     officer:point_at(call.input.place)
--     table.insert(history, LLM.tool_result(call, 'done'))
--   end
-- end)
-- ```

local llm = {}

local EMPTY_OBJECT_JSON = '{"__llm_empty_object":true}'

local retry_statuses = { [408] = true, [409] = true, [429] = true }

local anthropic_stops = {
  end_turn = 'end',
  stop_sequence = 'end',
  tool_use = 'tool_use',
  max_tokens = 'max_tokens',
  model_context_window_exceeded = 'max_tokens',
  refusal = 'refusal'
}

local openai_stops = {
  stop = 'end',
  length = 'max_tokens',
  tool_calls = 'tool_use',
  function_call = 'tool_use',
  content_filter = 'refusal'
}

--- The providers that clients can be created for, by name. Each provider has a default
-- `base_url`, optionally a default `model`, and two functions: `build(client, request)` returns
-- the path of the endpoint, a Map of headers and the request body, and `parse(data)` turns the
-- decoded reply into a response (or returns nil and a reason).
llm.providers = {}

--- A table that `LLM.to_json` writes as an empty JSON object, as an empty table is written as
-- an empty array. Use it where a schema needs an empty object, such as `properties` of a tool
-- that takes no arguments.
llm.empty_object = { __llm_empty_object = true }

--- Encodes a table as JSON with `util.TableToJSON`, writing `LLM.empty_object` as `{}`.
-- @param tab [Table]
-- @return [String JSON text]
function llm.to_json(tab)
  return string.Replace(util.TableToJSON(tab), EMPTY_OBJECT_JSON, '{}')
end

--- Decodes JSON text with `util.JSONToTable`, without depth limits and without turning keys that
-- look like numbers into numbers.
-- @param str [String JSON text]
-- @return [Table the decoded table, or nil if the text is not valid JSON]
function llm.from_json(str)
  if !isstring(str) or str == '' then return end

  return util.JSONToTable(str, true, true)
end

--- Creates a user message.
-- @param content [String text of the message, or a List of provider-specific content blocks]
-- @return [Map the message]
function llm.user(content)
  return { role = 'user', content = content }
end

--- Creates a message with the result of a tool call.
-- @param call [Map/String tool call from response.tool_calls, or its ID]
-- @param content='' [String/Table result of the call, tables are sent as JSON]
-- @param is_error=false [Boolean whether the call has failed]
-- @return [Map the message]
function llm.tool_result(call, content, is_error)
  if istable(content) then
    content = llm.to_json(content)
  end

  return {
    role = 'tool',
    tool_call_id = istable(call) and call.id or call,
    content = content or '',
    is_error = is_error or nil
  }
end

--- A client of one provider. Created with `LLM.new`.
local Client = {}
Client.__index = Client
llm.Client = Client

--- Creates a client.
-- ```
-- LLM.new { provider = 'anthropic', api_key = key }
-- LLM.new { provider = 'openai', base_url = 'http://localhost:11434/v1', model = 'qwen3:8b' }
-- ```
-- @param options [Map with the fields:
--   provider='anthropic' [String 'anthropic', 'openai' or another key of LLM.providers]
--   api_key=nil [String API key, may be omitted for local servers]
--   model=nil [String model name; 'claude-opus-5-5' for Anthropic, required for other providers]
--   base_url=nil [String API root that the endpoint path is appended to]
--   max_tokens=16000 [Number maximum number of tokens in a reply, thinking included]
--   max_tokens_key='max_tokens' [String body field of max_tokens for OpenAI-compatible APIs,
--     OpenAI's reasoning models want 'max_completion_tokens']
--   effort=nil [String 'low', 'medium', 'high', ... sent as output_config.effort to Anthropic and
--     as reasoning_effort to OpenAI-compatible APIs]
--   fallbacks='default' [String/List/Boolean Anthropic refusal fallbacks, false to turn them off]
--   betas=nil [List<String> extra Anthropic beta headers]
--   headers=nil [Map extra HTTP headers]
--   extra=nil [Map extra fields merged into every request body]
--   timeout=120 [Number seconds to wait for a reply]
--   max_retries=2 [Number retries of rate-limited, failed and timed out requests]]
-- @return [Client]
function llm.new(options)
  options = options or {}

  local provider_name = options.provider or 'anthropic'
  local provider = llm.providers[provider_name]

  if !provider then
    error('LLM: unknown provider '..tostring(provider_name), 2)
  end

  local model = options.model or provider.model

  if !model then
    error('LLM: the '..provider_name..' provider needs a model', 2)
  end

  local fallbacks = options.fallbacks

  if fallbacks == nil and provider_name == 'anthropic' then
    fallbacks = 'default'
  end

  return setmetatable({
    provider = provider_name,
    api_key = options.api_key,
    model = model,
    base_url = (options.base_url or provider.base_url):gsub('/+$', ''),
    max_tokens = options.max_tokens or 16000,
    max_tokens_key = options.max_tokens_key or 'max_tokens',
    effort = options.effort,
    fallbacks = fallbacks or nil,
    betas = options.betas,
    headers = options.headers,
    extra = options.extra,
    timeout = options.timeout or 120,
    max_retries = options.max_retries or 2
  }, Client)
end

--- @ignore
local function header_value(headers, name)
  if !istable(headers) then return end

  for header, value in pairs(headers) do
    if isstring(header) and header:lower() == name then
      return value
    end
  end
end

--- @ignore
local function retry_delay(attempt, retry_after)
  local delay = tonumber(retry_after)

  if !delay then
    delay = math.min(0.5 * 2 ^ (attempt - 1), 8) * (0.75 + math.random() * 0.5)
  end

  return math.Clamp(delay, 0, 60)
end

--- @ignore
local function api_error(code, body, data)
  local info = istable(data) and data.error

  if isstring(info) then
    return { status = code, message = info, body = body }
  elseif istable(info) then
    return {
      status = code,
      type = info.type or info.code,
      message = info.message or 'HTTP '..code,
      body = body
    }
  end

  return { status = code, message = 'HTTP '..code, body = body }
end

--- @ignore
local function send(client, provider, url, headers, payload, attempt, callback)
  local function retry(retry_after)
    timer.Simple(retry_delay(attempt, retry_after), function()
      send(client, provider, url, headers, payload, attempt + 1, callback)
    end)
  end

  local started = HTTP({
    url = url,
    method = 'POST',
    type = 'application/json',
    body = payload,
    headers = headers,
    timeout = client.timeout,
    success = function(code, body, response_headers)
      local data = llm.from_json(body)

      if code >= 200 and code < 300 then
        if !istable(data) then
          return callback(nil, { status = code, message = 'the reply is not valid JSON', body = body })
        end

        local response, reason = provider.parse(data)

        if !response then
          return callback(nil, { status = code, message = reason, body = body })
        end

        return callback(response)
      end

      if (retry_statuses[code] or code >= 500) and attempt <= client.max_retries then
        return retry(header_value(response_headers, 'retry-after'))
      end

      callback(nil, api_error(code, body, data))
    end,
    failed = function(reason)
      if attempt <= client.max_retries then
        return retry()
      end

      callback(nil, { status = 0, message = tostring(reason) })
    end
  })

  if !started then
    callback(nil, { status = 0, message = 'the HTTP request could not be started' })
  end
end

--- Sends a chat request. The callback receives the response, or nil and an error.
--
-- The response is a Map with the fields:
-- `text` (String all text of the reply), `tool_calls` (List of Maps with `id`, `name` and
-- `input`, empty if there are none), `stop_reason` ('end', 'tool_use', 'max_tokens',
-- 'refusal' or the provider's own reason), `refusal` (details of a refusal, if the provider
-- gives any), `usage` (Map with `input_tokens` and `output_tokens`), `model`, `message` (the
-- assistant message to append to the conversation) and `raw` (the decoded reply).
--
-- The error is a Map with `status` (HTTP status, 0 if there was no reply), `message`,
-- `type` (the provider's error type, if any) and `body` (the raw reply, if any).
-- ```
-- client:chat('Say hello.', function(response, err)
--   print(response and response.text or err.message)
-- end)
-- ```
-- @param request [String/Map a single user message, or a Map with the fields:
--   messages [List<Map> the conversation]
--   system=nil [String system prompt]
--   tools=nil [List<Map> tools with `name`, `description` and `parameters` (a JSON schema)]
--   stop=nil [List<String> stop sequences]
--   model, max_tokens, effort=nil [overrides of the client's settings]
--   extra=nil [Map extra fields merged into the request body]]
-- @param callback [Function receives the response, or nil and the error]
function Client:chat(request, callback)
  if isstring(request) then
    request = { messages = { llm.user(request) } }
  end

  local provider = llm.providers[self.provider]
  local path, headers, body = provider.build(self, request)

  for field, value in pairs(self.extra or {}) do
    body[field] = value
  end

  for field, value in pairs(request.extra or {}) do
    body[field] = value
  end

  for header, value in pairs(self.headers or {}) do
    headers[header] = value
  end

  send(self, provider, self.base_url..path, headers, llm.to_json(body), 1, callback)
end

--- @ignore
local function tool_input(arguments)
  if !istable(arguments) or table.IsEmpty(arguments) then
    return llm.empty_object
  end

  return arguments
end

--- @ignore
local function push_user_block(result, block)
  local last = result[#result]

  if !last or last.role != 'user' then
    last = { role = 'user', content = {} }
    result[#result + 1] = last
  end

  table.insert(last.content, block)
end

--- @ignore
local function anthropic_messages(messages)
  local result = {}
  local system_texts = {}

  for _, message in ipairs(messages) do
    local role = message.role

    if role == 'assistant' then
      local native = message.native
      local content = native and native.provider == 'anthropic' and native.content

      if !content and istable(message.content) then
        content = message.content
      elseif !content then
        content = {}

        if isstring(message.content) and message.content != '' then
          content[1] = { type = 'text', text = message.content }
        end

        for _, call in ipairs(message.tool_calls or {}) do
          content[#content + 1] = {
            type = 'tool_use',
            id = call.id,
            name = call.name,
            input = tool_input(call.input)
          }
        end
      end

      result[#result + 1] = { role = 'assistant', content = content }
    elseif role == 'tool' then
      push_user_block(result, {
        type = 'tool_result',
        tool_use_id = message.tool_call_id,
        content = message.content,
        is_error = message.is_error or nil
      })
    elseif role == 'system' then
      if isstring(message.content) and message.content != '' then
        system_texts[#system_texts + 1] = message.content
      end
    elseif istable(message.content) then
      for _, block in ipairs(message.content) do
        push_user_block(result, block)
      end
    else
      push_user_block(result, { type = 'text', text = message.content })
    end
  end

  return result, system_texts
end

--- The Anthropic Messages API. Assistant messages that came from it are sent back with their
-- original content blocks, thinking blocks included. System messages of the conversation are
-- appended to the system prompt, since the API has no system role in its messages.
llm.providers.anthropic = {
  base_url = 'https://api.anthropic.com/v1',
  model = 'claude-opus-5-5'
}

--- Builds a request to the Anthropic Messages API.
-- @param client [Client]
-- @param request [Map the request given to Client:chat]
-- @return [String endpoint path]
-- @return [Map headers]
-- @return [Map body]
function llm.providers.anthropic.build(client, request)
  local headers = { ['anthropic-version'] = '2023-06-01' }
  local betas = {}
  local messages, system_texts = anthropic_messages(request.messages or {})
  local body = {
    model = request.model or client.model,
    max_tokens = request.max_tokens or client.max_tokens,
    system = request.system,
    messages = messages,
    stop_sequences = request.stop
  }

  if #system_texts > 0 and (request.system == nil or isstring(request.system)) then
    if isstring(request.system) and request.system != '' then
      table.insert(system_texts, 1, request.system)
    end

    body.system = table.concat(system_texts, '\n\n')
  end

  if client.api_key then
    headers['x-api-key'] = client.api_key
  end

  if istable(request.tools) and #request.tools > 0 then
    body.tools = {}

    for i, tool in ipairs(request.tools) do
      body.tools[i] = {
        name = tool.name,
        description = tool.description,
        input_schema = tool.parameters or { type = 'object' }
      }
    end
  end

  local effort = request.effort or client.effort

  if effort then
    body.output_config = { effort = effort }
  end

  if client.fallbacks then
    body.fallbacks = client.fallbacks
    betas[#betas + 1] = isstring(client.fallbacks) and 'server-side-fallback-2026-07-01'
      or 'server-side-fallback-2026-06-01'
  end

  for _, beta in ipairs(client.betas or {}) do
    betas[#betas + 1] = beta
  end

  if #betas > 0 then
    headers['anthropic-beta'] = table.concat(betas, ',')
  end

  return '/messages', headers, body
end

--- Turns a reply of the Anthropic Messages API into a response.
-- @param data [Map the decoded reply]
-- @return [Map the response]
function llm.providers.anthropic.parse(data)
  local content = istable(data.content) and data.content or {}
  local usage = istable(data.usage) and data.usage or {}
  local text = {}
  local tool_calls = {}

  for _, block in ipairs(content) do
    if block.type == 'text' then
      text[#text + 1] = block.text
    elseif block.type == 'tool_use' then
      tool_calls[#tool_calls + 1] = {
        id = block.id,
        name = block.name,
        input = istable(block.input) and block.input or {}
      }
    end

    if istable(block.input) and table.IsEmpty(block.input) then
      block.input = llm.empty_object
    end
  end

  local response = {
    text = table.concat(text),
    tool_calls = tool_calls,
    stop_reason = anthropic_stops[data.stop_reason] or data.stop_reason,
    refusal = data.stop_details,
    usage = { input_tokens = usage.input_tokens or 0, output_tokens = usage.output_tokens or 0 },
    model = data.model,
    raw = data
  }

  response.message = {
    role = 'assistant',
    content = response.text,
    tool_calls = #tool_calls > 0 and tool_calls or nil,
    native = { provider = 'anthropic', content = content }
  }

  return response
end

--- @ignore
local function openai_messages(system, messages)
  local result = {}

  if system then
    result[1] = { role = 'system', content = system }
  end

  for _, message in ipairs(messages) do
    local role = message.role

    if role == 'assistant' then
      local entry = { role = 'assistant' }
      local content = message.content

      if istable(content) or (isstring(content) and content != '') then
        entry.content = content
      end

      if message.tool_calls then
        entry.tool_calls = {}

        for i, call in ipairs(message.tool_calls) do
          entry.tool_calls[i] = {
            id = call.id,
            type = 'function',
            ['function'] = {
              name = call.name,
              arguments = call.arguments or llm.to_json(tool_input(call.input))
            }
          }
        end
      end

      if !entry.content and !entry.tool_calls then
        entry.content = ''
      end

      result[#result + 1] = entry
    elseif role == 'tool' then
      result[#result + 1] = { role = 'tool', tool_call_id = message.tool_call_id, content = message.content }
    else
      result[#result + 1] = { role = role or 'user', content = message.content }
    end
  end

  return result
end

--- OpenAI-compatible chat completions APIs.
llm.providers.openai = {
  base_url = 'https://api.openai.com/v1'
}

--- Builds a request to an OpenAI-compatible chat completions API.
-- @param client [Client]
-- @param request [Map the request given to Client:chat]
-- @return [String endpoint path]
-- @return [Map headers]
-- @return [Map body]
function llm.providers.openai.build(client, request)
  local headers = {}
  local body = {
    model = request.model or client.model,
    messages = openai_messages(request.system, request.messages or {}),
    stop = request.stop,
    reasoning_effort = request.effort or client.effort
  }

  body[client.max_tokens_key] = request.max_tokens or client.max_tokens

  if client.api_key then
    headers.Authorization = 'Bearer '..client.api_key
  end

  if istable(request.tools) and #request.tools > 0 then
    body.tools = {}

    for i, tool in ipairs(request.tools) do
      body.tools[i] = {
        type = 'function',
        ['function'] = {
          name = tool.name,
          description = tool.description,
          parameters = tool.parameters or { type = 'object', properties = llm.empty_object }
        }
      }
    end
  end

  return '/chat/completions', headers, body
end

--- Turns a reply of an OpenAI-compatible chat completions API into a response.
-- @param data [Map the decoded reply]
-- @return [Map the response, or nil if the reply has no choices]
-- @return [String the reason the reply could not be read]
function llm.providers.openai.parse(data)
  local choice = istable(data.choices) and data.choices[1]

  if !istable(choice) then
    return nil, 'the reply has no choices'
  end

  local message = istable(choice.message) and choice.message or {}
  local usage = istable(data.usage) and data.usage or {}
  local tool_calls = {}

  for i, call in ipairs(message.tool_calls or {}) do
    local fn = call['function'] or {}

    tool_calls[i] = {
      id = call.id,
      name = fn.name,
      input = llm.from_json(fn.arguments) or {},
      arguments = fn.arguments
    }
  end

  local stop_reason = openai_stops[choice.finish_reason] or choice.finish_reason

  if #tool_calls > 0 then
    stop_reason = 'tool_use'
  elseif isstring(message.refusal) then
    stop_reason = 'refusal'
  end

  local response = {
    text = isstring(message.content) and message.content or '',
    tool_calls = tool_calls,
    stop_reason = stop_reason,
    refusal = message.refusal,
    usage = { input_tokens = usage.prompt_tokens or 0, output_tokens = usage.completion_tokens or 0 },
    model = data.model,
    raw = data
  }

  response.message = {
    role = 'assistant',
    content = response.text,
    tool_calls = #tool_calls > 0 and tool_calls or nil
  }

  return response
end

return llm
