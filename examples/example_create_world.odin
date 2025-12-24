package main

import artifact "../src"

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)
}
