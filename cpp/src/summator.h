#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

using namespace godot;

/// RefCounted integer accumulator exposed to GDScript via godot-cpp.
class Summator : public RefCounted {
	GDCLASS(Summator, RefCounted)

private:
	int count = 0;

protected:
	static void _bind_methods();

public:
	void add(int p_value);
	void reset();
	int get_total() const;
};
