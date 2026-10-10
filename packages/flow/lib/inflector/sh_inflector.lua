--- Converts words between their singular and plural forms, in the manner of the inflector of
-- Ruby on Rails. The rules of a language are declared inside of a `Flow.Inflector:inflections`
-- block as pattern replacements, irregular words and uncountable words; the English rules ship
-- with Flux. `Flow.Inflector:pluralize` and `Flow.Inflector:singularize` apply the rules of
-- the current language to a word. ActiveRecord uses them to derive the names of database
-- tables from the names of models, turning 'user' into 'users', and the names of foreign keys
-- from the names of tables.

class 'Flow::Inflector'

Flow.Inflector._plurals = {}
Flow.Inflector._singulars = {}
Flow.Inflector._irregulars = {}
Flow.Inflector._irregulars_rev = {}
Flow.Inflector._uncountables = {}
Flow.Inflector.current_language = 'en'

--- Defines the inflection rules of a language. The rules added inside of the callback
-- (and anything looked up afterward) belong to that language.
-- ```
-- Flow.Inflector:inflections('en', function(inflect)
--   inflect:plural(i'^(ox)$', '%1en')
--   inflect:singular(i'(quiz)zes$', '%1')
--   inflect:irregular('person', 'people')
--   inflect:uncountable(w'data ammo equipment')
-- end)
-- ```
-- @param lang [String language code]
-- @param func [Function receives the inflector]
-- @return [Flow::Inflector self, for chaining]
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

--- Returns the pluralization rules of the current language.
-- @return [List<Map> rules with the expression and replacement keys]
function Flow.Inflector:plurals()
  return self._plurals[self.current_language]
end

--- Returns the singularization rules of the current language.
-- @return [List<Map> rules with the expression and replacement keys]
function Flow.Inflector:singulars()
  return self._singulars[self.current_language]
end

--- Returns the uncountable words of the current language.
-- @return [Map true by word]
function Flow.Inflector:uncountables()
  return self._uncountables[self.current_language]
end

--- Returns the irregular words of the current language.
-- @return [Map plural forms by singular form]
function Flow.Inflector:irregulars()
  return self._irregulars[self.current_language]
end

--- Returns the irregular words of the current language, the other way around.
-- @return [Map singular forms by plural form]
function Flow.Inflector:irregulars_reverse()
  return self._irregulars_rev[self.current_language]
end

--- Adds a pluralization rule to the current language.
-- @param expression [String Lua pattern that the singular form must match]
-- @param replacement [String what to replace the match with, can refer to captures]
-- @return [Flow::Inflector self, for chaining]
function Flow.Inflector:plural(expression, replacement)
  local rules = self._plurals[self.current_language]

  rules[#rules + 1] = {
    expression = expression,
    replacement = replacement
  }

  return self
end

--- Adds a singularization rule to the current language.
-- @param expression [String Lua pattern that the plural form must match]
-- @param replacement [String what to replace the match with, can refer to captures]
-- @return [Flow::Inflector self, for chaining]
function Flow.Inflector:singular(expression, replacement)
  local rules = self._singulars[self.current_language]

  rules[#rules + 1] = {
    expression = expression,
    replacement = replacement
  }

  return self
end

--- Adds a word that does not follow the regular rules to the current language.
-- @param word [String singular form]
-- @param replacement [String plural form]
-- @return [Flow::Inflector self, for chaining]
function Flow.Inflector:irregular(word, replacement)
  self._irregulars[self.current_language][word] = replacement
  self._irregulars_rev[self.current_language][replacement] = word

  return self
end

--- Adds words that have no separate plural form to the current language.
-- @param words [String/List<String> a word or a list of words]
-- @return [Flow::Inflector self, for chaining]
function Flow.Inflector:uncountable(words)
  local lang = self.current_language

  local uncountables = self._uncountables[lang]

  if isstring(words) then
    uncountables[words] = true
  elseif istable(words) then
    for k, v in ipairs(words) do
      uncountables[v] = true
    end
  end

  return self
end

--- Converts a word to its plural form using the rules of the current language.
-- Only the last part of a snake_case word is converted.
-- @param word [String]
-- @return [String plural form, Number amount of replacements (irregular words only)]
function Flow.Inflector:pluralize(word)
  local original_word = word

  if word:find('_') then
    word = word:match('_([%w]+)$')
  end

  local irregular = self:irregulars()[word]

  if irregular then return original_word:gsub(word, irregular) end
  if self:uncountables()[word] then return original_word end

  local rules = self:plurals()

  for i = 1, #rules do
    local v = rules[i]
    local original_text = word
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      local ret = original_word:gsub(original_text, text)
      return ret
    end
  end

  return word
end

--- Converts a word to its singular form using the rules of the current language.
-- Only the last part of a snake_case word is converted.
-- @param word [String]
-- @return [String singular form, Number amount of replacements (irregular words only)]
function Flow.Inflector:singularize(word)
  local original_word = word

  if word:find('_') then
    word = word:match('_([%w]+)$')
  end

  local irregular = self:irregulars_reverse()[word]

  if irregular then return original_word:gsub(word, irregular) end
  if self:uncountables()[word] then return original_word end

  local rules = self:singulars()

  for i = 1, #rules do
    local v = rules[i]
    local original_text = word
    local text, replacements = word:gsub(v.expression, v.replacement)

    if (replacements or 0) > 0 then
      local ret = original_word:gsub(original_text, text)
      return ret
    end
  end

  return word
end
