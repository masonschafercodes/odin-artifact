package tests

import artifact "../src"
import "core:testing"

@(test)
test_component_registration :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	idx, ok := artifact.world_register_component(&world, Test_Position)
	testing.expect(t, ok, "Registration should succeed")
	testing.expect(t, idx >= 0, "Index should be non-negative")

	idx2, ok2 := artifact.world_register_component(&world, Test_Position)
	testing.expect(t, ok2, "Re-registration should succeed")
	testing.expect(t, idx == idx2, "Re-registration should return same index")
}

@(test)
test_spawn_with_unregistered_component :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entity, ok := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	testing.expect(t, !ok, "Spawn with unregistered component should fail")
	testing.expect(
		t,
		entity == artifact.INVALID_ENTITY,
		"Failed spawn should return INVALID_ENTITY",
	)
}

@(test)
test_component_access :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	entity, ok := artifact.entity_spawn(&world, Test_Position{1, 2, 3}, Test_Velocity{4, 5, 6})
	testing.expect(t, ok, "Spawn should succeed")

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(t, pos != nil, "Should get Position component")
	if pos != nil {
		testing.expect(
			t,
			pos[0] == 1 && pos[1] == 2 && pos[2] == 3,
			"Position values should match",
		)
	}

	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Position),
		"component_has should return true for Position",
	)
	testing.expect(
		t,
		!artifact.component_has(&world, entity, Test_Health),
		"component_has should return false for missing Health",
	)
}

@(test)
test_component_set :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	entity, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	success := artifact.component_set(&world, entity, Test_Position{10, 20, 30})
	testing.expect(t, success, "component_set should succeed")

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(t, pos != nil && pos[0] == 10, "Position should be updated")
}

@(test)
test_component_set_missing :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	entity, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	success := artifact.component_set(&world, entity, Test_Velocity{1, 2, 3})
	testing.expect(t, !success, "component_set for missing component should fail")
}

@(test)
test_multiple_entities_same_archetype :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	e3, _ := artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	testing.expect(t, artifact.world_archetype_count(&world) == 1, "Should have 1 archetype")

	p1 := artifact.component_get(&world, e1, Test_Position)
	p2 := artifact.component_get(&world, e2, Test_Position)
	p3 := artifact.component_get(&world, e3, Test_Position)

	testing.expect(t, p1 != nil && p1[0] == 1, "e1 should have position 1")
	testing.expect(t, p2 != nil && p2[0] == 2, "e2 should have position 2")
	testing.expect(t, p3 != nil && p3[0] == 3, "e3 should have position 3")
}

@(test)
test_different_archetypes :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0}, Test_Velocity{0, 1, 0})
	e3, _ := artifact.entity_spawn(
		&world,
		Test_Position{3, 0, 0},
		Test_Velocity{0, 0, 1},
		Test_Health{100, 100},
	)

	testing.expect(t, artifact.world_archetype_count(&world) == 3, "Should have 3 archetypes")

	testing.expect(t, artifact.component_has(&world, e1, Test_Position), "e1 should have Position")
	testing.expect(
		t,
		!artifact.component_has(&world, e1, Test_Velocity),
		"e1 should not have Velocity",
	)

	testing.expect(t, artifact.component_has(&world, e2, Test_Position), "e2 should have Position")
	testing.expect(t, artifact.component_has(&world, e2, Test_Velocity), "e2 should have Velocity")
	testing.expect(
		t,
		!artifact.component_has(&world, e2, Test_Health),
		"e2 should not have Health",
	)

	testing.expect(t, artifact.component_has(&world, e3, Test_Position), "e3 should have Position")
	testing.expect(t, artifact.component_has(&world, e3, Test_Velocity), "e3 should have Velocity")
	testing.expect(t, artifact.component_has(&world, e3, Test_Health), "e3 should have Health")
}

// =============================================================================
// component_add / component_remove Tests
// =============================================================================

@(test)
test_component_add_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Position),
		"Should have Position",
	)
	testing.expect(
		t,
		!artifact.component_has(&world, entity, Test_Velocity),
		"Should not have Velocity yet",
	)

	ok := artifact.component_add(&world, entity, Test_Velocity{4, 5, 6})
	testing.expect(t, ok, "component_add should succeed")

	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Velocity),
		"Should now have Velocity",
	)

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(
		t,
		pos != nil && pos[0] == 1 && pos[1] == 2 && pos[2] == 3,
		"Position should be preserved after add",
	)

	vel := artifact.component_get(&world, entity, Test_Velocity)
	testing.expect(
		t,
		vel != nil && vel[0] == 4 && vel[1] == 5 && vel[2] == 6,
		"Velocity should have correct value",
	)
}

