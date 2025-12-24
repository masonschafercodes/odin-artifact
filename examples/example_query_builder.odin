package main

import artifact "../src"
import "core:fmt"

Health :: distinct f32
Poison :: distinct f32
Shield :: distinct f32

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	register_components(&world)
	create_entities(&world)

	print_all_health_system(&world)
	print_healthy_system(&world)
	print_poisoned_system(&world)
	print_shielded_system(&world)
}

@(private = "file")
register_components :: proc(world: ^artifact.World) {
	artifact.world_register_component(world, Health)
	artifact.world_register_component(world, Poison)
	artifact.world_register_component(world, Shield)
}

@(private = "file")
create_entities :: proc(world: ^artifact.World) {
	artifact.entity_spawn(world, Health(100))
	artifact.entity_spawn(world, Health(80), Poison(5))
	artifact.entity_spawn(world, Health(120), Shield(50))
	artifact.entity_spawn(world, Health(60), Poison(10), Shield(25))
}

print_all_health_system :: proc(world: ^artifact.World) {
	fmt.println("=== All entities with Health ===")
	qb := artifact.query_builder(world)
	artifact.query_with(&qb, Health)
	for arch in artifact.query_execute(&qb).archetypes {
		health := artifact.archetype_get_column(arch, Health)
		for i in 0 ..< arch.count {
			fmt.printf("  Health = %.0f\n", health[i])
		}
	}
}

print_healthy_system :: proc(world: ^artifact.World) {
	fmt.println("=== Entities with Health but without Poison ===")
	qb := artifact.query_builder(world)
	artifact.query_with(&qb, Health)
	artifact.query_without(&qb, Poison)
	for arch in artifact.query_execute(&qb).archetypes {
		health := artifact.archetype_get_column(arch, Health)
		for i in 0 ..< arch.count {
			fmt.printf("  Health = %.0f\n", health[i])
		}
	}
}

print_poisoned_system :: proc(world: ^artifact.World) {
	fmt.println("=== Entities with Health and Poison ===")
	qb := artifact.query_builder(world)
	artifact.query_with(&qb, Health)
	artifact.query_with(&qb, Poison)
	for arch in artifact.query_execute(&qb).archetypes {
		health := artifact.archetype_get_column(arch, Health)
		poison := artifact.archetype_get_column(arch, Poison)
		for i in 0 ..< arch.count {
			fmt.printf("  Health = %.0f, Poison = %.0f\n", health[i], poison[i])
		}
	}
}

print_shielded_system :: proc(world: ^artifact.World) {
	fmt.println("=== Entities with Health and Shield, without Poison ===")
	qb := artifact.query_builder(world)
	artifact.query_with(&qb, Health)
	artifact.query_with(&qb, Shield)
	artifact.query_without(&qb, Poison)
	for arch in artifact.query_execute(&qb).archetypes {
		health := artifact.archetype_get_column(arch, Health)
		shield := artifact.archetype_get_column(arch, Shield)
		for i in 0 ..< arch.count {
			fmt.printf("  Health = %.0f, Shield = %.0f\n", health[i], shield[i])
		}
	}
}
