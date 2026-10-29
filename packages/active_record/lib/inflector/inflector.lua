--- Converts words between their singular and plural forms. The rules of a language are declared
-- inside of an `ActiveRecord.Inflector:inflections` block as pattern replacements, irregular words
-- and uncountable words; the English rules ship with Flux. `ActiveRecord.Inflector:pluralize`
-- and `ActiveRecord.Inflector:singularize` apply the rules of the current language to the last
-- part of a snake_case word. ActiveRecord uses them to derive the names of database tables from
-- the names of models, turning 'user' into 'users', and the names of foreign keys from the names
-- of tables.

class 'ActiveRecord::Inflector'

ActiveRecord.Inflector._plurals = {}
ActiveRecord.Inflector._singulars = {}
ActiveRecord.Inflector._irregulars = {}
ActiveRecord.Inflector._irregulars_rev = {}
ActiveRecord.Inflector._uncountables = {}
ActiveRecord.Inflector.current_language = 'en'

--- Defines the inflection rules of a language. The rules added inside of the callback
-- (and anything looked up afterward) belong to that language.
-- ```
-- ActiveRecord.Inflector:inflections('en', function(inflect)
--   inflect:plural(i'^(ox)$', '%1en')
--   inflect:singular(i'(quiz)zes$', '%1')
--   inflect:irregular('person', 'people')
--   inflect:uncountable(w'data ammo equipment')
-- end)
-- ```
-- @param lang [String language code]
-- @param func [Function receives the inflector]
-- @return [ActiveRecord::Inflector self, for chaining]
function ActiveRecord.Inflector:inflections(lang, func)
  lang = lang or 'en'

  self.current_language      = lang
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
function ActiveRecord.Inflector:plurals()
  return self._plurals[self.current_language]
end

--- Returns the singularization rules of the current language.
-- @return [List<Map> rules with the expression and replacement keys]
function ActiveRecord.Inflector:singulars()
  return self._singulars[self.current_language]
end

--- Returns the uncountable words of the current language.
-- @return [Map true by word]
function ActiveRecord.Inflector:uncountables()
  return self._uncountables[self.current_language]
end

--- Returns the irregular words of the current language.
-- @return [Map plural forms by singular form]
function ActiveRecord.Inflector:irregulars()
  return self._irregulars[self.current_language]
end

--- Returns the irregular words of the current language, the other way around.
-- @return [Map singular forms by plural form]
function ActiveRecord.Inflector:irregulars_reverse()
  return self._irregulars_rev[self.current_language]
end

--- Adds a pluralization rule to the current language.
-- @param expression [String Lua pattern that the singular form must match]
-- @param replacement [String what to replace the match with, can refer to captures]
-- @return [ActiveRecord::Inflector self, for chaining]
function ActiveRecord.Inflector:plural(expression, replacement)
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
-- @return [ActiveRecord::Inflector self, for chaining]
function ActiveRecord.Inflector:singular(expression, replacement)
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
-- @return [ActiveRecord::Inflector self, for chaining]
function ActiveRecord.Inflector:irregular(word, replacement)
  self._irregulars[self.current_language][word] = replacement
  self._irregulars_rev[self.current_language][replacement] = word

  return self
end

--- Adds words that have no separate plural form to the current language.
-- @param words [String/List<String> a word or a list of words]
-- @return [ActiveRecord::Inflector self, for chaining]
function ActiveRecord.Inflector:uncountable(words)
  local uncountables = self._uncountables[self.current_language]

  if isstring(words) then
    uncountables[words] = true
  elseif istable(words) then
    for _, word in ipairs(words) do
      uncountables[word] = true
    end
  end

  return self
end

local function inflect_last_part(word, irregulars, uncountables, rules)
  local last_part = word:match('_(%w+)$') or word
  local prefix = word:sub(1, #word - #last_part)
  local irregular = irregulars[last_part]

  if irregular then return prefix..irregular end
  if uncountables[last_part] then return word end

  for i = 1, #rules do
    local rule = rules[i]
    local text, replacements = last_part:gsub(rule.expression, rule.replacement)

    if replacements > 0 then
      return prefix..text
    end
  end

  return word
end

--- Converts a word to its plural form using the rules of the current language.
-- Only the last part of a snake_case word is converted.
-- @param word [String]
-- @return [String plural form]
function ActiveRecord.Inflector:pluralize(word)
  return inflect_last_part(word, self:irregulars(), self:uncountables(), self:plurals())
end

--- Converts a word to its singular form using the rules of the current language.
-- Only the last part of a snake_case word is converted.
-- @param word [String]
-- @return [String singular form]
function ActiveRecord.Inflector:singularize(word)
  return inflect_last_part(word, self:irregulars_reverse(), self:uncountables(), self:singulars())
end
