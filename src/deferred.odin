package artifact

import "core:mem"

Deferred_Op :: union {
	Deferred_Destroy,
	Deferred_Add,
	Deferred_Remove,
	Deferred_Set_Parent,
}

Deferred_Destroy :: struct {
	entity: Entity,
}

Deferred_Add :: struct {
	entity: Entity,
	value:  any,
}

Deferred_Remove :: struct {
	entity:  Entity,
	type_id: typeid,
}

Deferred_Set_Parent :: struct {
	child:  Entity,
	parent: Entity,
}

deferred_destroy :: proc(world: ^World, entity: Entity) {
	append(&world.deferred_ops, Deferred_Op(Deferred_Destroy{entity = entity}))
}

deferred_add :: proc(world: ^World, entity: Entity, value: $T) -> bool {
	data, err := mem.alloc(size_of(T), align_of(T), world.allocator)
	if err != .None || data == nil {
		return false
	}
	(cast(^T)data)^ = value
	append(
		&world.deferred_ops,
		Deferred_Op(Deferred_Add{entity = entity, value = any{data = data, id = typeid_of(T)}}),
	)
	return true
}

deferred_remove :: proc(world: ^World, entity: Entity, $T: typeid) {
	append(&world.deferred_ops, Deferred_Op(Deferred_Remove{entity = entity, type_id = T}))
}

deferred_set_parent :: proc(world: ^World, child: Entity, parent: Entity) {
	append(&world.deferred_ops, Deferred_Op(Deferred_Set_Parent{child = child, parent = parent}))
}

world_flush :: proc(world: ^World) {
	for op in world.deferred_ops {
		switch o in op {
		case Deferred_Destroy:
			entity_destroy(world, o.entity)
		case Deferred_Add:
			component_add_raw(world, o.entity, o.value)
			mem.free(o.value.data, world.allocator)
		case Deferred_Remove:
			component_remove_by_id(world, o.entity, o.type_id)
		case Deferred_Set_Parent:
			entity_set_parent(world, o.child, o.parent)
		}
	}
	clear(&world.deferred_ops)
}

deferred_ops_clear :: proc(world: ^World) {
	for op in world.deferred_ops {
		switch o in op {
		case Deferred_Destroy:
		case Deferred_Add:
			mem.free(o.value.data, world.allocator)
		case Deferred_Remove:
		case Deferred_Set_Parent:
		}
	}
	clear(&world.deferred_ops)
}
