--TO DO LIST
-- Make AI Crewmates/jokers/sentries damage scale properly
-- Look into body expertise and/or headshot damage | No BE, but clamp to Judge is fine
-- Work in HVT(?)
-- Restructure to prevent multi-hooking
-- Melee cloakers katana as Jiro is weird interaction

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
--g_dmg_mul = 1 --to extract damage boosts like Zerk, OVK, etc.
c_dmg = 1 --same as above
other_kill = false
other_melee = false --no comment
--ref_dmg = 16.28 --Base damage of the Judge shotgun, which is our par damage
--Yes, everything's divided by 10 I don't know either
m_lerp = 0 --for the value 'charge_lerp_value' in playerstandard.lua, in order to properly gauge melee damage

if RequiredScript == "lib/units/enemies/cop/copdamage" then 
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
	end)

	Hooks:PostHook(CopDamage, 'damage_bullet', 'get_not_graze', function(self, attack_data)
		other_kill = false
		cl_dir = attack_data.attack_dir
	end)

	Hooks:PostHook(CopDamage, 'sync_damage_bullet', 'get_ded', function(self, attacker_unit, damage_percent, i_body, hit_offset_height, variant, death)
		local hit_pos = mvector3.copy(self._unit:movement():m_pos())
		mvector3.set_z(hit_pos, hit_pos.z + hit_offset_height)
		local attack_dir, s_distance = nil
		local attack_data = {}
		attack_data.pos = hit_pos
		attack_data.attacker_unit = attacker_unit
		attack_data.variant = "bullet"
		attack_data.headshot = head
		attack_data.weapon_unit = attacker_unit and attacker_unit:inventory() and attacker_unit:inventory():equipped_unit()
		if attacker_unit then
			attack_dir = hit_pos - attacker_unit:movement():m_head_pos()
			s_distance = mvector3.normalize(attack_dir)
		else
			attack_dir = self._unit:rotation():y()
			s_distance = 1000
		end
		
		if death and gensec_space_program.settings.other_players_launch == true then
			other_kill = true
			--is_graze_kill = false
			g_dmg = damage_percent * self._HEALTH_INIT_PRECENT
			--g_dmg = g_dmg * 5
			c_dmg = 1
			dmg_mul = 1
			ref_dmg = (gensec_space_program.settings.reference_damage / 10) * (damage_percent * self._HEALTH_INIT_PRECENT)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_dir, s_distance, attacker_unit)
		end
	end)

	Hooks:PostHook(CopDamage, 'damage_simple', 'get_graze', function(self, attack_data)
		if attack_data.result ~= nil then
			--attack_data.result comes up nil when shooting invuln marshalls. The bandaid of all time™
		else
			return
		end
		if attack_data.variant == "graze" and attack_data.result.type == "death" then
			--attack_data.attack_dir will grab from original point of impact, cl_dir should in theory get the vector between player and original enemy
			--c_dmg = 1
			dmg_mul = 1
			other_kill = false
			--is_graze_kill = true
			local hit_pos = mvector3.copy(self._unit:movement():m_pos())
			--local g_distance = mvector3.normalize(attack_data.attack_dir)
			if cl_dir ~= nil then 
				local g_distance = mvector3.normalize(cl_dir)
				managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
			else
				local g_distance = mvector3.normalize(attack_data.attack_dir)
				managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_data.attack_dir, g_distance, cl_attacker)
			end
		end
	end)

	Hooks:PostHook(CopDamage, 'damage_explosion', 'get_boomies', function(self, attack_data)
		if attack_data.result ~= nil then
			--attack_data.result comes up nil when shooting invuln marshalls. The bandaid of all time™
		else
			return
		end
		if attack_data.result.type == "death" and not managers.groupai:state():whisper_mode() then
			g_dmg = attack_data.damage
			--c_dmg = 1
			dmg_mul = 1
			other_kill = false
			--is_graze_kill = true
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
		--mvector3.set_z(hit_pos, hit_pos.z + hit_offset_height)
		mvector3.set_z(hit_pos, hit_pos.z)
		local attack_dir, s_distance = nil
		if attack_dir then
			attack_dir = hit_pos - attacker_unit:movement():m_head_pos()
			s_distance = mvector3.normalize(attack_dir)
			--grabbing weapon damage
		else
			attack_dir = self._unit:rotation():y()
			s_distance = 1000 --arbitrary value to prevent it from not being set, then crashing in the shotgun_push function for being nil
			--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_explosion", "direction not found", ccolor)
		end
		
		if death and gensec_space_program.settings.other_players_launch == true then
			other_kill = false --supposed to be true, but since we can get the actual damage it's not needed

			--Attempt to get the base damage of the weapon used, if nil then default to the weakest explosive launcher, the Arbiter, for 480, or 48 internally.
			if attacker_unit and attacker_unit:inventory() and attacker_unit:inventory():equipped_unit() then --NX
				if attacker_unit:inventory():equipped_unit():base():weapon_tweak_data().stats ~= nil then 
					g_dmg = attacker_unit:inventory():equipped_unit():base():weapon_tweak_data().stats.damage or 48
				else
					--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_explosion", "(0)nil value, any crashers?", ccolor)
					g_dmg = 48
				end
			else
				--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_explosion", "(1)nil value, any crashers?", ccolor)
				g_dmg = 48
			end
			local attack_data = {
				variant = variant,
				attacker_unit = attacker_unit,
				weapon_unit = weapon_unit or attacker_unit and attacker_unit:inventory() and attacker_unit:inventory():equipped_unit()
			}
			--g_dmg = g_dmg * attacker_unit:inventory():equipped_unit():base():weapon_tweak_data().DAMAGE
			--g_dmg = damage_percent * self._HEALTH_INIT_PRECENT
			c_dmg = 1
			dmg_mul = 1
			ref_dmg = (gensec_space_program.settings.reference_damage / 10)
			managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, direction or attack_dir, s_distance, attacker_unit)
		end
	end)

	Hooks:PostHook(CopDamage, 'damage_melee', 'get_bonked', function(self,attack_data)
		if attack_data.result and not managers.groupai:state():whisper_mode() then
			if attack_data.result.type == "death" then
				local damage = managers.blackmarket:equipped_melee_weapon_damage_info(m_lerp)
				damage = damage * managers.player:get_melee_dmg_multiplier()
				g_dmg = damage
				cl_dir = attack_data.col_ray.ray
				local g_distance = mvector3.normalize(cl_dir)
				local hit_pos = mvector3.copy(self._unit:movement():m_pos())
				managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, cl_dir, g_distance, cl_attacker)
			end
		end
	end)

	Hooks:PostHook(CopDamage, 'sync_damage_melee', 'get_other_bonked', function(self, attacker_unit, damage_percent, damage_effect_percent, i_body, hit_offset_height, variant, death)
		if death then
			--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", Utils.ToString(attacker_unit), ccolor)
			local hit_pos = mvector3.copy(self._unit:movement():m_pos())
			mvector3.set_z(hit_pos, hit_pos.z + hit_offset_height)
			--mvector3.set_z(hit_pos, hit_pos.z)
			local attack_dir, s_distance = nil
			if attack_dir then
				attack_dir = hit_pos attacker_unit:movement():m_head_pos()
				s_distance = mvector3.normalize(attack_dir)
			else
				--attack_dir = -self._unit:rotation():y()
				attack_dir = hit_pos - attacker_unit:movement():m_head_pos()
				--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", Utils.ToString(attack_dir), ccolor)
				s_distance = 100 --arbitrary value to prevent it from not being set, then crashing in the shotgun_push function for being nil
			end
			
			if death and gensec_space_program.settings.other_players_launch == true then
				other_kill = false --supposed to be true, but since we can get the actual damage it's not needed
				--is_graze_kill = false
				if attacker_unit and attacker_unit:inventory() and attacker_unit:inventory():get_melee_weapon_id() then --NX
					--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", "inventory: " .. Utils.ToString(attacker_unit:inventory():get_melee_weapon_id()), ccolor)
					if tweak_data.blackmarket.melee_weapons[attacker_unit:inventory():get_melee_weapon_id()].stats ~= nil then 
						if gensec_space_program.settings.max_melee_toggle then
							g_dmg = (tweak_data.blackmarket.melee_weapons[attacker_unit:inventory():get_melee_weapon_id()].stats.max_damage / 10 ) or 16
						else
							g_dmg = (tweak_data.blackmarket.melee_weapons[attacker_unit:inventory():get_melee_weapon_id()].stats.min_damage / 10 ) or 7
						end
						--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", "melee info: " .. Utils.ToString(tweak_data.blackmarket.melee_weapons[attacker_unit:inventory():get_melee_weapon_id()].stats), ccolor)
					else
						--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", "(1)nil value, any crashers?", ccolor)
						g_dmg = 7
					end
				else
					--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", "(0)nil value, any crashers?", ccolor)
					g_dmg = 7
				end
				local attack_data = {
					variant = variant,
					attacker_unit = attacker_unit,
					weapon_unit = weapon_unit or attacker_unit and attacker_unit:inventory() and attacker_unit:inventory():get_melee_weapon_id()
				}
				--g_dmg = g_dmg * attacker_unit:inventory():equipped_unit():base():weapon_tweak_data().DAMAGE
				--g_dmg = damage_percent * self._HEALTH_INIT_PRECENT
				c_dmg = 1
				--ref_dmg = (gensec_space_program.settings.reference_damage / 10)
				other_melee = true
				--managers.chat:_receive_message(managers.chat.GAME, "sync_damage_melee", "g_dmg: " .. g_dmg, ccolor)
				managers.game_play_central:_do_shotgun_push(self._unit, hit_pos, attack_dir, s_distance, attacker_unit)
			end
		end
	end)
