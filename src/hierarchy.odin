package artifact

import "core:mem"

Hierarchy_Node :: struct {
	parent:   Entity,
	children: [dynamic]Entity,
}

Hierarchy :: struct {
	nodes:     map[Entity]Hierarchy_Node,
	allocator: mem.Allocator,
}

hierarchy_create :: proc(allocator: mem.Allocator) -> Hierarchy {
	return Hierarchy {
		nodes = make(map[Entity]Hierarchy_Node, allocator = allocator),
		allocator = allocator,
	}
}

hierarchy_destroy :: proc(h: ^Hierarchy) {
	for _, &node in h.nodes {
		delete(node.children)
	}
	delete(h.nodes)
}

@(private = "file")
hierarchy_ensure_node :: proc(h: ^Hierarchy, entity: Entity) -> ^Hierarchy_Node {
	if entity not_in h.nodes {
		h.nodes[entity] = Hierarchy_Node {
			parent   = INVALID_ENTITY,
			children = make([dynamic]Entity, h.allocator),
		}
	}
	return &h.nodes[entity]
}

@(private = "file")
hierarchy_maybe_remove_node :: proc(h: ^Hierarchy, entity: Entity) {
	if node, ok := h.nodes[entity]; ok {
		if node.parent == INVALID_ENTITY && len(node.children) == 0 {
			delete(node.children)
			delete_key(&h.nodes, entity)
		}
	}
}

entity_set_parent :: proc(world: ^World, child: Entity, parent: Entity) -> bool {
	if !entity_alive(world, child) {
		return false
	}

	if child == parent {
		return false
	}

	if parent != INVALID_ENTITY {
		if !entity_alive(world, parent) {
			return false
		}

		current := parent
		for current != INVALID_ENTITY {
			if current == child {
				return false
			}
			current = entity_get_parent(world, current)
		}
	}

	h := &world.hierarchy

	if node, ok := h.nodes[child]; ok && node.parent != INVALID_ENTITY {
		if old_parent_node, ok := &h.nodes[node.parent]; ok {
			for i := 0; i < len(old_parent_node.children); i += 1 {
				if old_parent_node.children[i] == child {
					unordered_remove(&old_parent_node.children, i)
					break
				}
			}
			hierarchy_maybe_remove_node(h, node.parent)
		}
	}

	if parent == INVALID_ENTITY {
		if node, ok := &h.nodes[child]; ok {
			node.parent = INVALID_ENTITY
			hierarchy_maybe_remove_node(h, child)
		}
		return true
	}

	child_node := hierarchy_ensure_node(h, child)
	child_node.parent = parent

	parent_node := hierarchy_ensure_node(h, parent)
	append(&parent_node.children, child)

	return true
}

entity_get_parent :: proc(world: ^World, child: Entity) -> Entity {
	if !entity_alive(world, child) {
		return INVALID_ENTITY
	}

	if node, ok := world.hierarchy.nodes[child]; ok {
		return node.parent
	}
	return INVALID_ENTITY
}

entity_get_children :: proc(world: ^World, parent: Entity) -> []Entity {
	if !entity_alive(world, parent) {
		return nil
	}

	if node, ok := world.hierarchy.nodes[parent]; ok {
		return node.children[:]
	}
	return nil
}

entity_has_parent :: proc(world: ^World, child: Entity) -> bool {
	if !entity_alive(world, child) {
		return false
	}

	if node, ok := world.hierarchy.nodes[child]; ok {
		return node.parent != INVALID_ENTITY
	}
	return false
}

entity_has_children :: proc(world: ^World, parent: Entity) -> bool {
	if !entity_alive(world, parent) {
		return false
	}

	if node, ok := world.hierarchy.nodes[parent]; ok {
		return len(node.children) > 0
	}
	return false
}

entity_child_count :: proc(world: ^World, parent: Entity) -> int {
	if !entity_alive(world, parent) {
		return 0
	}

	if node, ok := world.hierarchy.nodes[parent]; ok {
		return len(node.children)
	}
	return 0
}

hierarchy_on_entity_destroy :: proc(h: ^Hierarchy, entity: Entity) {
	if node, ok := h.nodes[entity]; ok {
		if node.parent != INVALID_ENTITY {
			if parent_node, ok := &h.nodes[node.parent]; ok {
				for i := 0; i < len(parent_node.children); i += 1 {
					if parent_node.children[i] == entity {
						unordered_remove(&parent_node.children, i)
						break
					}
				}
				hierarchy_maybe_remove_node(h, node.parent)
			}
		}

		for child in node.children {
			if child_node, ok := &h.nodes[child]; ok {
				child_node.parent = INVALID_ENTITY
				hierarchy_maybe_remove_node(h, child)
			}
		}

		delete(node.children)
		delete_key(&h.nodes, entity)
	}
}
