static func qwen_model_paths_test() -> void:
	assert(LlamServer.MODEL_NAME == "Qwen3.8-27B-Q4_K_M.gguf")
	assert(LlamServer.MODEL_PATH.ends_with("/Qwen3.8-27B-Q4_K_M.gguf"))
	assert(LlamServer.MMPROJ_PATH.ends_with("/mmproj-Qwen3.8-27B-BF16.gguf"))
	pass


static func qwen_server_args_test() -> void:
	var args := LlamServer.build_server_args("model.gguf", "mmproj.gguf", true)
	assert(args.has("--model"))
	assert(args.has("model.gguf"))
	assert(args.has("--mmproj"))
	assert(args.has("mmproj.gguf"))
	assert(LlamServer.CONTEXT_SIZE == 32768)
	assert(args.has("32768"))
	assert(args.has("--image-min-tokens"))
	assert(args.has("--reasoning"))
	assert(args.has("off"))
	assert(args.has("--no-reasoning-preserve"))
	assert(args.has("all"))
	pass


static func cpu_server_args_disable_offload_test() -> void:
	var args := LlamServer.build_server_args("model.gguf", "mmproj.gguf", false)
	assert(args.has("0"))
	assert(args.has("--no-mmproj-offload"))
	pass
