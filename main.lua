--TO DO LIST
-- Make AI Crewmates damage scale properly
-- Find cleaner way to get other player's damage output.
-- Look into body expertise and/or headshot damage | No BE, but clamp to Judge is fine
-- Look into explosive damage being amplified

ccolor = Color(255, 0, 170, 255) / 255 --defining a color for debug chat messages
tmp_vec1 = Vector3()
tmp_vec2 = Vector3()
tmp_vec3 = Vector3()
tmp_vec4 = Vector3() --the one vector from GamePlayCentralManager that I can't declare on runtime easily. Rest I'm doing for... reasons

cl_unit = nil
cl_hp = nil
cl_dir = nil
cl_distance = nil
cl_attacker = nil
--is_graze_kill = false
--cl_ is usually "client," first prefix I could think of for saving/storing the values of the parameters pass into _do_shotgun_push
--Reason being is for Graze kills, found it easier to recycle some of values, as Graze is considered after the shotgun push of the original kill

g_dmg = 16.28 --predeclaring to hopefully avoid nil crashes
c_dmg = 1 --same as above
other_kill = false
--local ref_dmg = 15.5 --Base damage of the Judge shotgun, which is our par damage
--Yes, everything's divided by 10 I don't know either

Hooks:PostHook(RaycastWeaponBase, 'should_shotgun_push', 'everyonepushes' , function(self)
		--Check if you're in stealth, if not then do the thing
		if not managers.groupai:state():whisper_mode() then
			--managers.chat:_receive_message(managers.chat.GAME, "Debug", "Pushit!", ccolor)
			return true
		end
			--In stealth, all guns behave as expected
			return _do_shotgun_push
end)

Hooks:PostHook(CopDamage, 'roll_critical_hit', 'get_crit', function(self, attack_data, damage)
	--If a crit was made, take the damage multiplier of said crit and store it, so it can be added to the
	--Force of the launch on kill
	local tvar = Hooks:GetReturn()
	--Return value is a boolean as to whether a critical hit was made. Just building around that, basically
	if tvar == true and gensec_space_program.settings.crit_launch_toggle == true then
		local dum_crit = self._char_tweak.critical_hits or {}
		c_dmg = dum_crit.damage_mul or self._char_tweak.headshot_dmg_mul
	else
		c_dmg = 1 --If it didn't crit, set it back to 1. Simpler to just set this to 1 and always multiply the "scale" value
		--by this var every time than to run a check down there.
	end
	--managers.chat:_receive_message(managers.chat.GAME, "roll_critical_hit", "Crit for " .. c_dmg, ccolor)
end)

Hooks:PostHook(CopDamage, 'sync_damage_bullet', 'get_ded', function(self, attacker_unit, damage_percent, i_body, hit_offset_height, variant, death)
	local hit_pos = mvector3.copy(self._unit:movement():m_pos())
	mvector3.set_z(hit_pos, hit_pos.z + hit_offset_height)
	local attack_dir, s_distance = nil

	if attacker_unit then
		attack_dir = hit_pos - attacker_unit:movement():m_head_pos()
		s_distance = mvector3.normalize(attack_dir)
	else
		attack_dir = self._unit:rotation():y()
	end
	
	if death and gensec_space_program.settings.other_players_launch == true then
		other_kill = true
		--is_graze_kill = false
		g_dmg = damage_percent * self._HEALTH_INIT_PRECENT
		--g_dmg = g_dmg * 5
		c_dmg = 1
		dmg_mul = 1
		ref_dmg = (gensec_space_program.settings.reference_damage / 10) * (damage_percent * self._HEALTH_INIT_PRECENT)
		managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_dir, s_distance)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ded for " .. g_dmg .. " ref ".. ref_dmg .. " d_% " .. damage_percent .. " ship " .. self._HEALTH_INIT_PRECENT, ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ref is " .. ref_dmg, ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "d_% is " .. damage_percent .. "", ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ship = " .. self._HEALTH_INIT_PRECENT, ccolor)
	end

end)