end

Hooks:PostHook(RaycastWeaponBase, '_get_current_damage', 'get_real_damage' , function(self, dmg_mul)
	g_dmg = self._damage * dmg_mul
	--g_dmg = self._damage
	--g_dmg_mul = dmg_mul
	other_kill = false
	--dmg_mul accounts for Overkill, Berserker, and Trigger Happy.
	--managers.chat:_receive_message(managers.chat.GAME, "_get_current_damage", "Firing for " .. g_dmg .." dmg_mul is ".. dmg_mul, ccolor)
end)

Hooks:PostHook(RaycastWeaponBase, 'should_shotgun_push', 'everyonepushes' , function(self)
		--Check if you're in stealth, if not then do the thing
		if not managers.groupai:state():whisper_mode() then
			--managers.chat:_receive_message(managers.chat.GAME, "Debug", "Pushit!", ccolor)
			return true
		end
			--In stealth, all guns behave as expected.
			return _do_shotgun_push
end)

Hooks:PreHook(PlayerStandard, '_do_melee_damage', 'get_real_melee_stuff', function(self, t, bayonet_melee, melee_hit_ray, melee_entry, hand_id)
	--This is needed to get the melee damage after taking into account charge melee. it's stored into m_lerp then passed to CopDamage:damage_melee to do the rest of the calculations
	melee_entry = melee_entry or managers.blackmarket:equipped_melee_weapon()
	local instant_hit = tweak_data.blackmarket.melee_weapons[melee_entry].instant
	local melee_damage_delay = tweak_data.blackmarket.melee_weapons[melee_entry].melee_damage_delay or 0
	local charge_lerp_value = instant_hit and 0 or self:_get_melee_charge_lerp_value(t, melee_damage_delay)
	m_lerp = charge_lerp_value
	--managers.chat:_receive_message(managers.chat.GAME, "_do_melee_damage", "b o n k for: " .. m_lerp, ccolor)
end)

