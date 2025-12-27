# Artifact ECS

Artifact is an archetype-based Entity Component System (ECS) library for Odin, designed for game engine development.

## Overview

Artifact organizes entities by their component composition using archetypes. Entities with identical component sets are stored together in contiguous memory, enabling cache-efficient iteration and high-performance system execution.

### Key Features

-   **Archetype-based storage**: Entities with the same components are grouped together
-   **Struct of Arrays (SoA) layout**: Components stored in contiguous columns for cache efficiency
-   **Generational entity handles**: 64-bit handles with embedded generation for safe reuse detection
-   **O(1) operations**: Constant-time entity lookup, component access, and column retrieval
-   **Query caching**: Repeated queries are cached and invalidated only when archetypes change
-   **Deferred operations**: Safe structural changes during iteration
-   **SIMD-friendly alignment**: 32-byte aligned component storage
-   **System scheduler**: Phase-based execution with dependency ordering and topological sort

## Installation

Clone or copy the `src/` directory into your Odin project and import:

```odin
import artifact "path/to/artifact/src"
```

## Quick Start

```odin
import artifact "artifact/src"

// Define components
Position :: struct {
    x, y: f32,
}

Velocity :: struct {
    vx, vy: f32,
}

main :: proc() {
    // Create world
    world := artifact.world_create()
    defer artifact.world_destroy(&world)

    // Register components
    artifact.world_register_component(&world, Position)
    artifact.world_register_component(&world, Velocity)

    // Spawn entities
    entity, _ := artifact.entity_spawn(&world,
        Position{0, 0},
        Velocity{1, 2},
    )

    // Query and iterate
    for arch in artifact.query(&world, Position, Velocity).archetypes {
        positions := artifact.archetype_get_column(arch, Position)
        velocities := artifact.archetype_get_column(arch, Velocity)

        for i in 0 ..< arch.count {
            positions[i].x += velocities[i].vx
            positions[i].y += velocities[i].vy
        }
    }
}
```

## API Reference

### World Management

| Function                             | Description                         |
| ------------------------------------ | ----------------------------------- |
| `world_create(capacity, allocator)`  | Create a new ECS world              |
| `world_destroy(world)`               | Destroy world and release resources |
| `world_register_component(world, T)` | Register a component type           |
| `world_entity_count(world)`          | Get number of alive entities        |
| `world_archetype_count(world)`       | Get number of archetypes            |
| `world_flush(world)`                 | Apply all deferred operations       |

### Entity Management

| Function                            | Description                                   |
| ----------------------------------- | --------------------------------------------- |
| `entity_create(world)`              | Create an empty entity                        |
| `entity_spawn(world, components..)` | Create entity with components                 |
| `entity_destroy(world, entity)`     | Destroy an entity                             |
| `entity_alive(world, entity)`       | Check if entity is alive                      |
| `entity_is_valid(entity)`           | Check if handle is valid (not INVALID_ENTITY) |

### Component Access

| Function                              | Description                   |
| ------------------------------------- | ----------------------------- |
| `component_get(world, entity, T)`     | Get pointer to component      |
| `component_has(world, entity, T)`     | Check if entity has component |
| `component_set(world, entity, value)` | Update existing component     |
| `component_add(world, entity, value)` | Add component to entity       |
| `component_remove(world, entity, T)`  | Remove component from entity  |

### Queries

| Function                      | Description                               |
| ----------------------------- | ----------------------------------------- |
| `query(world, types..)`       | Query archetypes with required components |
| `query_builder(world)`        | Create a query builder                    |
| `query_with(builder, T)`      | Add required component to query           |
| `query_without(builder, T)`   | Add excluded component to query           |
| `query_execute(builder)`      | Execute query and get results             |
| `query_count(world, types..)` | Count entities matching query             |

### Archetype Access

| Function                                | Description                         |
| --------------------------------------- | ----------------------------------- |
| `archetype_get_column(arch, T)`         | Get typed slice of component column |
| `archetype_get_component(arch, row, T)` | Get single component by row index   |
| `world_get_archetype(world, types..)`   | Get or create archetype             |

### Deferred Operations

| Function                             | Description              |
| ------------------------------------ | ------------------------ |
| `deferred_destroy(world, entity)`    | Queue entity destruction |
| `deferred_add(world, entity, value)` | Queue component addition |
| `deferred_remove(world, entity, T)`  | Queue component removal  |

### System Scheduler

| Function                                          | Description                              |
| ------------------------------------------------- | ---------------------------------------- |
| `scheduler_create(allocator)`                     | Create a new scheduler                   |
| `scheduler_destroy(sched)`                        | Destroy scheduler and free resources     |
| `scheduler_add_system(sched, name, proc, phase)`  | Register a system in a phase             |
| `scheduler_get_system(sched, name)`               | Get system ID by name                    |
| `scheduler_add_dependency(sched, system, dep)`    | Add dependency (dep runs before system)  |
| `scheduler_add_dependency_by_name(sched, s, dep)` | Add dependency by system names           |
| `scheduler_set_enabled(sched, system, enabled)`   | Enable or disable a system               |
| `scheduler_is_enabled(sched, system)`             | Check if system is enabled               |
| `scheduler_run(sched, world)`                     | Run all systems in order                 |
| `scheduler_run_phase(sched, world, phase)`        | Run systems in a specific phase          |
| `scheduler_rebuild_order(sched)`                  | Rebuild execution order (detects cycles) |
| `scheduler_system_count(sched)`                   | Get total number of systems              |
| `scheduler_enabled_count(sched)`                  | Get number of enabled systems            |

