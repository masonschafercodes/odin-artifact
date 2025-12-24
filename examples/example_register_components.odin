package main

import artifact "../src"

@(private = "file")
Position :: distinct [3]f32

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	register_components(&world)
}

@(private = "file")
register_components :: proc(world: ^artifact.World) {
	artifact.world_register_component(world, Position)
}
