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

  if c and c:len() >= val then
    success_callback(model)
  else
    error_callback(model, column, 'min_length')
  end
end)

ActiveRecord.Validator:add('max_length', function(model, column, val, opts, success_callback, error_callback)
  local c = model[column]

  if c and c:len() <= val then
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

    if opts.case_sensitive then
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