if RequiredScript == "lib/managers/gameplaycentralmanager" then
	Hooks:PostHook(GamePlayCentralManager, 'get_shotgun_push_range', 'max_range', function(attacker)
		--Make the push universal.
		--Currently a toggle between 5 meters and 9 quadrillion meters, but maybe making a slider would be nice.
		if not managers.groupai:state():whisper_mode() and gensec_space_program.settings.infinite_launch_range == true then
			return 999999999999999
		end
	end)
	
	function GamePlayCentralManager:_do_shotgun_push(unit, hit_pos, dir, distance, attacker)
		cl_unit = unit
		cl_hp = hit_pos
		cl_dir = dir
		cl_distance = distance
		cl_attacker = attacker
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
			if other_melee == true then
				--This is the only way I could think of to get sync_melee kills to not turn cops into spaghetti
				scale = scale / 100
				--g_dmg = g_dmg / 100
				other_melee = false
			end
			scale = scale * math.max(1, (g_dmg / ref_dmg))
			--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "post scale: " .. scale, ccolor)
			--Multiplies by crits. c_dmg will be 1 if it didn't crit.
			scale = scale * c_dmg
			scale = scale * gensec_space_program.settings.launch_multiplier
		end
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "result: " .. (g_dmg / ref_dmg), ccolor)
		c_dmg = 1
		--there was something I was testing here
		--chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale post =  " .. scale , ccolor)
		local rot_time = 1 + math.rand(2)
		local asm = unit:anim_state_machine()
		
		--This is vanilla code that will nerf the effect on dozers and - to my knowledge - bosses like Yufu Wang, Gabriel, Sanchez, etc.
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
		--I've found just increasing this value of 600 to something higher gets results
		--What I did was band-aid solutions to make things scale with gun damage, however
		--You can also just buff everything with this if you want.
		--Update: Why would you do that you have the multiplier setting in-game I-
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
	  ["menu_gensec_space_program_max_melee_toggle"] = "Use Max Melee Damage for Other Players",
	  ["menu_gensec_space_program_max_melee_toggle_desc"] = "When calculating launch strength for *other players* melee kills, use the maximum damage of their respective melee weapon as oppossed to their minimum."
	  --["menu_gensec_space_program_crit_launch_multiplier_desc"] = "Choose if you want critical hits to amplify the launch further, and if so, by how much."
	})
  end)
  if not AutoMenuBuilder then
		dofile(ModPath .. "automenubuilder.lua") -- run the auto menu builder file to have access to its functions
  end
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
	max_melee_toggle = false,
	--crit_launch_multiplier = 1
  },
  values = {
    reference_damage = { 10, 10000, 0.01 }, -- number values make a slider with min, max and step value
	launch_multiplier = { 0.1, 5, 0.1 },
    --crit_launch_multiplier = { 0, 1, 0.01 }
  },
}
