package tests

import artifact "../src"
import "core:testing"

@(test)
test_deferred_add :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	artifact.deferred_add(&world, e, Test_Velocity{1, 2, 3})

	testing.expect(
		t,
		!artifact.component_has(&world, e, Test_Velocity),
		"Should not have velocity yet",
	)

	artifact.world_flush(&world)

	testing.expect(
		t,
		artifact.component_has(&world, e, Test_Velocity),
		"Should have velocity after flush",
	)

	vel := artifact.component_get(&world, e, Test_Velocity)
	testing.expect(t, vel != nil, "Should be able to get velocity")
	testing.expect(t, vel[0] == 1 && vel[1] == 2 && vel[2] == 3, "Velocity values should match")
}

@(test)
test_deferred_destroy :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	artifact.deferred_destroy(&world, e)

	testing.expect(t, artifact.entity_alive(&world, e), "Should still be alive before flush")

	artifact.world_flush(&world)

	testing.expect(t, !artifact.entity_alive(&world, e), "Should be dead after flush")
}

@(test)
test_deferred_remove :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0}, Test_Velocity{1, 0, 0})

	artifact.deferred_remove(&world, e, Test_Velocity)

	testing.expect(
		t,
		artifact.component_has(&world, e, Test_Velocity),
		"Should have velocity before flush",
	)

	artifact.world_flush(&world)

	testing.expect(
		t,
		!artifact.component_has(&world, e, Test_Velocity),
		"Should not have velocity after flush",
	)
	testing.expect(
		t,
		artifact.component_has(&world, e, Test_Position),
		"Should still have position",
	)
}

@(test)
test_deferred_safe_iteration :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Health)

	for _ in 0 ..< 10 {
		artifact.entity_spawn(&world, Test_Position{0, 0, 0})
	}

	count := 0
	for arch in artifact.query(&world, Test_Position).archetypes {
		for i in 0 ..< arch.count {
			entity := arch.entities[i]
			artifact.deferred_add(&world, entity, Test_Health{100, 100})
			count += 1
		}
	}

	testing.expect(t, count == 10, "Should iterate all 10 entities")

	artifact.world_flush(&world)

	health_count := artifact.query_count(&world, Test_Position, Test_Health)
	testing.expect(t, health_count == 10, "All 10 should have health after flush")
}
