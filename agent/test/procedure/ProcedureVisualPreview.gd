extends Control

## Standalone PROCEDURE animation preview. Space / Enter replays the fixed token sample.
## Full sample is 200 unique tokens; TokenizerEffect uses the first complete sentence (~12),
## then EmbeddingEffect flies every token into the RGB starfield.

## First 12 form one sentence ending in "？"; remaining pieces are unique fillers for EmbeddingEffect.
const SAMPLE_PIECES: Array[String] = [
	"每次", "我", "向你", "提问", "，", "你的", "脑子", "里", "发生", "了", "什么", "？",
	"模型", "先把", "输入", "拆成", "离散", "符号", "再映射", "到高维", "空间", "形成",
	"语义", "表示", "注意力", "会扫描", "上下文", "权重", "决定", "哪些", "线索", "更重要",
	"前馈", "网络", "随后", "非线性", "变换", "特征", "残差", "连接", "保留", "原始",
	"信号", "层归一化", "稳定", "训练", "过程", "位置", "编码", "注入", "顺序", "信息",
	"多头", "机制", "并行", "捕捉", "不同", "关系", "模式", "掩码", "限制", "可见",
	"范围", "防止", "泄露", "未来", "词元", "嵌入", "矩阵", "把编号", "变成", "连续",
	"向量", "点积", "衡量", "相似", "程度", "缩放", "避免", "梯度", "爆炸", "软最大化",
	"得到", "概率", "分布", "输出", "头", "预测", "下一个", "候选", "采样", "策略",
	"温度", "调节", "随机性", "束搜索", "权衡", "多样性", "与连贯", "缓存", "键值",
	"加速", "推理", "吞吐", "量化", "压缩", "显存", "占用", "蒸馏", "迁移", "知识",
	"微调", "适配", "下游", "任务", "提示", "工程", "引导", "行为", "对齐", "偏好",
	"安全", "过滤", "有害", "内容", "工具", "调用", "扩展", "能力", "边界", "检索",
	"增强", "生成", "质量", "评估", "指标", "困惑度", "反映", "流畅", "人工", "反馈",
	"强化学习", "优化", "多模态", "图像", "文本", "音频", "统一", "接口", "流水线", "调度",
	"批次", "延迟", "吞吐率", "显卡", "利用率", "算子", "内核", "减少", "开销", "编译",
	"图优化", "常量", "折叠", "死代码", "消除", "内联", "展开", "循环", "向量化", "指令",
	"并行度", "内存", "带宽", "瓶颈", "局部性", "友好", "布局", "张量", "切片", "广播",
	"语义化", "命名", "便于", "调试", "日志", "追踪", "请求", "链路", "指标面板", "告警",
	"阈值", "回滚", "版本", "灰度", "发布", "验证", "校验和", "哈希", "指纹",
]
const SAMPLE_IDS: Array[int] = [
	97571, 14594, 84209, 93355, 10867, 62431, 73642, 31876, 55729, 91004, 48113, 20497,
	10001, 10002, 10003, 10004, 10005, 10006, 10007, 10008, 10009, 10010,
	10011, 10012, 10013, 10014, 10015, 10016, 10017, 10018, 10019, 10020,
	10021, 10022, 10023, 10024, 10025, 10026, 10027, 10028, 10029, 10030,
	10031, 10032, 10033, 10034, 10035, 10036, 10037, 10038, 10039, 10040,
	10041, 10042, 10043, 10044, 10045, 10046, 10047, 10048, 10049, 10050,
	10051, 10052, 10053, 10054, 10055, 10056, 10057, 10058, 10059, 10060,
	10061, 10062, 10063, 10064, 10065, 10066, 10067, 10068, 10069, 10070,
	10071, 10072, 10073, 10074, 10075, 10076, 10077, 10078, 10079, 10080,
	10081, 10082, 10083, 10084, 10085, 10086, 10087, 10088, 10089, 10090,
	10091, 10092, 10093, 10094, 10095, 10096, 10097, 10098, 10099, 10100,
	10101, 10102, 10103, 10104, 10105, 10106, 10107, 10108, 10109, 10110,
	10111, 10112, 10113, 10114, 10115, 10116, 10117, 10118, 10119, 10120,
	10121, 10122, 10123, 10124, 10125, 10126, 10127, 10128, 10129, 10130,
	10131, 10132, 10133, 10134, 10135, 10136, 10137, 10138, 10139, 10140,
	10141, 10142, 10143, 10144, 10145, 10146, 10147, 10148, 10149, 10150,
	10151, 10152, 10153, 10154, 10155, 10156, 10157, 10158, 10159, 10160,
	10161, 10162, 10163, 10164, 10165, 10166, 10167, 10168, 10169, 10170,
	10171, 10172, 10173, 10174, 10175, 10176, 10177, 10178, 10179, 10180,
	10181, 10182, 10183, 10184, 10185, 10186, 10187, 10188,
]

var procedure: ProcedureController
var replaying: bool = false


func _ready() -> void:
	build_preview_ui()
	replay.call_deferred()
	pass


func build_preview_ui() -> void:
	var background := ColorRect.new()
	background.color = ColorBase.deep_surface
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	procedure = ProcedureController.new()
	procedure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(procedure)

	var hint := Label.new()
	hint.text = "PROCEDURE · Space / Enter 重播"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Fonts.regular())
	hint.add_theme_font_size_override("font_size", Typography.label_medium_size)
	hint.add_theme_color_override("font_color", ColorBase.secondary_text)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -48.0
	hint.offset_bottom = -20.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	pass


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		replay()
		get_viewport().set_input_as_handled()
	pass


func build_sample_tokens() -> Array[LlamaHelper.Token]:
	assert(SAMPLE_PIECES.size() == 200)
	assert(SAMPLE_IDS.size() == 200)
	var tokens: Array[LlamaHelper.Token] = []
	for index in SAMPLE_PIECES.size():
		tokens.append(LlamaHelper.Token.new(SAMPLE_IDS[index], SAMPLE_PIECES[index]))
	return tokens


func replay() -> void:
	if replaying:
		return
	replaying = true
	await procedure.play_preview(build_sample_tokens())
	replaying = false
	pass
