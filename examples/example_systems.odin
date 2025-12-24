package main

import artifact "../src"
import "core:fmt"
import "core:math/rand"
import "core:time"

EntityRandomNumber :: distinct f32
ENTITY_COUNT :: 10

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	register_components(&world)
	create_entities(&world, ENTITY_COUNT)

	for {
		random_number_update_system(&world)
		random_number_print_system(&world)
		time.sleep(time.Second)
	}
}

@(private = "file")
register_components :: proc(world: ^artifact.World) {
	artifact.world_register_component(world, EntityRandomNumber)
}

@(private = "file")
create_entities :: proc(world: ^artifact.World, count: int) {
	for i in 0 ..< count {
		x := rand.float32()
		artifact.entity_spawn(world, EntityRandomNumber(x))
	}
}

random_number_update_system :: proc(world: ^artifact.World) {
	for arch in artifact.query(world, EntityRandomNumber).archetypes {
		random_numbers := artifact.archetype_get_column(arch, EntityRandomNumber)

		for i in 0 ..< arch.count {
			x := rand.float32()
			random_numbers[i] = EntityRandomNumber(x)
		}
	}
}

random_number_print_system :: proc(world: ^artifact.World) {
	for arch in artifact.query(world, EntityRandomNumber).archetypes {
		random_numbers := artifact.archetype_get_column(arch, EntityRandomNumber)
		for i in 0 ..< arch.count {
			fmt.printf("Entity %d: %f\n", i, random_numbers[i])
		}
	}
}
