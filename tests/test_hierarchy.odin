package tests

import artifact "../src"
import "core:testing"

@(test)
test_basic_parenting :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child1, _ := artifact.entity_create(&world)
	child2, _ := artifact.entity_create(&world)

	ok1 := artifact.entity_set_parent(&world, child1, parent)
	ok2 := artifact.entity_set_parent(&world, child2, parent)

	testing.expect(t, ok1, "Setting parent for child1 should succeed")
	testing.expect(t, ok2, "Setting parent for child2 should succeed")

	testing.expect(
		t,
		artifact.entity_get_parent(&world, child1) == parent,
		"child1 should have correct parent",
	)
	testing.expect(
		t,
		artifact.entity_get_parent(&world, child2) == parent,
		"child2 should have correct parent",
	)

	children := artifact.entity_get_children(&world, parent)
	testing.expect(t, len(children) == 2, "Parent should have 2 children")

	testing.expect(
		t,
		artifact.entity_get_parent(&world, parent) == artifact.INVALID_ENTITY,
		"Parent should be a root entity",
	)
}

@(test)
test_orphan_on_parent_destroy :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child1, _ := artifact.entity_create(&world)
	child2, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, child1, parent)
	artifact.entity_set_parent(&world, child2, parent)

	artifact.entity_destroy(&world, parent)

	testing.expect(
		t,
		artifact.entity_get_parent(&world, child1) == artifact.INVALID_ENTITY,
		"child1 should be orphaned (root)",
	)
	testing.expect(
		t,
		artifact.entity_get_parent(&world, child2) == artifact.INVALID_ENTITY,
		"child2 should be orphaned (root)",
	)

	testing.expect(t, artifact.entity_alive(&world, child1), "child1 should still be alive")
	testing.expect(t, artifact.entity_alive(&world, child2), "child2 should still be alive")
}

@(test)
test_cycle_detection :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	a, _ := artifact.entity_create(&world)
	b, _ := artifact.entity_create(&world)
	c, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, b, a)
	artifact.entity_set_parent(&world, c, b)

	ok := artifact.entity_set_parent(&world, a, c)
	testing.expect(t, !ok, "Creating cycle A -> B -> C -> A should fail")

	ok2 := artifact.entity_set_parent(&world, b, b)
	testing.expect(t, !ok2, "Self-parenting should fail")

	testing.expect(
		t,
		artifact.entity_get_parent(&world, b) == a,
		"B should still have A as parent",
	)
	testing.expect(
		t,
		artifact.entity_get_parent(&world, c) == b,
		"C should still have B as parent",
	)
}

@(test)
test_self_parenting_rejected :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entity, _ := artifact.entity_create(&world)

	ok := artifact.entity_set_parent(&world, entity, entity)
	testing.expect(t, !ok, "Self-parenting should be rejected")
	testing.expect(
		t,
		artifact.entity_get_parent(&world, entity) == artifact.INVALID_ENTITY,
		"Entity should remain a root",
	)
}

@(test)
test_reparenting :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent1, _ := artifact.entity_create(&world)
	parent2, _ := artifact.entity_create(&world)
	child, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, child, parent1)
	testing.expect(
		t,
		artifact.entity_get_parent(&world, child) == parent1,
		"Child should have parent1",
	)
	testing.expect(
		t,
		len(artifact.entity_get_children(&world, parent1)) == 1,
		"parent1 should have 1 child",
	)

	ok := artifact.entity_set_parent(&world, child, parent2)
	testing.expect(t, ok, "Reparenting should succeed")
	testing.expect(
		t,
		artifact.entity_get_parent(&world, child) == parent2,
		"Child should now have parent2",
	)
	testing.expect(
		t,
		len(artifact.entity_get_children(&world, parent1)) == 0,
		"parent1 should have 0 children",
	)
	testing.expect(
		t,
		len(artifact.entity_get_children(&world, parent2)) == 1,
		"parent2 should have 1 child",
	)
}

@(test)
test_remove_parent :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, child, parent)
	testing.expect(t, artifact.entity_has_parent(&world, child), "Child should have parent")

	ok := artifact.entity_set_parent(&world, child, artifact.INVALID_ENTITY)
	testing.expect(t, ok, "Removing parent should succeed")
	testing.expect(
		t,
		artifact.entity_get_parent(&world, child) == artifact.INVALID_ENTITY,
		"Child should be a root",
	)
	testing.expect(t, !artifact.entity_has_parent(&world, child), "Child should not have parent")
	testing.expect(
		t,
		len(artifact.entity_get_children(&world, parent)) == 0,
		"Parent should have 0 children",
	)
}

