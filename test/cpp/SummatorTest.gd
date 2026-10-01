## Unit tests for the gai_cpp GDExtension (`Summator`).
extends RefCounted


func summator_add_test() -> void:
	var s: Summator = Summator.new()
	s.add(10)
	s.add(20)
	assert(s.get_total() == 30)
	pass


func summator_reset_test() -> void:
	var s: Summator = Summator.new()
	s.add(7)
	s.reset()
	assert(s.get_total() == 0)
	pass
