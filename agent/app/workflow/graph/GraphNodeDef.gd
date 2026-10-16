class_name GraphNodeDef
extends RefCounted

var inputs: Array[PortDef] = []
var outputs: Array[PortDef] = []


func catalog_id() -> String:
	return ""


func display_label() -> String:
	var id := catalog_id()
	var key := "workflow.node." + id
	var translated := I18n.t(key)
	return id if translated == key else translated


func is_source() -> bool:
	return false


func is_batch() -> bool:
	return false


func primary_output_is_folder() -> bool:
	if outputs.is_empty():
		return false
	return outputs[0].port_type == PortDef.TYPE_FOLDER


func find_input(port_id: String) -> PortDef:
	for port in inputs:
		if port.id == port_id:
			return port
	return null


func find_output(port_id: String) -> PortDef:
	for port in outputs:
		if port.id == port_id:
			return port
	return null


func input_port_index_for_id(port_id: String) -> int:
	for i in range(inputs.size()):
		if inputs[i].id == port_id:
			return i
	return -1


func output_port_at_port_index(port_index: int) -> PortDef:
	if port_index < 0 or port_index >= outputs.size():
		return null
	return outputs[port_index]
