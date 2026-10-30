--- Client-side receiver of the Gamemastery plugin: the list of pool characters that the
-- server sends to gamemasters.

Cable.receive('fl_gm_pool', function(pool)
  Gamemastery.pool = istable(pool) and pool or {}

  --- Called on the client when the list of pool characters has arrived from the server and
  -- has been stored. The server sends it to gamemasters when they join, when their role or
  -- permissions change and whenever the pool changes; the gamemaster panel rebuilds itself.
  -- @param pool [List<Map> entries with the id, name, model, skin, phys_desc, faction,
  --   banned, possessed_by and in_world fields]
  hook.Run('GamemasterPoolReceived', Gamemastery.pool)
end)