**System Phases** (execute in order):
1. `Pre_Update` - Input handling, physics preparation
2. `Update` - Main game logic
3. `Post_Update` - Collision response, cleanup
4. `Render` - Drawing and presentation

## Usage Patterns

### System Implementation

```odin
movement_system :: proc(world: ^artifact.World) {
    for arch in artifact.query(world, Position, Velocity).archetypes {
        positions := artifact.archetype_get_column(arch, Position)
        velocities := artifact.archetype_get_column(arch, Velocity)

        for i in 0 ..< arch.count {
            positions[i].x += velocities[i].vx
            positions[i].y += velocities[i].vy
        }
    }
}
```

### Using the Scheduler

```odin
// Create scheduler
sched := artifact.scheduler_create()
defer artifact.scheduler_destroy(&sched)

// Register systems in phases
artifact.scheduler_add_system(&sched, "input", input_system, .Pre_Update)
physics_id := artifact.scheduler_add_system(&sched, "physics", physics_system, .Update)
movement_id := artifact.scheduler_add_system(&sched, "movement", movement_system, .Update)
artifact.scheduler_add_system(&sched, "render", render_system, .Render)

// Set up dependencies (movement runs after physics)
artifact.scheduler_add_dependency(&sched, movement_id, physics_id)

// Game loop
for !should_quit {
    artifact.scheduler_run(&sched, &world)
}
```

### Query with Exclusions

```odin
// Find all entities with Position but without Frozen
qb := artifact.query_builder(&world)
artifact.query_with(&qb, Position)
artifact.query_without(&qb, Frozen)

for arch in artifact.query_execute(&qb).archetypes {
    // Process non-frozen entities
}
```

### Safe Iteration with Deferred Operations

When modifying entity structure during iteration, use deferred operations to avoid invalidating iterators:

```odin
for arch in artifact.query(&world, Health).archetypes {
    healths := artifact.archetype_get_column(arch, Health)

    for i in 0 ..< arch.count {
        entity := arch.entities[i]

        if healths[i].current <= 0 {
            // Queue for later - safe during iteration
            artifact.deferred_add(&world, entity, Dead{})
            artifact.deferred_remove(&world, entity, Health)
        }
    }
}

// Apply all queued changes
artifact.world_flush(&world)
```

### Single Entity Component Access

```odin
// Get component pointer
if pos := artifact.component_get(&world, player, Position); pos != nil {
    pos.x = 100
    pos.y = 200
}

// Check before access
if artifact.component_has(&world, player, Velocity) {
    vel := artifact.component_get(&world, player, Velocity)
    // Use velocity
}

// Add/remove components
artifact.component_add(&world, player, Shield{health = 50})
artifact.component_remove(&world, player, Shield)
```

### Callback-Based Iteration

```odin
artifact.for_each_2(&world, Position, Velocity,
    proc(entity: artifact.Entity, pos: ^Position, vel: ^Velocity) {
        pos.x += vel.vx
        pos.y += vel.vy
    }
)
```

## Architecture

### Entity Handles

Entities are 64-bit generational handles:

-   Lower 32 bits: Pool index
-   Upper 32 bits: Generation counter

The generation counter increments when an entity slot is reused, allowing detection of stale handles.

### Archetypes

An archetype stores all entities with an identical set of components. Each archetype contains:

-   A bitmask identifying which components are present
-   A dynamic array of entity handles
-   Component columns (one per component type)
-   A column index map for O(1) component type lookups

When a component is added or removed from an entity, the entity moves to a different archetype.

### Component Storage

Components are stored in a Struct of Arrays layout within each archetype. Each component type has its own contiguous array (column), enabling cache-efficient iteration when processing many entities.

### Query Caching

Query results are cached by component mask. The cache is invalidated when new archetypes are created, not when entities are spawned or destroyed. This provides high cache hit rates for systems that query the same components each frame.

## Constants and Limits

| Constant                       | Value | Description                        |
| ------------------------------ | ----- | ---------------------------------- |
| `MAX_COMPONENTS`               | 64    | Maximum registered component types |
| `DEFAULT_ENTITY_POOL_CAPACITY` | 65536 | Initial entity pool size           |
| `DEFAULT_ARCHETYPE_CAPACITY`   | 1024  | Initial capacity per archetype     |
| `COLUMN_ALIGNMENT`             | 32    | Memory alignment (SIMD-compatible) |

## Performance Characteristics

| Operation            | Complexity                       |
| -------------------- | -------------------------------- |
| Entity lookup        | O(1)                             |
| Component access     | O(1)                             |
| Column lookup        | O(1) via hash map                |
| Entity spawn         | O(1) amortized                   |
| Entity destroy       | O(1)                             |
| Component add/remove | O(1) amortized                   |
| Query (cached)       | O(1)                             |
| Query (uncached)     | O(n) where n = archetype count   |
| Iteration            | O(m) where m = matching entities |

## License

See LICENSE file for details.
