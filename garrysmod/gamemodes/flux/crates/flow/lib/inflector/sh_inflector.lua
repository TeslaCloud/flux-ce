class 'Flow::Inflector'

Flow.Inflector._plurals = {}
Flow.Inflector._singulars = {}
Flow.Inflector._irregulars = {}
Flow.Inflector._irregulars_rev = {}
Flow.Inflector._uncountables = {}
Flow.Inflector.current_language = 'en'

function Flow.Inflector:inflections(lang, func)
  self.current_language      = lang or 'en'
  self._plurals[lang]        = self._plurals[lang] or {}
  self._singulars[lang]      = self._singulars[lang] or {}
  self._irregulars[lang]     = self._irregulars[lang] or {}
  self._irregulars_rev[lang] = self._irregulars_rev[lang] or {}
  self._uncountables[lang]   = self._uncountables[lang] or {}

  func(self)

  return self
end

function Flow.Inflector:plurals()
  return self._plurals[self.current_language]
end

function Flow.Inflector:singulars()
  return self._singulars[self.current_language]
end

function Flow.Inflector:uncountables()
  return self._uncountables[self.current_language]
end

function Flow.Inflector:irregulars()
  return self._irregulars[self.current_language]
end

function Flow.Inflector:irregulars_reverse()
  return self._irregulars_rev[self.current_language]
end

function Flow.Inflector:plural(expression, replacement)
  table.insert(self._plurals[self.current_language], {
    expression = expression,
    replacement = replacement
  })

  return self
end

function Flow.Inflector:singular(expression, replacement)
  table.insert(self._singulars[self.current_language], {
    expression = expression,
    replacement = replacement
  })

  return self
end

function Flow.Inflector:irregular(word, replacement)
  self._irregulars[self.current_language][word] = replacement
  self._irregulars_rev[self.current_language][replacement] = word

  return self
end

function Flow.Inflector:uncountable(words)
  local lang = self.current_language

  if isstring(words) then
    self._uncountables[lang][word] = true
  elseif istable(words) then
    for k, v in ipairs(words) do
      self._uncountables[lang][v] = true
    end
  end

  return self
end

function Flow.Inflector:pluralize(word)
  local original_word = word

  if word:find('_') then
    word = word:match('_([%w]+)$')
  end

  local irregular = self:irregulars()[word]

  if irregular then return original_word:gsub(word, irregular) end
  if self:uncountables()[word] then return original_word end

  for k, v in ipairs(self:plurals()) do
    local original_text = word
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      return original_word:gsub(original_text, text)
    end
  end

  return word
end

function Flow.Inflector:singularize(word)
  local original_word = word

  if word:find('_') then
    word = word:match('_([%w]+)$')
  end

  local irregular = self:irregulars_reverse()[word]

  if irregular then return original_word:gsub(word, irregular) end
  if self:uncountables()[word] then return original_word end

  for k, v in ipairs(self:singulars()) do
    local original_text = word
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      return original_word:gsub(original_text, text)
    end
  end

  return word
end
