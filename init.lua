local function get_step(itemstack)
	return tonumber(itemstack:get_meta():get("step")) or 0.1
end

local function show_formspec(itemstack, player)
	minetest.show_formspec(
		player:get_player_name(),
		"short_raycast:form",
		([[
		size[1,1]
		field[0.3,0.3;1,1;step;step;%.2f]
	]]):format(get_step(itemstack))
	)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "short_raycast:form" then
		return
	end
	local wielded_item = player:get_wielded_item()
	if wielded_item:get_name() ~= "short_raycast:caster" then
		return
	end
	local step = tonumber(fields.step)
	if (not step) or step <= 0 then
		return
	end
	local meta = wielded_item:get_meta()
	meta:set_float("step", step)
	player:set_wielded_item(wielded_item)
end)

local function multicast(start, stop, objects, liquids, step)
	local pos = start
	local delta = (stop - start):normalize() * step
	local function get_next_ray()
		local old_pos = pos
		pos = pos + delta
		if start:distance(pos) > start:distance(stop) then
			return
		end
		return Raycast(old_pos, pos, objects, liquids)
	end
	local ray = get_next_ray()
	return function()
		local pointed_thing
		while ray and not pointed_thing do
			pointed_thing = ray()
			if not pointed_thing then
				ray = get_next_ray()
			end
		end
		return pointed_thing
	end
end

minetest.register_tool("short_raycast:caster", {
	inventory_image = "short_raycast_tool.png",
	groups = { not_in_creative_inventory = 1 },
	on_place = show_formspec,
	on_secondary_use = show_formspec,
	on_use = function(itemstack, user, pointed_thing)
		if not minetest.is_player(user) then
			return
		end
		local look = user:get_look_dir()
		local eye_height = vector.new(0, user:get_properties().eye_height, 0)
		local eye_offset = user:get_eye_offset() * 0.1
		local yaw = user:get_look_horizontal()
		local start = user:get_pos() + eye_height + vector.rotate_around_axis(eye_offset, { x = 0, y = 1, z = 0 }, yaw)
		local step = get_step(itemstack)

		for pt in multicast(start, start + (100 * look), true, false, step) do
			if pt.type ~= "object" or pt.ref ~= user then
				futil.create_ephemeral_hud(user, 60, {
					hud_elem_type = "image_waypoint",
					text = "short_raycast_waypoint.png",
					scale = { x = -1 / 16 * 9, y = -1 },
					alignment = { x = 0, y = -1 },
					world_pos = pt.intersection_point,
				})
				break
			end
		end
	end,
})

minetest.register_entity("short_raycast:entity", {
	visual = "cube",
	collisionbox = { -0.7, -0.01, -0.7, 0.7, 2.69, 0.7 },
	visual_size = { x = 1.4, y = 2.7, z = 1.4 },
	textures = {
		"[combine:16x16^[noalpha^[colorize:#000:255",
		"[combine:16x16^[noalpha^[colorize:#000:255",
		"[combine:16x16^[noalpha^[colorize:#000:255",
		"[combine:16x16^[noalpha^[colorize:#000:255",
		"[combine:16x16^[noalpha^[colorize:#000:255",
		"[combine:16x16^[noalpha^[colorize:#000:255",
	},
})

minetest.register_chatcommand("short_raycast_entity", {
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return
		end
		minetest.add_entity(player:get_pos(), "short_raycast:entity")
	end,
})
