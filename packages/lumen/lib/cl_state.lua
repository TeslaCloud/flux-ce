--- State for Lumen components. A component is a function of its props; the hooks in this file,
-- called while it renders, give it memory that survives between renders. They must be called
-- in the same order on every render, so they do not belong in conditions or loops. Templates
-- have them in scope as `use_state`, `use_effect`, `use_ref` and `use_memo`.
-- ```
-- return function(props)
--   local count, set_count = use_state(0)
--
--   use_effect(function()
--     print('The count is now '..count)
--   end, { count })
--
--   return <button on_press={function() set_count(count + 1) end}>
--     Clicked {count} times
--   </button>
-- end
-- ```
-- @module [Lumen.State]

mod 'Lumen::State'

local isfunction = isfunction

local current = nil

--- Starts a render of a component: the hooks that follow belong to this instance.
-- @param instance [Map instance of the component, as the reconciler keeps it]
function Lumen.State.begin(instance)
  instance.hooks = instance.hooks or {}
  instance.hook_index = 0
  current = instance
end

--- Ends the render that `begin` started.
function Lumen.State.finish()
  current = nil
end

--- Returns the instance that is rendering.
-- @return [Map the instance, or nil outside of a render]
function Lumen.State.current()
  return current
end

--- Returns the slot of the next hook of the rendering component, creating it the first time.
-- @param kind [String what the hook is, to catch hooks called in a different order]
-- @return [Map the slot, Boolean whether it has just been created]
local function next_slot(kind)
  if !current then
    error('Lumen: hooks can only be called while a component renders', 3)
  end

  local index = current.hook_index + 1
  current.hook_index = index

  local slot = current.hooks[index]

  if !slot then
    slot = { kind = kind }
    current.hooks[index] = slot

    return slot, true
  end

  if slot.kind != kind then
    error('Lumen: hook '..index..' was '..slot.kind..' on the last render and is '..kind..' now; '..
      'hooks must be called in the same order on every render', 3)
  end

  return slot, false
end

--- Gives the component a value that it can change. Changing it renders the component again
-- on the next frame, unless the new value is the same as the old one.
-- @param initial [Any the value on the first render; a function is called for it]
-- @return [Any the current value, Function sets the value: give it the new value, or a
--   function that receives the current value and returns the new one]
function Lumen.use_state(initial)
  local slot, created = next_slot('state')

  if created then
    local instance = current

    if isfunction(initial) then
      initial = initial()
    end

    slot.value = initial
    slot.set = function(value)
      if isfunction(value) then
        value = value(slot.value)
      end

      if value == slot.value then return end

      slot.value = value

      Lumen.Reconciler.schedule(instance)
    end
  end

  return slot.value, slot.set
end

--- Runs a function after the component has been mounted or updated. With dependencies the
-- function only runs when one of them has changed since the last render; with an empty list it
-- runs once, after the first render. The function may return a function that cleans up, which
-- runs before the next run and when the component is unmounted.
-- ```
-- use_effect(function()
--   local timer_name = 'lumen_clock_'..tostring(ref.current)
--
--   timer.Create(timer_name, 1, 0, function() set_time(os.time()) end)
--
--   return function()
--     timer.Remove(timer_name)
--   end
-- end, {})
-- ```
-- @param effect [Function the effect, may return a cleanup function]
-- @param deps=nil [List values the effect depends on; nil runs it after every render]
function Lumen.use_effect(effect, deps)
  local slot, created = next_slot('effect')
  local changed = created or deps == nil or !Lumen.shallow_equal(deps, slot.deps)

  slot.deps = deps

  if changed then
    slot.pending = effect

    Lumen.Reconciler.queue_effect(current, slot)
  end
end

--- Gives the component a table that stays the same between renders, to keep anything in
-- without rendering again when it changes. Passed as the `ref` prop of an element, it receives
-- the panel of the element in `current`.
-- @param initial=nil [Any the value of `current` on the first render]
-- @return [Map the table, with the value in `current`]
function Lumen.use_ref(initial)
  local slot, created = next_slot('ref')

  if created then
    slot.ref = { current = initial }
  end

  return slot.ref
end

--- Computes a value and keeps it until one of the dependencies changes.
-- @param compute [Function returns the value]
-- @param deps=nil [List values the result depends on; nil computes it on every render]
-- @return [Any the value]
function Lumen.use_memo(compute, deps)
  local slot, created = next_slot('memo')

  if created or deps == nil or !Lumen.shallow_equal(deps, slot.deps) then
    slot.deps = deps
    slot.value = compute()
  end

  return slot.value
end

--- Runs the cleanups of the effects of an instance, when it is unmounted.
-- @param instance [Map instance of the component]
function Lumen.State.cleanup(instance)
  for k, slot in ipairs(instance.hooks or {}) do
    if slot.kind == 'effect' then
      slot.pending = nil

      if isfunction(slot.cleanup) then
        local cleanup = slot.cleanup

        slot.cleanup = nil

        local success, err = pcall(cleanup)

        if !success then
          ErrorNoHalt('Lumen: an effect cleanup has failed: '..tostring(err)..'\n')
        end
      end
    end
  end
end

--- Runs an effect whose dependencies have changed: its previous cleanup first, then the
-- effect, keeping whatever it returns as the next cleanup.
-- @param slot [Map the hook slot of the effect]
function Lumen.State.run_effect(slot)
  local effect = slot.pending

  slot.pending = nil

  if !isfunction(effect) then return end

  if isfunction(slot.cleanup) then
    local cleanup = slot.cleanup

    slot.cleanup = nil

    local success, err = pcall(cleanup)

    if !success then
      ErrorNoHalt('Lumen: an effect cleanup has failed: '..tostring(err)..'\n')
    end
  end

  local success, result = pcall(effect)

  if !success then
    ErrorNoHalt('Lumen: an effect has failed: '..tostring(result)..'\n')
  elseif isfunction(result) then
    slot.cleanup = result
  end
end
