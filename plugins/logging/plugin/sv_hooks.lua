--- Logs the damage that players take, serverside.

local log_damage = { '[DAMAGE]', Color(255, 0, 0) }

hook.Add('PlayerHurt', 'Damage_Log', function(target, attacker, _health, damage)
  Logging:print_admin_log(log_damage, target:GetName()..' has taken '..math.Round(damage)..' damage from '..
    attacker:GetName())
end)
