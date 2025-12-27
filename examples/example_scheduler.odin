package main

import artifact "../src"
import "core:fmt"

// Components
Position :: struct {
	x, y: f32,
}

Velocity :: struct {
	vx, vy: f32,
}

@(private = "file")
Health :: struct {
	current, max: f32,
}

main :: proc() {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	artifact.world_register_component(&world, Position)
	artifact.world_register_component(&world, Velocity)
	artifact.world_register_component(&world, Health)

	artifact.entity_spawn(&world, Position{0, 0}, Velocity{1, 2}, Health{100, 100})
	artifact.entity_spawn(&world, Position{10, 10}, Velocity{-1, 1}, Health{50, 100})
	artifact.entity_spawn(&world, Position{5, 5}, Velocity{0.5, 0.5})

	sched := artifact.scheduler_create()
	defer artifact.scheduler_destroy(&sched)

	// Register systems in different phases
	// Pre_Update: Input handling, physics prep
	artifact.scheduler_add_system(&sched, "input", input_system, .Pre_Update)

	// Update: Main game logic
	physics_id := artifact.scheduler_add_system(&sched, "physics", physics_system, .Update)
	movement_id := artifact.scheduler_add_system(&sched, "movement", movement_system, .Update)
	health_id := artifact.scheduler_add_system(&sched, "health", health_system, .Update)

	// Post_Update: Cleanup, collision response
	artifact.scheduler_add_system(&sched, "bounds_check", bounds_check_system, .Post_Update)

	// Render: Drawing
	artifact.scheduler_add_system(&sched, "render", render_system, .Render)

	// Set up dependencies within the Update phase
	// Movement depends on physics (physics runs first)
	artifact.scheduler_add_dependency(&sched, movement_id, physics_id)
	// Health system runs independently (no dependencies)

	// Can also add dependencies by name
	artifact.scheduler_add_dependency_by_name(&sched, "bounds_check", "movement")

	fmt.println("=== Starting Game Loop ===\n")
	for frame in 0 ..< 3 {
		fmt.printf("--- Frame %d ---\n", frame)
		artifact.scheduler_run(&sched, &world)
		fmt.println()
	}

	// Example: Run only specific phases
	fmt.println("=== Running Only Update Phase ===\n")
	artifact.scheduler_run_phase(&sched, &world, .Update)

	// Example: Disable a system
	fmt.println("\n=== Disabling Physics System ===\n")
	artifact.scheduler_set_enabled(&sched, physics_id, false)
	artifact.scheduler_run(&sched, &world)

	artifact.scheduler_set_enabled(&sched, physics_id, true)

	fmt.printf("\nTotal systems: %d\n", artifact.scheduler_system_count(&sched))
	fmt.printf("Enabled systems: %d\n", artifact.scheduler_enabled_count(&sched))
}

input_system :: proc(world: ^artifact.World) {
	fmt.println("  [Pre_Update] Input system")
}

physics_system :: proc(world: ^artifact.World) {
	fmt.println("  [Update] Physics system")
	for arch in artifact.query(world, Velocity).archetypes {
		velocities := artifact.archetype_get_column(arch, Velocity)
		for i in 0 ..< arch.count {
			velocities[i].vy -= 0.1
		}
	}
}

movement_system :: proc(world: ^artifact.World) {
	fmt.println("  [Update] Movement system (depends on physics)")
	for arch in artifact.query(world, Position, Velocity).archetypes {
		positions := artifact.archetype_get_column(arch, Position)
		velocities := artifact.archetype_get_column(arch, Velocity)
		for i in 0 ..< arch.count {
			positions[i].x += velocities[i].vx
			positions[i].y += velocities[i].vy
		}
	}
}

health_system :: proc(world: ^artifact.World) {
	fmt.println("  [Update] Health system")
	for arch in artifact.query(world, Health).archetypes {
		healths := artifact.archetype_get_column(arch, Health)
		for i in 0 ..< arch.count {
			if healths[i].current < healths[i].max {
				healths[i].current += 1
			}
		}
	}
}

bounds_check_system :: proc(world: ^artifact.World) {
	fmt.println("  [Post_Update] Bounds check system")
	for arch in artifact.query(world, Position).archetypes {
		positions := artifact.archetype_get_column(arch, Position)
		for i in 0 ..< arch.count {
			positions[i].x = clamp(positions[i].x, -100, 100)
			positions[i].y = clamp(positions[i].y, -100, 100)
		}
	}
}

render_system :: proc(world: ^artifact.World) {
	fmt.println("  [Render] Render system")
	for arch in artifact.query(world, Position).archetypes {
		positions := artifact.archetype_get_column(arch, Position)
		for i in 0 ..< arch.count {
			fmt.printf("    Entity %d at (%.1f, %.1f)\n", i, positions[i].x, positions[i].y)
		}
	}
}
