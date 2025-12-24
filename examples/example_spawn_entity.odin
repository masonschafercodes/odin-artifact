package main

import artifact "../src"
import "core:math/rand"

EntityPosition :: distinct [2]f32
EntityColor :: distinct [4]u8

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	register_components(&world)
	create_entities(&world)
}

@(private = "file")
register_components :: proc(world: ^artifact.World) {
	artifact.world_register_component(world, EntityPosition)
	artifact.world_register_component(world, EntityColor)
}

@(private = "file")
create_entities :: proc(world: ^artifact.World) {
	x := rand.float32()
	y := rand.float32()

	r := u8(128 + rand.uint32() % 128)
	g := u8(128 + rand.uint32() % 128)
	b := u8(128 + rand.uint32() % 128)

	artifact.entity_spawn(world, EntityPosition{x, y}, EntityColor{r, g, b, 255})
}
