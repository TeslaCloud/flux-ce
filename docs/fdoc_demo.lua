--- Demo all that FDoc has to offer.
-- The first doc comment of a file, followed by a blank line, documents the file itself.
-- @module [Demo]

--- Summary line, followed by a longer description in Markdown.
--
-- Triple ticks will be automatically recognized as an example.
-- ```
-- -- Some example. This comment will appear in the example.
-- test(123, actor, { test = true })
-- ```
--
-- You can continue writing description after examples.
-- All lines that begin with @ will be treated differently.
--
-- @warning [Internal] Some custom message to append instead of default message for "Internal".
-- @deprecation [Text to display in the warning window. Should be deprecation reason.]
-- @deprecation_version [0.8.0]
-- @alias [Demo.other_test]
-- @param a=Default Value or Description [Number Some number]
-- @param b [Player Some player]
-- @param c [Map Table]
-- @return [Foo blank foo object, Number one hundred]
--
-- You can also refer to other functions (both variations are valid)
-- @see other_function
-- @see [MyClass#method]
function test(a, b, c)
  return Foo.new(), 100
end

--- Demo variable argument functions.
-- @variant foo(a, b)
--   @param a [Number This variant accepts a number as the first parameter]
--   @param b [String And a string as the second parameter!]
-- @variant foo(a)
--   @param a [String If you specify a string here it will do something else!]
-- @return [Nil You do not have to specify this explicitly if it returns nil, but you can if you
--   want to add a message to it. Bracketed tag bodies may continue on the next lines.]
function foo(a, b)
end

--- Demo a function that only does its work in one environment and on one realm.
-- @environment [development] Prints nothing outside of the development environment.
-- @realm [server]
-- @param text [String text to print]
function debug_print(text)
  if IS_DEVELOPMENT then
    print(text)
  end
end

--- Demo a function that runs a hook.
-- @param actor [Player player the hook is about]
-- @param items [List<Item> items the player carries]
function run_demo_hook(actor, items)
  --- Demo a documented hook. The doc comment directly above a line that runs a hook
  -- documents the hook.
  -- @param actor [Player player the hook is about]
  -- @param items [List<Item> items the player carries]
  -- @return [Boolean Return false to stop it]
  hook.Run('DemoHook', actor, items)
end

--- @ignore
function undocumented_helper()
end
