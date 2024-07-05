local function on_configuration_changed()
    if game.surfaces[MergingChests.merge_surface_name] then
        game.delete_surface(MergingChests.merge_surface_name)
    end

    local surface = game.create_surface(MergingChests.merge_surface_name, {
        default_enable_all_autoplace_controls = false,
        property_expression_names = {
            cliffiness = 0
        },
        starting_area = "none"
    })

    surface.generate_with_lab_tiles = true

    for _, force in pairs(game.forces) do
        force.chart(surface, {{-1, -1}, {1, 1}})
    end
end

local function on_force_created(event)
    event.force.chart(game.surfaces[MergingChests.merge_surface_name], {{-1, -1}, {1, 1}})
end

script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_force_created, on_force_created)
