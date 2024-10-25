--- @alias chest_merged_event { player_index: number, surface: LuaSurface, split_chests: LuaEntity[], merged_chest: LuaEntity }

--- @param entity LuaEntity
--- @return integer
local function non_blank_inventory_slots_count(entity)
	local count = 0
	local inventory = entity.get_inventory(defines.inventory.chest)
	if inventory then
		for i = 1, #inventory do
			if inventory[i].valid_for_read then
				count = count + 1
			end
		end
	end

	return count
end

--- @param from_entities LuaEntity[]
--- @param to_entity_name string
--- @param to_entity_count integer
--- @return boolean
function MergingChests.can_move_inventories(from_entities, to_entity_name, to_entity_count)
	local from_item_count = 0
	for _, from_entity in ipairs(from_entities) do
		from_item_count = from_item_count + non_blank_inventory_slots_count(from_entity)
	end

	local to_inventory_size = prototypes.entity[to_entity_name].get_inventory_size(defines.inventory.chest) or 0

	local is_merged_chest, _, _ = MergingChests.get_merged_chest_info(to_entity_name)

	return from_item_count <= (is_merged_chest and MergingChests.get_inventory_size(to_inventory_size, to_entity_count, to_entity_name) or to_inventory_size * to_entity_count)
end

--- @param from_entities LuaEntity[]
--- @param to_entities LuaEntity[]
function MergingChests.move_inventories(from_entities, to_entities)
	local to_entity_index = 1
	local to_inventory_index = 1

	for _, from_entity in ipairs(from_entities) do
		local from_inventory = from_entity.get_inventory(defines.inventory.chest)
		if from_inventory then
			for i = 1, #from_inventory do
				local item = from_inventory[i]
				if item.valid_for_read then
					local to_inventory = to_entities[to_entity_index].get_inventory(defines.inventory.chest)
					if to_inventory then
						to_inventory[to_inventory_index].set_stack(item)
						to_inventory_index = to_inventory_index + 1

						if to_inventory_index > #to_inventory then
							to_entity_index = to_entity_index + 1
							to_inventory_index = 1
						end
					end
				end
			end
		end
	end
end

---@param entity LuaEntity
---@return integer | nil
local function get_entity_bar(entity)
	local inventory = entity.get_inventory(defines.inventory.chest)
	if inventory and inventory.supports_bar() then
		return inventory.get_bar() - 1
	end
	return nil
end

--- @param entities LuaEntity[]
--- @param is_ghost boolean
--- @return integer
function MergingChests.get_total_bar(entities, is_ghost)
	local bar_count = 0
	for _, entity in ipairs(entities) do
		local bar = (is_ghost and entity.ghost_prototype or entity.prototype).get_inventory_size(defines.inventory.chest) or 0
		if is_ghost then
			local clone = entity.clone({ position = {0, 0}, surface = game.surfaces[MergingChests.merge_surface_name] })
			if clone then
				local _, revived_entity = clone.silent_revive({ raise_revive = false })
				if revived_entity then
					bar = get_entity_bar(revived_entity) or bar
					revived_entity.destroy({ raise_destroy = false })
				else
					error('Can\'t revive ghost for getting its bar')
				end
			else
				error('Can\'t clone ghost for getting its bar')
			end
		else
			bar = get_entity_bar(entity) or bar
		end
		bar_count = bar_count + bar
	end

	return bar_count
end

--- @param from_entities LuaEntity[]
--- @param to_entities LuaEntity[]
function MergingChests.reconnect_circuits(from_entities, to_entities)
	local from_entities_set = { }
	for _, from_entity in ipairs(from_entities) do
		from_entities_set[from_entity] = from_entity
	end

	local outside_connectors = { }
	for _, from_entity in ipairs(from_entities) do
		for _, connector in ipairs(from_entity.get_wire_connectors(false)) do
			for _, connection in ipairs(connector.connections) do
				if not from_entities_set[connection.target.owner] then
					outside_connectors[connector.wire_connector_id] = outside_connectors[connector.wire_connector_id] or {}
					outside_connectors[connector.wire_connector_id][connection.target.owner.unit_number..'/'..connection.target.wire_connector_id] = connection.target
				end
			end
		end
	end

	if next(outside_connectors) ~= nil then
		local red = outside_connectors[defines.wire_connector_id.circuit_red] ~= nil
		local green = outside_connectors[defines.wire_connector_id.circuit_green] ~= nil

		local grid = MergingChests.entities_to_grid(to_entities)
		for x = grid.min_x, grid.max_x do
			for y = grid.min_y, grid.max_y do
				if red then
					if x + 1 <= grid.max_x then
						grid[x][y].get_wire_connector(defines.wire_connector_id.circuit_red, true)
							.connect_to(grid[x + 1][y].get_wire_connector(defines.wire_connector_id.circuit_red, true))
					end
					if y + 1 <= grid.max_y then
						grid[x][y].get_wire_connector(defines.wire_connector_id.circuit_red, true)
							.connect_to(grid[x][y + 1].get_wire_connector(defines.wire_connector_id.circuit_red, true))
					end
				end

				if green then
					if x + 1 <= grid.max_x then
						grid[x][y].get_wire_connector(defines.wire_connector_id.circuit_green, true)
							.connect_to(grid[x + 1][y].get_wire_connector(defines.wire_connector_id.circuit_green, true))
					end
					if y + 1 <= grid.max_y then
						grid[x][y].get_wire_connector(defines.wire_connector_id.circuit_green, true)
							.connect_to(grid[x][y + 1].get_wire_connector(defines.wire_connector_id.circuit_green, true))
					end
				end
			end
		end

		for wire_connector_id, connectors in pairs(outside_connectors) do
			for _, connector in pairs(connectors) do
				local closest_entity = nil
				local min = nil

				for _, to_entity in ipairs(to_entities) do
					local diffX = to_entity.position.x - connector.owner.position.x
					local diffY = to_entity.position.y - connector.owner.position.y

					if not min or (diffX * diffX + diffY * diffY < min) then
						min = diffX * diffX + diffY * diffY
						closest_entity = to_entity
					end
				end

				if closest_entity then
					closest_entity.get_wire_connector(wire_connector_id, true).connect_to(connector)
				end
			end
		end
	end
end

MergingChests.on_chest_merged_event_name = script.generate_event_name()
MergingChests.on_chest_split_event_name = script.generate_event_name()

local function get_chest_merged_event_name()
	return MergingChests.on_chest_merged_event_name
end

local function get_chest_split_event_name()
	return MergingChests.on_chest_split_event_name
end

remote.add_interface('MergingChests', {
	get_chest_merged_event_name = get_chest_merged_event_name,
	get_chest_split_event_name = get_chest_split_event_name
})
