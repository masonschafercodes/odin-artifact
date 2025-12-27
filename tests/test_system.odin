package tests

import artifact "../src"
import "core:testing"

@(test)
test_scheduler_basic :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	test_system :: proc(world: ^artifact.World) {}

	id := artifact.scheduler_add_system(&sched, "test_system", test_system)
	testing.expect(t, id != artifact.INVALID_SYSTEM, "System registration should succeed")
	testing.expect(t, artifact.scheduler_system_count(&sched) == 1, "Should have 1 system")
}

@(test)
test_scheduler_duplicate_name :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	test_system :: proc(world: ^artifact.World) {}

	id1 := artifact.scheduler_add_system(&sched, "test", test_system)
	id2 := artifact.scheduler_add_system(&sched, "test", test_system)

	testing.expect(t, id1 != artifact.INVALID_SYSTEM, "First registration should succeed")
	testing.expect(t, id2 == artifact.INVALID_SYSTEM, "Duplicate registration should fail")
	testing.expect(t, artifact.scheduler_system_count(&sched) == 1, "Should still have 1 system")
}

@(test)
test_scheduler_get_system :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	test_system :: proc(world: ^artifact.World) {}

	expected_id := artifact.scheduler_add_system(&sched, "my_system", test_system)

	found_id, ok := artifact.scheduler_get_system(&sched, "my_system")
	testing.expect(t, ok, "Should find system by name")
	testing.expect(t, found_id == expected_id, "Should return correct ID")

	_, not_found := artifact.scheduler_get_system(&sched, "nonexistent")
	testing.expect(t, !not_found, "Should not find nonexistent system")
}

@(test)
test_scheduler_phases_order :: proc(t: ^testing.T) {
	// Test that systems run and phase ordering works by modifying component data
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)

	// Create entity to track execution
	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// Each phase adds to x position, so we can verify order by checking final value
	pre_update :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 1 // x += 1
			}
		}
	}

	update :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 2 // x *= 2
			}
		}
	}

	post_update :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 10 // x += 10
			}
		}
	}

	render :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 3 // x *= 3
			}
		}
	}

	// Register in non-sequential order
	artifact.scheduler_add_system(&sched, "render", render, .Render)
	artifact.scheduler_add_system(&sched, "update", update, .Update)
	artifact.scheduler_add_system(&sched, "pre_update", pre_update, .Pre_Update)
	artifact.scheduler_add_system(&sched, "post_update", post_update, .Post_Update)

	ok := artifact.scheduler_run(&sched, &world)
	testing.expect(t, ok, "Scheduler run should succeed")

	// Execution order should be: pre_update, update, post_update, render
	// x starts at 0
	// pre_update: x = 0 + 1 = 1
	// update: x = 1 * 2 = 2
	// post_update: x = 2 + 10 = 12
	// render: x = 12 * 3 = 36
	pos := artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos != nil, "Should get position")
	if pos != nil {
		testing.expect(t, pos[0] == 36, "Position x should be 36 after all phases")
	}
}

@(test)
test_scheduler_dependencies :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	e, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// Dependency order: physics -> collision -> movement
	// Each multiplies by different value so order matters
	physics :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 2
			}
		}
	}

	collision :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 3
			}
		}
	}

	movement :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 5
			}
		}
	}

	// Register in reverse order to test dependency sorting
	movement_id := artifact.scheduler_add_system(&sched, "movement", movement)
	collision_id := artifact.scheduler_add_system(&sched, "collision", collision)
	physics_id := artifact.scheduler_add_system(&sched, "physics", physics)

	artifact.scheduler_add_dependency(&sched, collision_id, physics_id)
	artifact.scheduler_add_dependency(&sched, movement_id, collision_id)

	ok := artifact.scheduler_run(&sched, &world)
	testing.expect(t, ok, "Scheduler should succeed")

	// Order: physics, collision, movement
	// x = 1
	// physics: x = 1 * 2 = 2
	// collision: x = 2 + 3 = 5
	// movement: x = 5 * 5 = 25
	pos := artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos != nil, "Should get position")
	if pos != nil {
		testing.expect(
			t,
			pos[0] == 25,
			"Position x should be 25 after dependency-ordered execution",
		)
	}
}

@(test)
test_scheduler_cycle_detection :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	sys_a :: proc(world: ^artifact.World) {}
	sys_b :: proc(world: ^artifact.World) {}

	a := artifact.scheduler_add_system(&sched, "a", sys_a)
	b := artifact.scheduler_add_system(&sched, "b", sys_b)

	// Create cycle: a -> b -> a
	artifact.scheduler_add_dependency(&sched, a, b)
	artifact.scheduler_add_dependency(&sched, b, a)

	ok := artifact.scheduler_rebuild_order(&sched)
	testing.expect(t, !ok, "Cycle should be detected")
}

