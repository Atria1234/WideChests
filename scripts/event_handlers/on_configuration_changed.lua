local function on_configuration_changed()
    local surface = game.get_surface(MergingChests.merge_surface_name)
    if not surface then
        surface = game.create_surface(MergingChests.merge_surface_name, {
            default_enable_all_autoplace_controls = false,
            property_expression_names = {
                cliffiness = 0
            },
            starting_area = "none"
        })
    else
        for _, force in pairs(game.forces) do
            force.set_surface_hidden(surface, true)
        end
    end
end

local function on_surface_created(event)
    local surface = game.get_surface(event.surface_index)
    if surface and surface.name == MergingChests.merge_surface_name then
        surface.generate_with_lab_tiles = true
        surface.peaceful_mode = true

        for _, force in pairs(game.forces) do
            force.chart(surface, {{-1, -1}, {1, 1}})
            force.set_surface_hidden(surface, true)
        end
    end
end

local function on_force_created(event)
    local surface = game.get_surface(MergingChests.merge_surface_name)
    if surface then
        event.force.chart(surface, {{-1, -1}, {1, 1}})
        event.force.set_surface_hidden(surface, true)
    end
end

script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_surface_created, on_surface_created)
script.on_event(defines.events.on_force_created, on_force_created)
