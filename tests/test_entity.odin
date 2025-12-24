package tests

import artifact "../src"
import "core:testing"

Test_Position :: distinct [3]f32
Test_Velocity :: distinct [3]f32
Test_Health :: struct {
	current: f32,
	max:     f32,
}

@(test)
test_entity_create_and_destroy :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entity, ok := artifact.entity_create(&world)
	testing.expect(t, ok, "Entity creation should succeed")
	testing.expect(
		t,
		artifact.entity_alive(&world, entity),
		"Newly created entity should be alive",
	)
	testing.expect(t, artifact.world_entity_count(&world) == 1, "World should have 1 entity")

	artifact.entity_destroy(&world, entity)
	testing.expect(
		t,
		!artifact.entity_alive(&world, entity),
		"Destroyed entity should not be alive",
	)
	testing.expect(t, artifact.world_entity_count(&world) == 0, "World should have 0 entities")
}

@(test)
test_entity_generation_increment :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entity1, _ := artifact.entity_create(&world)
	gen1 := artifact.entity_generation(entity1)

	artifact.entity_destroy(&world, entity1)

	entity2, _ := artifact.entity_create(&world)
	gen2 := artifact.entity_generation(entity2)

	testing.expect(t, gen2 > gen1, "Generation should increment after slot reuse")
	testing.expect(
		t,
		artifact.entity_index(entity1) == artifact.entity_index(entity2),
		"Should reuse same slot index",
	)
}

@(test)
test_stale_entity_handle :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})
	cached_handle := entity

	artifact.entity_destroy(&world, entity)

	testing.expect(
		t,
		!artifact.entity_alive(&world, cached_handle),
		"Stale handle should report not alive",
	)
	testing.expect(
		t,
		artifact.component_get(&world, cached_handle, Test_Position) == nil,
		"component_get on stale handle should return nil",
	)
}

@(test)
test_invalid_entity :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	testing.expect(
		t,
		!artifact.entity_alive(&world, artifact.INVALID_ENTITY),
		"INVALID_ENTITY should not be alive",
	)
	testing.expect(
		t,
		!artifact.entity_destroy(&world, artifact.INVALID_ENTITY),
		"Destroying INVALID_ENTITY should fail",
	)
}

@(test)
test_entity_pool_reuse :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entities: [100]artifact.Entity
	for i in 0 ..< 100 {
		entities[i], _ = artifact.entity_create(&world)
	}
	testing.expect(t, artifact.world_entity_count(&world) == 100, "Should have 100 entities")

	for i in 0 ..< 50 {
		artifact.entity_destroy(&world, entities[i])
	}
	testing.expect(t, artifact.world_entity_count(&world) == 50, "Should have 50 entities")

	for i in 0 ..< 50 {
		_, ok := artifact.entity_create(&world)
		testing.expect(t, ok, "Entity creation should succeed")
	}
	testing.expect(t, artifact.world_entity_count(&world) == 100, "Should have 100 entities again")
}
