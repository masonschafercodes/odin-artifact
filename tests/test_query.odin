package tests

import artifact "../src"
import "core:testing"

@(test)
test_query_cache_hit :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{1, 0, 0})

	r1 := artifact.query(&world, Test_Position, Test_Velocity)
	testing.expect(t, len(r1.archetypes) == 1, "Should find 1 archetype")

	r2 := artifact.query(&world, Test_Position, Test_Velocity)
	testing.expect(t, len(r2.archetypes) == 1, "Should still find 1 archetype")

	testing.expect(
		t,
		raw_data(r1.archetypes) == raw_data(r2.archetypes),
		"Cache hit should return same backing array",
	)
}

@(test)
test_query_cache_invalidation :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	r1 := artifact.query(&world, Test_Position)
	ptr1 := raw_data(r1.archetypes)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Health{100, 100})

	r2 := artifact.query(&world, Test_Position)
	ptr2 := raw_data(r2.archetypes)

	testing.expect(t, ptr1 != ptr2, "Cache should be invalidated after new archetype")
	testing.expect(t, len(r2.archetypes) == 2, "Should now find 2 archetypes")
}

@(test)
test_query_cache_multiple_queries :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0})
	artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{1, 0, 0})

	r_pos := artifact.query(&world, Test_Position)
	r_both := artifact.query(&world, Test_Position, Test_Velocity)

	testing.expect(t, len(r_pos.archetypes) == 2, "Position query should find 2 archetypes")
	testing.expect(t, len(r_both.archetypes) == 1, "Both query should find 1 archetype")

	testing.expect(
		t,
		artifact.world_query_cache_count(&world) == 2,
		"Should have 2 cached queries",
	)
}

@(test)
test_query_cache_survives_entity_spawn :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	r1 := artifact.query(&world, Test_Position)
	ptr1 := raw_data(r1.archetypes)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0})

	r2 := artifact.query(&world, Test_Position)
	ptr2 := raw_data(r2.archetypes)

	testing.expect(t, ptr1 == ptr2, "Cache should survive spawns to existing archetype")
}

@(test)
test_query_cache_invalidation_on_component_add :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	r1 := artifact.query(&world, Test_Position)
	ptr1 := raw_data(r1.archetypes)

	artifact.component_add(&world, e, Test_Velocity{1, 0, 0})

	r2 := artifact.query(&world, Test_Position)
	ptr2 := raw_data(r2.archetypes)

	testing.expect(
		t,
		ptr1 != ptr2,
		"Cache should be invalidated after component_add creates new archetype",
	)
}

@(test)
test_build_mask_consistency :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	mask1 := artifact.build_mask(&world, Test_Position, Test_Velocity)
	mask2 := artifact.build_mask(&world, Test_Velocity, Test_Position)

	testing.expect(t, mask1 == mask2, "build_mask should be order-independent")
}

// =============================================================================
// Query Builder / Exclusion Tests
// =============================================================================

@(test)
test_query_builder_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0}, Test_Velocity{0, 1, 0})

	qb := artifact.query_builder(&world)
	artifact.query_with(&qb, Test_Position)
	artifact.query_with(&qb, Test_Velocity)
	result := artifact.query_execute(&qb)

	testing.expect(t, len(result.archetypes) == 1, "Builder query should find 1 archetype")
}

@(test)
test_query_exclusion :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0}, Test_Velocity{0, 1, 0})
	artifact.entity_spawn(&world, Test_Position{3, 0, 0}, Test_Health{100, 100})

	qb := artifact.query_builder(&world)
	artifact.query_with(&qb, Test_Position)
	artifact.query_without(&qb, Test_Velocity)
	result := artifact.query_execute(&qb)

	testing.expect(t, len(result.archetypes) == 2, "Should find 2 archetypes without Velocity")

	total := 0
	for arch in result.archetypes {
		total += arch.count
	}
	testing.expect(t, total == 2, "Should find 2 entities without Velocity")
}

@(test)
test_query_exclusion_multiple :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0}, Test_Velocity{0, 1, 0})
	artifact.entity_spawn(&world, Test_Position{3, 0, 0}, Test_Health{100, 100})
	artifact.entity_spawn(
		&world,
		Test_Position{4, 0, 0},
		Test_Velocity{1, 0, 0},
		Test_Health{50, 100},
	)

	qb := artifact.query_builder(&world)
	artifact.query_with(&qb, Test_Position)
	artifact.query_without(&qb, Test_Velocity)
	artifact.query_without(&qb, Test_Health)
	result := artifact.query_execute(&qb)

	testing.expect(t, len(result.archetypes) == 1, "Should find 1 archetype")

	total := 0
	for arch in result.archetypes {
		total += arch.count
	}
	testing.expect(t, total == 1, "Should find 1 entity with Position only")
}

@(test)
test_query_exclusion_cached :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	artifact.entity_spawn(&world, Test_Position{2, 0, 0}, Test_Velocity{0, 1, 0})

	qb1 := artifact.query_builder(&world)
	artifact.query_with(&qb1, Test_Position)
	artifact.query_without(&qb1, Test_Velocity)
	r1 := artifact.query_execute(&qb1)

	qb2 := artifact.query_builder(&world)
	artifact.query_with(&qb2, Test_Position)
	artifact.query_without(&qb2, Test_Velocity)
	r2 := artifact.query_execute(&qb2)

	testing.expect(
		t,
		raw_data(r1.archetypes) == raw_data(r2.archetypes),
		"Exclusion queries should be cached",
	)
}