@(test)
test_component_add_already_has :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	ok := artifact.component_add(&world, entity, Test_Position{10, 20, 30})
	testing.expect(t, ok, "component_add for existing should succeed")

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(t, pos != nil && pos[0] == 10, "Should update existing component")
}

@(test)
test_component_add_unregistered :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	ok := artifact.component_add(&world, entity, Test_Velocity{1, 2, 3})
	testing.expect(t, !ok, "component_add for unregistered component should fail")
}

@(test)
test_component_remove_basic :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3}, Test_Velocity{4, 5, 6})

	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Velocity),
		"Should have Velocity",
	)

	ok := artifact.component_remove(&world, entity, Test_Velocity)
	testing.expect(t, ok, "component_remove should succeed")

	testing.expect(
		t,
		!artifact.component_has(&world, entity, Test_Velocity),
		"Should not have Velocity anymore",
	)

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(t, pos != nil && pos[0] == 1, "Position should be preserved")
}

@(test)
test_component_remove_nonexistent :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	ok := artifact.component_remove(&world, entity, Test_Velocity)
	testing.expect(t, !ok, "Removing nonexistent component should return false")
}

@(test)
test_component_remove_to_empty :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})

	ok := artifact.component_remove(&world, entity, Test_Position)
	testing.expect(t, ok, "Should be able to remove last component")

	testing.expect(
		t,
		artifact.entity_alive(&world, entity),
		"Entity should still be alive with no components",
	)
	testing.expect(
		t,
		!artifact.component_has(&world, entity, Test_Position),
		"Should no longer have Position",
	)
}

@(test)
test_archetype_transition_preserves_other_entities :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	e1, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})
	e2, _ := artifact.entity_spawn(&world, Test_Position{2, 0, 0})
	e3, _ := artifact.entity_spawn(&world, Test_Position{3, 0, 0})

	artifact.component_add(&world, e2, Test_Velocity{0, 1, 0})

	p1 := artifact.component_get(&world, e1, Test_Position)
	p3 := artifact.component_get(&world, e3, Test_Position)

	testing.expect(t, p1 != nil && p1[0] == 1, "e1 position should be preserved")
	testing.expect(t, p3 != nil && p3[0] == 3, "e3 position should be preserved")
}

@(test)
test_add_then_remove_returns_to_original :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)

	initial_arch_count := artifact.world_archetype_count(&world)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 2, 3})
	after_spawn_count := artifact.world_archetype_count(&world)

	artifact.component_add(&world, entity, Test_Velocity{4, 5, 6})
	after_add_count := artifact.world_archetype_count(&world)

	artifact.component_remove(&world, entity, Test_Velocity)
	after_remove_count := artifact.world_archetype_count(&world)

	testing.expect(t, after_remove_count == after_add_count, "No new archetypes created on remove")

	pos := artifact.component_get(&world, entity, Test_Position)
	testing.expect(
		t,
		pos != nil && pos[0] == 1 && pos[1] == 2 && pos[2] == 3,
		"Position preserved after add/remove cycle",
	)
}

@(test)
test_multiple_add_remove_cycles :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	artifact.world_register_component(&world, Test_Velocity)
	artifact.world_register_component(&world, Test_Health)

	entity, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})

	artifact.component_add(&world, entity, Test_Velocity{2, 0, 0})
	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Velocity),
		"Should have Velocity",
	)

	artifact.component_add(&world, entity, Test_Health{100, 100})
	testing.expect(t, artifact.component_has(&world, entity, Test_Health), "Should have Health")

	artifact.component_remove(&world, entity, Test_Velocity)
	testing.expect(
		t,
		!artifact.component_has(&world, entity, Test_Velocity),
		"Should not have Velocity",
	)
	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Health),
		"Should still have Health",
	)

	artifact.component_add(&world, entity, Test_Velocity{3, 0, 0})
	testing.expect(
		t,
		artifact.component_has(&world, entity, Test_Velocity),
		"Should have Velocity again",
	)

	pos := artifact.component_get(&world, entity, Test_Position)
	vel := artifact.component_get(&world, entity, Test_Velocity)
	hp := artifact.component_get(&world, entity, Test_Health)

	testing.expect(t, pos != nil && pos[0] == 1, "Position preserved")
	testing.expect(t, vel != nil && vel[0] == 3, "Velocity has new value")
	testing.expect(t, hp != nil && hp.current == 100, "Health preserved")
}
