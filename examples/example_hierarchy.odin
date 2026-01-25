package main

import artifact "../src"
import "core:fmt"

Transform :: struct {
	x, y: f32,
}

Name :: struct {
	value: string,
}

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Transform)
	artifact.world_register_component(&world, Name)

	demo_basic_hierarchy(&world)
	demo_reparenting(&world)
	demo_orphaning(&world)
}

demo_basic_hierarchy :: proc(world: ^artifact.World) {
	fmt.println("=== Basic Hierarchy ===")

	root, _ := artifact.entity_spawn(world, Name{"Root"}, Transform{0, 0})
	player, _ := artifact.entity_spawn(world, Name{"Player"}, Transform{10, 20})
	weapon, _ := artifact.entity_spawn(world, Name{"Weapon"}, Transform{1, 0})
	shield, _ := artifact.entity_spawn(world, Name{"Shield"}, Transform{-1, 0})

	artifact.entity_set_parent(world, player, root)
	artifact.entity_set_parent(world, weapon, player)
	artifact.entity_set_parent(world, shield, player)

	fmt.printf("Player's parent: %s\n", get_name(world, artifact.entity_get_parent(world, player)))
	fmt.printf("Player's children: %d\n", artifact.entity_child_count(world, player))

	fmt.println("Player's children:")
	for child in artifact.entity_get_children(world, player) {
		fmt.printf("  - %s\n", get_name(world, child))
	}

	fmt.printf("Player has parent: %v\n", artifact.entity_has_parent(world, player))
	fmt.printf("Player has children: %v\n", artifact.entity_has_children(world, player))
	fmt.printf("Root has parent: %v\n", artifact.entity_has_parent(world, root))

	artifact.entity_destroy(world, root)
	artifact.entity_destroy(world, player)
	artifact.entity_destroy(world, weapon)
	artifact.entity_destroy(world, shield)

	fmt.println()
}

demo_reparenting :: proc(world: ^artifact.World) {
	fmt.println("=== Reparenting ===")

	parent1, _ := artifact.entity_spawn(world, Name{"Parent1"}, Transform{0, 0})
	parent2, _ := artifact.entity_spawn(world, Name{"Parent2"}, Transform{100, 0})
	child, _ := artifact.entity_spawn(world, Name{"Child"}, Transform{5, 5})

	artifact.entity_set_parent(world, child, parent1)
	fmt.printf(
		"Child's initial parent: %s\n",
		get_name(world, artifact.entity_get_parent(world, child)),
	)
	fmt.printf("Parent1 children count: %d\n", artifact.entity_child_count(world, parent1))
	fmt.printf("Parent2 children count: %d\n", artifact.entity_child_count(world, parent2))

	artifact.entity_set_parent(world, child, parent2)
	fmt.println("\nAfter reparenting:")
	fmt.printf(
		"Child's new parent: %s\n",
		get_name(world, artifact.entity_get_parent(world, child)),
	)
	fmt.printf("Parent1 children count: %d\n", artifact.entity_child_count(world, parent1))
	fmt.printf("Parent2 children count: %d\n", artifact.entity_child_count(world, parent2))

	artifact.entity_set_parent(world, child, artifact.INVALID_ENTITY)
	fmt.println("\nAfter removing parent:")
	fmt.printf("Child has parent: %v\n", artifact.entity_has_parent(world, child))

	artifact.entity_destroy(world, parent1)
	artifact.entity_destroy(world, parent2)
	artifact.entity_destroy(world, child)

	fmt.println()
}

demo_orphaning :: proc(world: ^artifact.World) {
	fmt.println("=== Orphaning on Parent Destruction ===")

	parent, _ := artifact.entity_spawn(world, Name{"Parent"}, Transform{0, 0})
	child1, _ := artifact.entity_spawn(world, Name{"Child1"}, Transform{1, 0})
	child2, _ := artifact.entity_spawn(world, Name{"Child2"}, Transform{2, 0})

	artifact.entity_set_parent(world, child1, parent)
	artifact.entity_set_parent(world, child2, parent)

	fmt.printf(
		"Before destruction - Child1 has parent: %v\n",
		artifact.entity_has_parent(world, child1),
	)
	fmt.printf(
		"Before destruction - Child2 has parent: %v\n",
		artifact.entity_has_parent(world, child2),
	)

	artifact.entity_destroy(world, parent)

	fmt.println("\nAfter parent destruction:")
	fmt.printf("Child1 is alive: %v\n", artifact.entity_alive(world, child1))
	fmt.printf("Child2 is alive: %v\n", artifact.entity_alive(world, child2))
	fmt.printf("Child1 has parent: %v\n", artifact.entity_has_parent(world, child1))
	fmt.printf("Child2 has parent: %v\n", artifact.entity_has_parent(world, child2))

	artifact.entity_destroy(world, child1)
	artifact.entity_destroy(world, child2)

	fmt.println()
}

@(private = "file")
get_name :: proc(world: ^artifact.World, entity: artifact.Entity) -> string {
	if !artifact.entity_alive(world, entity) {
		return "<none>"
	}
	if name := artifact.component_get(world, entity, Name); name != nil {
		return name.value
	}
	return "<unnamed>"
}