Hooks:PostHook(CopDamage, 'damage_simple', 'get_graze', function(self, attack_data)
	if attack_data.result ~= nil then
		--attack_data.result comes up nil when shooting invuln marshalls. The bandade of all time™
	else
		return
	end
	if attack_data.variant == "graze" and attack_data.result.type == "death" then
		--managers.chat:_receive_message(managers.chat.GAME, "damage_simple", "graze for " .. g_dmg, ccolor)
		--g_dmg = attack_data.damage
		--attack_data.attack_dir will grab from original point of impact, cl_dir should in theory get the vector between player and original enemy
		--cl_dir will now
		c_dmg = 1
		dmg_mul = 1
		other_kill = false
		--is_graze_kill = true
		--managers.chat:_receive_message(managers.chat.GAME, "damage_simple", "graze!", ccolor)
		local hit_pos = mvector3.copy(self._unit:movement():m_pos())
		--local g_distance = mvector3.normalize(attack_data.attack_dir)
		if cl_dir ~= nil then 
			local g_distance = mvector3.normalize(cl_dir)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
		else
			local g_distance = mvector3.normalize(attack_data.attack_dir)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_data.attack_dir, g_distance, cl_attacker)
		end
		--managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
		--if is_graze_kill == true then
			--managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
		--else
			--managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_data.attack_dir, g_distance, cl_attacker)
			--cl_dir = attack_data.attack_dir
			--is_graze_kill = true
		--end
	end
end)

Hooks:PostHook(CopDamage, 'damage_bullet', 'get_not_graze', function(attack_data)
	--managers.chat:_receive_message(managers.chat.GAME, "damage_bullet", "boolet", ccolor)
	--is_graze_kill = false
	other_kill = false
	cl_dir = attack_data.attack_dir
end)

Hooks:PostHook(CopDamage, 'damage_explosion', 'get_boomies', function(self, attack_data)
	if attack_data.result ~= nil then
		--attack_data.result comes up nil when shooting invuln marshalls. The bandade of all time™
	else
		return
	end
	if attack_data.result.type == "death" then
		g_dmg = attack_data.damage
		--managers.chat:_receive_message(managers.chat.GAME, "damage_explosion", "boom", ccolor)
		c_dmg = 1
		dmg_mul = 1
		other_kill = false
		--is_graze_kill = true
		--managers.chat:_receive_message(managers.chat.GAME, "damage_simple", "graze!", ccolor)
		local hit_pos = mvector3.copy(self._unit:movement():m_pos())
		--local g_distance = mvector3.normalize(attack_data.attack_dir)
		cl_dir = attack_data.col_ray.ray
		if cl_dir ~= nil then 
			local g_distance = mvector3.normalize(cl_dir)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
		else
			local g_distance = mvector3.normalize(attack_data.attack_dir)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_data.attack_dir, g_distance, cl_attacker)
		end
	end
end)

Hooks:PostHook(CopDamage, 'sync_damage_explosion', 'get_other_boomies', function(self, attacker_unit, damage_percent, i_attack_variant, death, direction, weapon_unit)
	local hit_pos = mvector3.copy(self._unit:movement():m_pos())
	--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_explosion", "boom", ccolor)
	--mvector3.set_z(hit_pos, hit_pos.z + hit_offset_height)
	mvector3.set_z(hit_pos, hit_pos.z)
	local attack_dir, s_distance = nil

	if attacker_unit then
		attack_dir = hit_pos - attacker_unit:movement():m_head_pos()
		s_distance = mvector3.normalize(attack_dir)
	else
		attack_dir = self._unit:rotation():y()
	end
	
	if death and gensec_space_program.settings.other_players_launch == true then
		other_kill = true
		--is_graze_kill = false
		g_dmg = damage_percent * self._HEALTH_INIT_PRECENT
		g_dmg = g_dmg * 5
		c_dmg = 1
		dmg_mul = 1
		ref_dmg = (gensec_space_program.settings.reference_damage / 10) * (damage_percent * self._HEALTH_INIT_PRECENT)
		managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_dir, s_distance)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ded for " .. g_dmg .. " ref ".. ref_dmg .. " d_% " .. damage_percent .. " ship " .. self._HEALTH_INIT_PRECENT, ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ref is " .. ref_dmg, ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "d_% is " .. damage_percent .. "", ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_bullet", "ship = " .. self._HEALTH_INIT_PRECENT, ccolor)
	end
end)