@(test)
test_scheduler_disabled_system :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// System increments x by 1 each run
	test_system :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 1
			}
		}
	}

	id := artifact.scheduler_add_system(&sched, "test", test_system)

	// First run - should execute (x becomes 1)
	artifact.scheduler_run(&sched, &world)
	pos := artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 1, "System should run once")

	// Disable and run again (x stays 1)
	artifact.scheduler_set_enabled(&sched, id, false)
	artifact.scheduler_run(&sched, &world)
	pos = artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 1, "Disabled system should not run")

	// Re-enable and run (x becomes 2)
	artifact.scheduler_set_enabled(&sched, id, true)
	artifact.scheduler_run(&sched, &world)
	pos = artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 2, "Re-enabled system should run")
}

@(test)
test_scheduler_run_phase :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	e, _ := artifact.entity_spawn(&world, Test_Position{0, 0, 0})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// Update adds 10, Render multiplies by 2
	update :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 10
			}
		}
	}

	render :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 2
			}
		}
	}

	artifact.scheduler_add_system(&sched, "update", update, .Update)
	artifact.scheduler_add_system(&sched, "render", render, .Render)

	// Only run Update phase (x = 0 + 10 = 10)
	artifact.scheduler_run_phase(&sched, &world, .Update)
	pos := artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 10, "Only update should run")

	// Run Render phase (x = 10 * 2 = 20)
	artifact.scheduler_run_phase(&sched, &world, .Render)
	pos = artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 20, "Render should also run now")
}

@(test)
test_scheduler_cross_phase_dependency :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	pre :: proc(world: ^artifact.World) {}
	update :: proc(world: ^artifact.World) {}

	pre_id := artifact.scheduler_add_system(&sched, "pre", pre, .Pre_Update)
	update_id := artifact.scheduler_add_system(&sched, "update", update, .Update)

	// Update can depend on Pre_Update (earlier phase) - should work
	ok1 := artifact.scheduler_add_dependency(&sched, update_id, pre_id)
	testing.expect(t, ok1, "Cross-phase dependency to earlier phase should work")

	// Pre_Update cannot depend on Update (later phase) - should fail
	ok2 := artifact.scheduler_add_dependency(&sched, pre_id, update_id)
	testing.expect(t, !ok2, "Cross-phase dependency to later phase should fail")
}

@(test)
test_scheduler_dependency_by_name :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Test_Position)
	e, _ := artifact.entity_spawn(&world, Test_Position{1, 0, 0})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// first multiplies by 2, second adds 10
	first :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] *= 2
			}
		}
	}

	second :: proc(w: ^artifact.World) {
		for arch in artifact.query(w, Test_Position).archetypes {
			positions := artifact.archetype_get_column(arch, Test_Position)
			for i in 0 ..< arch.count {
				positions[i][0] += 10
			}
		}
	}

	artifact.scheduler_add_system(&sched, "second", second)
	artifact.scheduler_add_system(&sched, "first", first)

	// Add dependency by name: second depends on first
	ok := artifact.scheduler_add_dependency_by_name(&sched, "second", "first")
	testing.expect(t, ok, "Dependency by name should succeed")

	artifact.scheduler_run(&sched, &world)

	// Order: first, second
	// x = 1 * 2 = 2, then x = 2 + 10 = 12
	pos := artifact.component_get(&world, e, Test_Position)
	testing.expect(t, pos[0] == 12, "First should run first, then second")
}

@(test)
test_scheduler_enabled_count :: proc(t: ^testing.T) {
	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	sys :: proc(world: ^artifact.World) {}

	id1 := artifact.scheduler_add_system(&sched, "sys1", sys)
	id2 := artifact.scheduler_add_system(&sched, "sys2", sys)
	artifact.scheduler_add_system(&sched, "sys3", sys)

	testing.expect(t, artifact.scheduler_enabled_count(&sched) == 3, "All 3 should be enabled")

	artifact.scheduler_set_enabled(&sched, id1, false)
	testing.expect(t, artifact.scheduler_enabled_count(&sched) == 2, "2 should be enabled")

	artifact.scheduler_set_enabled(&sched, id2, false)
	testing.expect(t, artifact.scheduler_enabled_count(&sched) == 1, "1 should be enabled")
}
