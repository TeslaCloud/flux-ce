class 'ActiveRecord::Inflector'

ActiveRecord.Inflector._plurals = {}
ActiveRecord.Inflector._singulars = {}
ActiveRecord.Inflector._irregulars = {}
ActiveRecord.Inflector._irregulars_rev = {}
ActiveRecord.Inflector._uncountables = {}
ActiveRecord.Inflector.current_language = 'en'

function ActiveRecord.Inflector:inflections(lang, func)
  self.current_language     = lang or 'en'
  self._plurals[lang]        = self._plurals[lang] or {}
  self._singulars[lang]      = self._singulars[lang] or {}
  self._irregulars[lang]     = self._irregulars[lang] or {}
  self._irregulars_rev[lang] = self._irregulars_rev[lang] or {}
  self._uncountables[lang]   = self._uncountables[lang] or {}

  func(self)

  return self
end

function ActiveRecord.Inflector:plurals()
  return self._plurals[self.current_language]
end

function ActiveRecord.Inflector:singulars()
  return self._singulars[self.current_language]
end

function ActiveRecord.Inflector:uncountables()
  return self._uncountables[self.current_language]
end

function ActiveRecord.Inflector:irregulars()
  return self._irregulars[self.current_language]
end

function ActiveRecord.Inflector:irregulars_reverse()
  return self._irregulars_rev[self.current_language]
end

function ActiveRecord.Inflector:plural(expression, replacement)
  table.insert(self._plurals[self.current_language], {
    expression = expression,
    replacement = replacement
  })

  return self
end

function ActiveRecord.Inflector:singular(expression, replacement)
  table.insert(self._singulars[self.current_language], {
    expression = expression,
    replacement = replacement
  })

  return self
end

function ActiveRecord.Inflector:irregular(word, replacement)
  self._irregulars[self.current_language][word] = replacement
  self._irregulars_rev[self.current_language][replacement] = word

  return self
end

function ActiveRecord.Inflector:uncountable(words)
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

function ActiveRecord.Inflector:pluralize(word)
  local irregular = self:irregulars()[word]

  if irregular then return irregular end
  if self:uncountables()[word] then return word end

  for k, v in ipairs(self:plurals()) do
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      return text
    end
  end

  return word
end

function ActiveRecord.Inflector:singularize(word)
  local irregular = self:irregulars_reverse()[word]

  if irregular then return irregular end
  if self:uncountables()[word] then return word end

  for k, v in ipairs(self:singulars()) do
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      return text
    end
  end

  return word
end