@(test)
test_deferred_set_parent :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child, _ := artifact.entity_create(&world)

	artifact.deferred_set_parent(&world, child, parent)

	testing.expect(
		t,
		artifact.entity_get_parent(&world, child) == artifact.INVALID_ENTITY,
		"Parent should not be set before flush",
	)

	artifact.world_flush(&world)

	testing.expect(
		t,
		artifact.entity_get_parent(&world, child) == parent,
		"Parent should be set after flush",
	)
}

@(test)
test_invalid_entity_handling :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	entity, _ := artifact.entity_create(&world)

	ok1 := artifact.entity_set_parent(&world, artifact.INVALID_ENTITY, entity)
	testing.expect(t, !ok1, "Setting parent on INVALID_ENTITY should fail")

	dead, _ := artifact.entity_create(&world)
	artifact.entity_destroy(&world, dead)

	ok2 := artifact.entity_set_parent(&world, entity, dead)
	testing.expect(t, !ok2, "Setting parent to dead entity should fail")

	testing.expect(
		t,
		artifact.entity_get_parent(&world, dead) == artifact.INVALID_ENTITY,
		"Dead entity parent should be INVALID_ENTITY",
	)
	testing.expect(
		t,
		len(artifact.entity_get_children(&world, dead)) == 0,
		"Dead entity children should be empty",
	)
}

@(test)
test_helper_functions :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child1, _ := artifact.entity_create(&world)
	child2, _ := artifact.entity_create(&world)

	testing.expect(t, !artifact.entity_has_parent(&world, child1), "Initially no parent")
	testing.expect(t, !artifact.entity_has_children(&world, parent), "Initially no children")
	testing.expect(t, artifact.entity_child_count(&world, parent) == 0, "Initially 0 children")

	artifact.entity_set_parent(&world, child1, parent)
	artifact.entity_set_parent(&world, child2, parent)

	testing.expect(t, artifact.entity_has_parent(&world, child1), "child1 should have parent")
	testing.expect(t, artifact.entity_has_children(&world, parent), "parent should have children")
	testing.expect(
		t,
		artifact.entity_child_count(&world, parent) == 2,
		"parent should have 2 children",
	)
}

@(test)
test_child_destroy_removes_from_parent :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	parent, _ := artifact.entity_create(&world)
	child1, _ := artifact.entity_create(&world)
	child2, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, child1, parent)
	artifact.entity_set_parent(&world, child2, parent)

	testing.expect(
		t,
		artifact.entity_child_count(&world, parent) == 2,
		"Parent should have 2 children",
	)

	artifact.entity_destroy(&world, child1)

	testing.expect(
		t,
		artifact.entity_child_count(&world, parent) == 1,
		"Parent should have 1 child",
	)
	children := artifact.entity_get_children(&world, parent)
	testing.expect(
		t,
		len(children) == 1 && children[0] == child2,
		"Remaining child should be child2",
	)
}

@(test)
test_deep_hierarchy :: proc(t: ^testing.T) {
	world := artifact.world_create()
	defer artifact.world_destroy(&world)

	root, _ := artifact.entity_create(&world)
	e1, _ := artifact.entity_create(&world)
	e2, _ := artifact.entity_create(&world)
	e3, _ := artifact.entity_create(&world)
	e4, _ := artifact.entity_create(&world)

	artifact.entity_set_parent(&world, e1, root)
	artifact.entity_set_parent(&world, e2, e1)
	artifact.entity_set_parent(&world, e3, e2)
	artifact.entity_set_parent(&world, e4, e3)

	testing.expect(t, artifact.entity_get_parent(&world, e4) == e3, "e4 parent is e3")
	testing.expect(t, artifact.entity_get_parent(&world, e3) == e2, "e3 parent is e2")
	testing.expect(t, artifact.entity_get_parent(&world, e2) == e1, "e2 parent is e1")
	testing.expect(t, artifact.entity_get_parent(&world, e1) == root, "e1 parent is root")
	testing.expect(
		t,
		artifact.entity_get_parent(&world, root) == artifact.INVALID_ENTITY,
		"root has no parent",
	)

	artifact.entity_destroy(&world, e2)

	testing.expect(
		t,
		artifact.entity_get_parent(&world, e3) == artifact.INVALID_ENTITY,
		"e3 should be orphaned",
	)
	testing.expect(
		t,
		artifact.entity_get_parent(&world, e4) == e3,
		"e4 should still have e3 as parent",
	)
}
