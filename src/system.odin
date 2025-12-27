package artifact

import "core:mem"

// System phases for grouping execution order
System_Phase :: enum {
	Pre_Update,
	Update,
	Post_Update,
	Render,
}

System_Proc :: #type proc(world: ^World)
System_Id :: distinct u32
INVALID_SYSTEM :: System_Id(0xFFFFFFFF)

// System registration data
System :: struct {
	id:           System_Id,
	name:         string,
	phase:        System_Phase,
	proc_ptr:     System_Proc,
	dependencies: [dynamic]System_Id, // Systems this one depends on (must run first)
	enabled:      bool,
}

// Scheduler manages system registration and execution order
Scheduler :: struct {
	systems:         [dynamic]System,
	systems_by_name: map[string]System_Id,
	execution_order: [dynamic]System_Id, // Topologically sorted
	order_dirty:     bool,
	phase_ranges:    [System_Phase][2]int, // [start, end) indices in execution_order
	allocator:       mem.Allocator,
}

// Create a new scheduler
scheduler_create :: proc(allocator := context.allocator) -> Scheduler {
	return Scheduler {
		systems = make([dynamic]System, allocator),
		systems_by_name = make(map[string]System_Id, allocator = allocator),
		execution_order = make([dynamic]System_Id, allocator),
		order_dirty = false,
		allocator = allocator,
	}
}

// Destroy a scheduler and free resources
scheduler_destroy :: proc(sched: ^Scheduler) {
	for &sys in sched.systems {
		delete(sys.dependencies)
	}
	delete(sched.systems)
	delete(sched.systems_by_name)
	delete(sched.execution_order)
}

// Register a new system
scheduler_add_system :: proc(
	sched: ^Scheduler,
	name: string,
	system_proc: System_Proc,
	phase: System_Phase = .Update,
) -> System_Id {
	if _, exists := sched.systems_by_name[name]; exists {
		return INVALID_SYSTEM // Already registered
	}

	id := System_Id(len(sched.systems))

	sys := System {
		id           = id,
		name         = name,
		phase        = phase,
		proc_ptr     = system_proc,
		dependencies = make([dynamic]System_Id, sched.allocator),
		enabled      = true,
	}

	append(&sched.systems, sys)
	sched.systems_by_name[name] = id
	sched.order_dirty = true

	return id
}

// Get system ID by name
scheduler_get_system :: proc(sched: ^Scheduler, name: string) -> (System_Id, bool) {
	id, ok := sched.systems_by_name[name]
	return id, ok
}

// Add dependency: `system` depends on `dependency` (dependency runs first)
scheduler_add_dependency :: proc(
	sched: ^Scheduler,
	system: System_Id,
	dependency: System_Id,
) -> bool {
	if int(system) >= len(sched.systems) || int(dependency) >= len(sched.systems) {
		return false
	}

	sys := &sched.systems[system]
	dep := &sched.systems[dependency]

	// Cannot depend on a system in a later phase
	if dep.phase > sys.phase {
		return false
	}

	// Check for duplicate
	for existing_dep in sys.dependencies {
		if existing_dep == dependency {
			return true // Already exists
		}
	}

	append(&sys.dependencies, dependency)
	sched.order_dirty = true
	return true
}

// Add dependency by name (convenience function)
scheduler_add_dependency_by_name :: proc(
	sched: ^Scheduler,
	system_name: string,
	dependency_name: string,
) -> bool {
	sys_id, sys_ok := sched.systems_by_name[system_name]
	dep_id, dep_ok := sched.systems_by_name[dependency_name]

	if !sys_ok || !dep_ok {
		return false
	}

	return scheduler_add_dependency(sched, sys_id, dep_id)
}

// Enable or disable a system
scheduler_set_enabled :: proc(sched: ^Scheduler, system: System_Id, enabled: bool) {
	if int(system) < len(sched.systems) {
		sched.systems[system].enabled = enabled
	}
}

// Check if a system is enabled
scheduler_is_enabled :: proc(sched: ^Scheduler, system: System_Id) -> bool {
	if int(system) >= len(sched.systems) {
		return false
	}
	return sched.systems[system].enabled
}

// Rebuild execution order using topological sort (Kahn's algorithm)
// Returns false if a cycle is detected
scheduler_rebuild_order :: proc(sched: ^Scheduler) -> bool {
	clear(&sched.execution_order)

	n := len(sched.systems)
	if n == 0 {
		sched.order_dirty = false
		return true
	}

	// Calculate in-degrees for each system
	in_degree := make([]int, n, context.temp_allocator)
	for &sys in sched.systems {
		for dep_id in sys.dependencies {
			// Only count dependencies within same or earlier phases
			dep := &sched.systems[dep_id]
			if dep.phase <= sys.phase {
				in_degree[sys.id] += 1
			}
		}
	}

	// Process phase by phase
	for phase in System_Phase {
		start_idx := len(sched.execution_order)

		// Queue for systems with no pending dependencies in this phase
		queue := make([dynamic]System_Id, context.temp_allocator)

		// Find all systems in this phase with zero in-degree
		for &sys in sched.systems {
			if sys.phase == phase && in_degree[sys.id] == 0 {
				append(&queue, sys.id)
			}
		}

		processed := 0
		for len(queue) > 0 {
			// Pop from queue (FIFO for deterministic order)
			current := queue[0]
			ordered_remove(&queue, 0)

			append(&sched.execution_order, current)
			processed += 1

			// Decrease in-degree for systems that depend on this one
			for &sys in sched.systems {
				for dep_id in sys.dependencies {
					if dep_id == current {
						in_degree[sys.id] -= 1
						// Only add to current phase's queue if same phase and ready
						if sys.phase == phase && in_degree[sys.id] == 0 {
							append(&queue, sys.id)
						}
					}
				}
			}
		}

		// Count systems in this phase
		phase_count := 0
		for &sys in sched.systems {
			if sys.phase == phase {
				phase_count += 1
			}
		}

		// Check for cycle (not all systems were processed)
		if processed != phase_count {
			return false
		}

		end_idx := len(sched.execution_order)
		sched.phase_ranges[phase] = [2]int{start_idx, end_idx}
	}

	sched.order_dirty = false
	return true
}

// Run all enabled systems in order
scheduler_run :: proc(sched: ^Scheduler, world: ^World) -> bool {
	if sched.order_dirty {
		if !scheduler_rebuild_order(sched) {
			return false // Cycle or other error
		}
	}

	for sys_id in sched.execution_order {
		sys := &sched.systems[sys_id]
		if sys.enabled && sys.proc_ptr != nil {
			sys.proc_ptr(world)
		}
	}

	return true
}

// Run systems in a specific phase only
scheduler_run_phase :: proc(sched: ^Scheduler, world: ^World, phase: System_Phase) -> bool {
	if sched.order_dirty {
		if !scheduler_rebuild_order(sched) {
			return false
		}
	}

	range := sched.phase_ranges[phase]
	for i in range[0] ..< range[1] {
		sys_id := sched.execution_order[i]
		sys := &sched.systems[sys_id]
		if sys.enabled && sys.proc_ptr != nil {
			sys.proc_ptr(world)
		}
	}

	return true
}

// Get the number of registered systems
scheduler_system_count :: proc(sched: ^Scheduler) -> int {
	return len(sched.systems)
}

// Get the number of enabled systems
scheduler_enabled_count :: proc(sched: ^Scheduler) -> int {
	count := 0
	for &sys in sched.systems {
		if sys.enabled {
			count += 1
		}
	}
	return count
}