--[[Hooks:PostHook(CopDamage, 'damage_melee', 'get_bonked', function(self,attack_data)
	--managers.chat:_receive_message(managers.chat.GAME, "damage_melee", "bonk", ccolor)
	if attack_data.result.type == "death" then
		managers.chat:_receive_message(managers.chat.GAME, "damage_melee", "bonk", ccolor)
		g_dmg = attack_data.damage
		c_dmg = 1
		dmg_mul = 1
		other_kill = false
		--is_graze_kill = true
		--managers.chat:_receive_message(managers.chat.GAME, "damage_simple", "graze!", ccolor)
		local hit_pos = mvector3.copy(self._unit:movement():m_pos())
		--local g_distance = mvector3.normalize(attack_data.attack_dir)
		--cl_dir = attack_data.col_ray.body
		if cl_dir ~= nil then 
			local g_distance = mvector3.normalize(cl_dir)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
		else
			local g_distance = mvector3.normalize(attack_data.col_ray.body)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_data.attack_dir, g_distance, cl_attacker)
		end
	end
end)]]--

--[[Hooks:PostHook(RaycastWeaponBase, 'melee_damage_info', 'get_melee_stuff', function(self,...)
	local my_tweak_data = self:weapon_tweak_data()
	local dmg = my_tweak_data.damage_melee * self:melee_damage_multiplier()
	local dmg_effect = dmg * my_tweak_data.damage_melee_effect_mul
	managers.chat:_receive_message(managers.chat.GAME, "melee_damage_info", "Bonking for " .. dmg_effect .." dmg_mul is ".. dmg_mul, ccolor)
end)]]--

Hooks:PreHook(RaycastWeaponBase, '_get_current_damage', 'get_real_damage' , function(self, dmg_mul)
	g_dmg = self._damage * dmg_mul
	other_kill = false
	--dmg_mul accounts for Overkill, Berserker, and Trigger Happy.
	--managers.chat:_receive_message(managers.chat.GAME, "Debug", "Firing for " .. g_dmg .." dmg_mul is ".. dmg_mul, ccolor)
end)

Hooks:PostHook(GamePlayCentralManager, 'get_shotgun_push_range', 'max_range', function(attacker)
	--Make the push universal. On to-do list to make happen only in loud, for obvious reasons.
	--return 999999999999999
	if not managers.groupai:state():whisper_mode() and gensec_space_program.settings.infinite_launch_range == true then
		--managers.chat:_receive_message(managers.chat.GAME, "Debug", "Pushit!", ccolor)
		return 999999999999999
	end
end)



if RequiredScript == "lib/managers/gameplaycentralmanager" then
	function GamePlayCentralManager:_do_shotgun_push(unit, hit_pos, dir, distance, attacker)
		cl_unit = unit
		cl_hp = hit_pos
		cl_dir = dir
		cl_distance = distance
		cl_attacker = attacker
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "pushit!", ccolor)
		local mov_ext = unit:movement()
		local full_body_action = mov_ext and mov_ext:get_action(1)
	
		if full_body_action and full_body_action:type() == "hurt" then
			full_body_action:force_ragdoll(true)
		end
	
	
		local scale = math.clamp(1 - distance / math.min(self:get_shotgun_push_range(attacker), 500), 0.5, 1)
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale pre =  " .. scale , ccolor)
		--Magic happens here. If your gun's damage is higher than the Judge, calculate the ratio and multiply the vector's scalar by it.
		--If not, then it's a Judge (or whatever damage the user specified).
		if not managers.groupai:state():whisper_mode() then
			if other_kill == false then
				ref_dmg = gensec_space_program.settings.reference_damage / 10
			end
			--Multiplies by crits. c_dmg will be 1 if it didn't crit.
			scale = scale * c_dmg
			scale = scale * math.max(1, (g_dmg / ref_dmg))
			scale = scale * gensec_space_program.settings.launch_multiplier
			--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "crit mul  " .. (1 + (gensec_space_program.settings.crit_launch_multiplier / 10)) , ccolor)
		end
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "g_dmg =  " .. g_dmg , ccolor)
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale pre =  " .. scale , ccolor)
		--there was something I was testing here
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale post =  " .. scale , ccolor)
		local rot_time = 1 + math.rand(2)
		local asm = unit:anim_state_machine()
		
		--This is vanilla code will nerf the effect on dozers and - to my knowledge - bosses like Yufu Wang, Gabriel, Sanchez, etc.
		--Might make an option to disable this, or if you're reading this and want to buff
		--dozer pushes for some reason, the entire if statement is safe to delete or comment out.
		--Might make this a toggle later.
		--Update: I made this a toggle later.
		if gensec_space_program.settings.buff_dozer_launches == false and not managers.groupai:state():whisper_mode() then
			if asm and asm:get_global("tank") == 1 then
				scale = scale * 0.3
				rot_time = rot_time * 0.2
			end
		end
		local push_vec = tmp_vec1
		mvector3.set_static(push_vec, dir.x, dir.y, dir.z + 0.5)
		--I've found just incrasing this value of 600 to something higher gets results
		--What I did was band-aid solutions to make things scale with gun damage, however
		--You can also just buff everything with this if you want.
		mvector3.multiply(push_vec, 600 * scale)
	
		local unit_pos = tmp_vec2
	
		unit:m_position(unit_pos)
	
		local height_sign = math.sign( mvector3.distance_sq(hit_pos, unit_pos) - 10000)
		local twist_dir = math.random(2) == 1 and 1 or -1
		local rot_acc = tmp_vec3
	
		mvector3.set(rot_acc, dir)
		mvector3.cross(rot_acc, rot_acc, math.UP)
		mvector3.set(tmp_vec4, math.UP)
		mvector3.multiply(tmp_vec4, 0.5 * twist_dir)
		mvector3.add(rot_acc, tmp_vec4)
		mvector3.multiply(rot_acc, -1000 * height_sign)
	
		local u_body = nil
		local i_u_body = 0
		local get_body_f = unit.body
		local nr_u_bodies = unit:num_bodies()
		local world = World
		local play_physic_effect_f = world.play_physic_effect
		local idstr_shotgun_push_effect = Idstring("physic_effects/shotgun_hit")
	
		for i = 0, unit:num_bodies() - 1 do
			u_body = get_body_f(unit, i)
	
			if u_body and u_body:enabled() and u_body:dynamic() then
				play_physic_effect_f(world, idstr_shotgun_push_effect, u_body, push_vec, 4 * u_body:mass() / math.random(2), rot_acc, rot_time)
			end
		end
	
		managers.mutators:notify(Message.OnShotgunPush, unit, hit_pos, dir, distance, attacker)
	end
