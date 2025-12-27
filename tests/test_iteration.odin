package tests

import artifact "../src"
import "core:testing"

@(test)
test_for_each_1_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	// Verify we can iterate and modify components
	artifact.for_each_1(
		&world,
		Test_Position,
		proc(entity: artifact.Entity, pos: ^Test_Position) {
			pos[0] *= 10 // Multiply x by 10
		},
	)

	// Verify modifications persisted
	result := artifact.query(&world, Test_Position)
	for arch in result.archetypes {
		positions := artifact.archetype_get_column(arch, Test_Position)
		for i in 0 ..< arch.count {
			testing.expect(t, positions[i][0] >= 10, "Position should have been modified")
		}
	}
}

@(test)
test_for_each_2_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{1, 2, 3})
	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{4, 5, 6})

	// Apply velocity to position
	artifact.for_each_2(
		&world,
		Test_Position,
		Test_Velocity,
		proc(entity: artifact.Entity, pos: ^Test_Position, vel: ^Test_Velocity) {
			pos[0] += vel[0]
			pos[1] += vel[1]
			pos[2] += vel[2]
		},
	)

	// Verify modifications
	result := artifact.query(&world, Test_Position, Test_Velocity)
	for arch in result.archetypes {
		positions := artifact.archetype_get_column(arch, Test_Position)
		velocities := artifact.archetype_get_column(arch, Test_Velocity)
		for i in 0 ..< arch.count {
			testing.expect(
				t,
				positions[i][0] == velocities[i][0],
				"Position x should equal velocity x after update",
			)
		}
	}
}

@(test)
test_for_each_3_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	artifact.entity_spawn(
		&world,
		Test_Position{0, 0, 0},
		Test_Velocity{1, 1, 1},
		Test_Health{100, 100},
	)

	// Iterate with all 3 components
	artifact.for_each_3(
		&world,
		Test_Position,
		Test_Velocity,
		Test_Health,
		proc(
			entity: artifact.Entity,
			pos: ^Test_Position,
			vel: ^Test_Velocity,
			health: ^Test_Health,
		) {
			pos[0] = health.current // Set x to current health
		},
	)

	// Verify
	result := artifact.query(&world, Test_Position, Test_Velocity, Test_Health)
	for arch in result.archetypes {
		positions := artifact.archetype_get_column(arch, Test_Position)
		for i in 0 ..< arch.count {
			testing.expect(t, positions[i][0] == 100, "Position x should equal health")
		}
	}
}

@(test)
test_for_each_only_matches_complete_archetypes :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	// Entity with only Position
	artifact.entity_spawn(&world, Test_Position{100, 0, 0})
	// Entity with both Position and Velocity
	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{5, 0, 0})

	// for_each_2 should only iterate the entity with both components
	artifact.for_each_2(
		&world,
		Test_Position,
		Test_Velocity,
		proc(entity: artifact.Entity, pos: ^Test_Position, vel: ^Test_Velocity) {
			pos[0] = 999 // Mark as visited
		},
	)

	// Check that position-only entity wasn't touched
	result_pos_only := artifact.query(&world, Test_Position)
	found_100 := false
	found_999 := false
	for arch in result_pos_only.archetypes {
		positions := artifact.archetype_get_column(arch, Test_Position)
		for i in 0 ..< arch.count {
			if positions[i][0] == 100 {
				found_100 = true
			}
			if positions[i][0] == 999 {
				found_999 = true
			}
		}
	}
	testing.expect(t, found_100, "Position-only entity should be unchanged")
	testing.expect(t, found_999, "Position+Velocity entity should be marked")
}

@(test)
test_query_count :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	artifact.entity_spawn(&world, Test_Position{3, 0, 0}, Test_Velocity{0, 0, 0})

	pos_count := artifact.query_count(&world, Test_Position)
	testing.expect(t, pos_count == 3, "Should count 3 entities with Position")

	vel_count := artifact.query_count(&world, Test_Velocity)
	testing.expect(t, vel_count == 1, "Should count 1 entity with Velocity")

	both_count := artifact.query_count(&world, Test_Position, Test_Velocity)
	testing.expect(t, both_count == 1, "Should count 1 entity with both")
}
