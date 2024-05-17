--TO DO LIST
-- Get override to play nicely - No errors! | DONE
-- Look into extracting crits | DONE
-- Look into body expertise and/or headshot damage | No BE, but clamp to Judge is fine
-- Look into explosive damage being amplified
-- Make shotgun push range an option | DONE
local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
local tmp_vec3 = Vector3()
local tmp_vec4 = Vector3() --the one vector from GamePlayCentralManager that I can't declare on runtime easily.
--local c_dmg
local ccolor = Color(255, 0, 170, 255) / 255
--local g_dmg = 1
--local ref_dmg = 15.5 --Base damage of the Judge shotgun, which is our par damage
--Yes, everything's divided by 10 I don't know either
--local push = Vector3()


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

Hooks:PreHook(RaycastWeaponBase, '_get_current_damage', 'get_real_damage' , function(self, dmg_mul)
	g_dmg = self._damage * dmg_mul
	--dmg_mul accounts for Trigger Happy, Overkill, and Berserker.
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
		local mov_ext = unit:movement()
		local full_body_action = mov_ext and mov_ext:get_action(1)
	
		if full_body_action and full_body_action:type() == "hurt" then
			full_body_action:force_ragdoll(true)
		end
	
	
		local scale = math.clamp(1 - distance / math.min(self:get_shotgun_push_range(attacker), 500), 0.5, 1)
		
		--Magic happens here. If your gun's damage is higher than the Judge, calculate the ratio and multiply the vector's scalar by it.
		--If not, then it's a Judge (or whatever damage the user specified).
		if not managers.groupai:state():whisper_mode() then
			ref_dmg = gensec_space_program.settings.reference_damage / 10
			--Multiplies by crits. Will be 1 if it didn't crit.
			scale = scale * c_dmg
			--if c_dmg > 1 then
			--	scale = scale * (1 + (c_dmg * gensec_space_program.settings.crit_launch_multiplier))
			--end
			scale = scale * math.max(1, (g_dmg / ref_dmg))
			scale = scale * gensec_space_program.settings.launch_multiplier
			--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "crit mul  " .. (1 + (gensec_space_program.settings.crit_launch_multiplier / 10)) , ccolor)
		end
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale pre =  " .. scale , ccolor)
		
		
		--managers.chat:_receive_message(managers.chat.GAME, "_do_shotgun_push", "scale post =  " .. scale , ccolor)
		local rot_time = 1 + math.rand(2)
		local asm = unit:anim_state_machine()
		
		--This is vanilla code will nerf the effect on dozers and - to my knowledge - bosses like Yufu Wang and Gabriel.
		--Might make an option to disable this, or if you're reading this and want to buff
		--dozer pushes for some reason, the entire if statement is safe to delete or comment out.
		--Might make this a toggle later.
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
	  ["menu_gensec_space_program_crit_launch_toggle_desc"] = "Determines whether or not critical hits will amplify the strength of the launch, according to the enemy's respective damage multiplier."
	  --["menu_gensec_space_program_crit_launch_multiplier_desc"] = "Choose if you want critical hits to amplify the launch further, and if so, by how much."
	})
  end)

dofile(ModPath .. "automenubuilder.lua") -- run the auto menu builder file to have access to its functions

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusgensec_space_program", function(menu_manager, nodes)

	-- loads previously saved settings for that mod into the given table
	AutoMenuBuilder:load_settings(gensec_space_program.settings, "gensec_space_program")
	ref_dmg_IDENTIFIER_OPTION_desc = "test"
	-- automatically creates a mod options menu from a table containing key/value pairs
	-- the type of menu element created from a value in the table is determined by the value type
	-- localization ids are generated in the style: menu_IDENTIFIER_OPTION and menu_IDENTIFIER_OPTION_desc
	-- example for this mod: menu_gensec_space_program_slider, menu_gensec_space_program_slider_desc, menu_gensec_space_program_inherited_1, ...
	-- if no localization is available for an option name it is auto generated from the option name
	AutoMenuBuilder:create_menu_from_table(nodes, gensec_space_program.settings, "gensec_space_program", "blt_options", gensec_space_program.values --[[ optional ]], gensec_space_program.order --[[ optional ]])
  
  end)

gensec_space_program = gensec_space_program or {
  settings = {
    buff_dozer_launches = false, 
    reference_damage = 162.80, 
    launch_multiplier = 1, 
	infinite_launch_range = false,
	crit_launch_toggle = true 
	--crit_launch_multiplier = 1
  },
  values = {
    reference_damage = { 10, 10000, 0.01 }, -- number values make a slider with min, max and step value
	launch_multiplier = { 0.1, 5, 0.1 },
    --crit_launch_multiplier = { 0, 1, 0.01 }
  },
}
