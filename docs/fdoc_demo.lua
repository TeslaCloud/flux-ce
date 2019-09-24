--- Demo all that FDoc has to offer.
--
-- Triple ticks will be automatically recognized as an example.
--  ```
--  -- Some example. This comment will appear in the example.
--  test(123, player, { test = true })
--  ```
--
-- You can continue writing description after examples.
-- All lines that begin with @ will be treated differently.
--
-- @warning [Internal] Some custom message to append instead of default message for "Internal".
-- @deprecation [Text to display in the warning window. Should be deprecation reason.]
-- @deprecation_version [0.8.0]
-- @param a=Default Value or Description [Number Some number]
-- @param b [Object Some object]
-- @param c [Hash Table]
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
-- @return [Nil You do not have to specify this explicitly if it returns nil, but you can if you want to add a message to it.]
--
function foo(a, b)
  -- ...
end
