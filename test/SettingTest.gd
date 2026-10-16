
func Setting_test() -> void:
	Setting.clear()
	
	var boolKey := "aaa"
	var boolValue := true
	assert(false == Setting.get_bool(boolKey))
	Setting.set_bool(boolKey, boolValue)
	assert(boolValue == Setting.get_bool(boolKey))
	Setting.save()
	await gdf.gdf_node.get_tree().create_timer(1).timeout
	
	var intKey := "bbb"
	var intValue := 2000000000
	assert(0 == Setting.get_int(intKey))
	Setting.set_int(intKey, intValue)
	assert(intValue == Setting.get_int(intKey))
	Setting.save()
	await gdf.gdf_node.get_tree().create_timer(1).timeout
	
	var floatKey := "ccc"
	var floatValue := -100
	assert(0 == Setting.get_float(floatKey))
	Setting.set_float(floatKey, floatValue)
	assert(floatValue == Setting.get_float(floatKey))
	Setting.save()
	await gdf.gdf_node.get_tree().create_timer(1).timeout
	
	var stringKey := "ddd"
	var stringValue := "Hello World!"
	assert(StringUtils.EMPTY == Setting.get_string(stringKey))
	Setting.set_string(stringKey, stringValue)
	assert(stringValue == Setting.get_string(stringKey))
	Setting.save()
	await gdf.gdf_node.get_tree().create_timer(1).timeout
	FileUtils.delete_file_or_directory(Setting.SETTING_FILE_PATH)
	pass