end


--OPTIONS STUFF HERE (thanks hoppip)--
Hooks:Add("LocalizationManagerPostInit", "GSP_menu_loc", function(localization_manager)

	localization_manager:add_localized_strings({
	  ["menu_gensec_space_program_buff_dozer_launches_desc"] = "Choose whether or not to disable the vanilla behavior of dozers/bosses getting reduced launch power (70% reduction).",
	  ["menu_gensec_space_program_reference_damage_desc"] = "Chooses the 'pivot point' of the launch multiplier. Higher will mean stronger launches on average, and vice versa. (Default is 162.80, or a stock Judge).",
	  ["menu_gensec_space_program_launch_multiplier_desc"] = "A multiplier of the launch overall.",
	  ["menu_gensec_space_program_infinite_launch_range_desc"] = "Whether or not you want to launch cops with kills further than 5 meters away from you.",
	  ["menu_gensec_space_program_crit_launch_toggle"] = "Crits amplify launch strength",
	  ["menu_gensec_space_program_crit_launch_toggle_desc"] = "Determines whether or not critical hits will amplify the strength of the launch, according to the enemy's respective damage multiplier.",
	  ["menu_gensec_space_program_other_players_launch"] = "Other players can launch corpses",
	  ["menu_gensec_space_program_other_players_launch_desc"] = "Determine whether or not other players in the session will launch bodies according to the other options specified here. Jokers, turrets, and AI Crew mates are not considered.",
	  --["menu_gensec_space_program_crit_launch_multiplier_desc"] = "Choose if you want critical hits to amplify the launch further, and if so, by how much."
	})
  end)

dofile(ModPath .. "automenubuilder.lua") -- run the auto menu builder file to have access to its functions

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusgensec_space_program", function(menu_manager, nodes)

	AutoMenuBuilder:load_settings(gensec_space_program.settings, "gensec_space_program")
	--ref_dmg_IDENTIFIER_OPTION_desc = "test"
	AutoMenuBuilder:create_menu_from_table(nodes, gensec_space_program.settings, "gensec_space_program", "blt_options", gensec_space_program.values --[[ optional ]], gensec_space_program.order --[[ optional ]])
  
  end)

gensec_space_program = gensec_space_program or {
  settings = {
    buff_dozer_launches = false, 
    reference_damage = 162.80, 
    launch_multiplier = 1, 
	infinite_launch_range = false,
	crit_launch_toggle = true, 
	other_players_launch = true,
	--crit_launch_multiplier = 1
  },
  values = {
    reference_damage = { 10, 10000, 0.01 }, -- number values make a slider with min, max and step value
	launch_multiplier = { 0.1, 5, 0.1 },
    --crit_launch_multiplier = { 0, 1, 0.01 }
  },
}
