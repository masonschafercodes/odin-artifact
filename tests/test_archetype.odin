package tests

import artifact "../src"
import "core:testing"

@(test)
test_swap_and_pop_consistency :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	entities: [5]artifact.Entity
	for i in 0 ..< 5 {
		entities[i], _ = artifact.entity_spawn(&world, Test_Position{f32(i), 0, 0})
	}

	artifact.entity_destroy(&world, entities[2])

	for i in 0 ..< 5 {
		if i == 2 do continue

		pos := artifact.component_get(&world, entities[i], Test_Position)
		testing.expect(t, pos != nil, "Remaining entity should have position")
		if pos != nil {
			testing.expectf(
				t,
				pos[0] == f32(i),
				"Position value should be preserved after swap-and-pop, got %v expected %v",
				pos[0],
				f32(i),
			)
		}
	}
}

@(test)
test_destroy_first_entity :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	e3, _ := artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	artifact.entity_destroy(&world, e1)

	p2 := artifact.component_get(&world, e2, Test_Position)
	p3 := artifact.component_get(&world, e3, Test_Position)

	testing.expect(t, p2 != nil && p2[0] == 2, "e2 position should be preserved")
	testing.expect(t, p3 != nil && p3[0] == 3, "e3 position should be preserved")
}

@(test)
test_destroy_last_entity :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	e3, _ := artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	artifact.entity_destroy(&world, e3)

	p1 := artifact.component_get(&world, e1, Test_Position)
	p2 := artifact.component_get(&world, e2, Test_Position)

	testing.expect(t, p1 != nil && p1[0] == 1, "e1 position should be preserved")
	testing.expect(t, p2 != nil && p2[0] == 2, "e2 position should be preserved")
}

@(test)
test_query_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0}) // Only position
	artifact.entity_spawn(&world, Test_Position{2, 0, 0}, Test_Velocity{1, 0, 0}) // Both
	artifact.entity_spawn(&world, Test_Position{3, 0, 0}, Test_Velocity{2, 0, 0}) // Both

	query := artifact.query(&world, Test_Position, Test_Velocity)

	total := 0
	for arch in query.archetypes {
		total += arch.count
	}

	testing.expect(t, total == 2, "Query should find 2 entities with Position and Velocity")
}

@(test)
test_archetype_column_access :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	artifact.entity_spawn(&world, Test_Position{1, 2, 3})
	artifact.entity_spawn(&world, Test_Position{4, 5, 6})
	artifact.entity_spawn(&world, Test_Position{7, 8, 9})

	arch := artifact.world_get_archetype(&world, Test_Position)
	testing.expect(t, arch != nil, "Should get archetype")

	if arch != nil {
		positions := artifact.archetype_get_column(arch, Test_Position)
		testing.expect(t, len(positions) == 3, "Should have 3 positions")
		if len(positions) >= 3 {
			testing.expect(t, positions[0][0] == 1, "First position x should be 1")
			testing.expect(t, positions[1][0] == 4, "Second position x should be 4")
			testing.expect(t, positions[2][0] == 7, "Third position x should be 7")
		}
	}
}

@(test)
test_destroy_all_in_archetype :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	e3, _ := artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	artifact.entity_destroy(&world, e1)
	artifact.entity_destroy(&world, e2)
	artifact.entity_destroy(&world, e3)

	testing.expect(t, artifact.world_entity_count(&world) == 0, "Should have 0 entities")

	e4, ok := artifact.entity_spawn(&world, Test_Position{4, 0, 0})
	testing.expect(t, ok, "Should be able to spawn after destroying all")
	testing.expect(t, artifact.entity_alive(&world, e4), "New entity should be alive")
}
