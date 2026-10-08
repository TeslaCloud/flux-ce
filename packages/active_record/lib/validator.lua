--- Validations of model objects. `ActiveRecord::Base#validates` attaches validations to a
-- column of a model, and `ActiveRecord::Base#save` runs them through `validate_model`
-- before anything is written: the object is saved only if all of them pass, otherwise its
-- `invalid` callback receives the column and the id of the validation that failed.
--
-- The built-in validations are `presence` (the value is not nil), `min_length` and
-- `max_length` (length of a string in UTF-8 characters), `format` (the value matches a
-- Lua pattern) and `uniqueness` (no row of the table holds the same value, ignoring
-- case). More can be registered with `add`.

class 'ActiveRecord::Validator'

ActiveRecord.Validator.validators = {}

local function run_validation(model, column, v_opts, v_id, success_callback, error_callback)
  local function process_next()
    if v_opts[v_id + 1] then
      run_validation(model, column, v_opts, v_id + 1, success_callback, error_callback)
    else
      success_callback(model)
    end
  end

  local vo = v_opts[v_id]

  if vo then
    local validator = ActiveRecord.Validator.validators[vo.id]

    if isfunction(validator) then
      return validator(model, column, vo.value, v_opts, function()
        process_next()
      end, error_callback)
    end
  end

  process_next()
end

local function validate_column(model, schema, validations, column, success_callback, error_callback)
  local function process_next()
    local next_key = next(schema, column)

    if next_key then
      validate_column(model, schema, validations, next_key, success_callback, error_callback)
    else
      success_callback(model)
    end
  end

  local v_options = validations[column]

  if v_options then
    run_validation(model, column, v_options, 1, function()
      process_next()
    end, error_callback)
  else
    process_next()
  end
end

--- Runs the validations defined on a model, one column at a time. Validators may be
-- asynchronous, so the outcome is reported through the callbacks.
-- @param model [ActiveRecord::Base object to validate]
-- @param success_callback [Function called with the model once every validation passed]
-- @param error_callback [Function called with the model, the column name and an error
--   code as soon as a validation fails]
-- @return [ActiveRecord::Validator/Boolean self, or false if the model has no schema]
function ActiveRecord.Validator:validate_model(model, success_callback, error_callback)
  local schema = model:get_schema()
  local validations = model.validations or {}

  if !schema then error_callback(model, 'schema', 'schema_invalid') return false end

  local schema_key = next(schema)

  if model.before_validation then
    model:before_validation(!model.fetched)
  end

  local after_validation = function(succeeded)
    if model.after_validation then
      model:after_validation(succeeded, !model.fetched)
    end
  end

  local _on_success = function(...)
    after_validation(true)
    return success_callback(...)
  end

  local _on_fail = function(...)
    after_validation(false)
    return error_callback(...)
  end

  validate_column(model, schema, validations, schema_key, _on_success, _on_fail)

  return self
end

--- Registers a validator, which can then be used with ActiveRecord::Base#validates.
-- A validator has to call exactly one of the two callbacks it is given.
-- ```
-- ActiveRecord.Validator:add('presence', function(model, column, val, opts, success, fail)
--   if model[column] != nil then
--     success(model)
--   else
--     fail(model, column, 'presence')
--   end
-- end)
-- ```
-- @param id [String name of the validation, the key used in the options of #validates]
-- @param callback [Function receives the model, the column name, the value given for
--   this validation, all validation options of the column, a success callback and an
--   error callback]
-- @return [ActiveRecord::Validator(self)]
function ActiveRecord.Validator:add(id, callback)
  self.validators[id] = callback
  return self
end

ActiveRecord.Validator:add('presence', function(model, column, val, opts, success_callback, error_callback)
  if model[column] != nil then
    success_callback(model)
  else
    error_callback(model, column, 'presence')
  end
end)

ActiveRecord.Validator:add('min_length', function(model, column, val, opts, success_callback, error_callback)
  local c = model[column]

  if isstring(c) and utf8.len(c) >= val then
    success_callback(model)
  else
    error_callback(model, column, 'min_length')
  end
end)

ActiveRecord.Validator:add('max_length', function(model, column, val, opts, success_callback, error_callback)
  local c = model[column]

  if isstring(c) and utf8.len(c) <= val then
    success_callback(model)
  else
    error_callback(model, column, 'max_length')
  end
end)

ActiveRecord.Validator:add('format', function(model, column, val, opts, success_callback, error_callback)
  local c = model[column]

  if c and c:match(val) then
    success_callback(model)
  else
    error_callback(model, column, 'format')
  end
end)

ActiveRecord.Validator:add('uniqueness', function(model, column, val, opts, success_callback, error_callback)
  if model[column] != nil then
    local m = nil

    if !opts.case_sensitive then
      m = model:where('lower('..column..') = ?', string.lower(tostring(model[column])))
    else
      m = model:where(column, tostring(model[column]))
    end

    if m then
      m:get(function()
        error_callback(model, column, 'uniqueness')
      end):rescue(function()
        success_callback(model)
      end)
    else
      error_callback(model, column, 'uniqueness')
    end
  end
end)
