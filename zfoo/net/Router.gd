class_name Router
extends Object

const ASK_TIMEOUT_MILLIS: int = 13 * TimeUtils.MILLIS_PER_SECOND

# SignalBridge
static var signalAttachmentMap: Dictionary[int, EncodedPacketInfo] = {}

# PacketBus
static var packetBus: Dictionary[int, Callable] = {}

static var ignored_packet_logs: Array[Object] = []

####################################################################################################
static func send(session: ISession, packet: Object, attachment: Object = null) -> void:
	if packet == null:
		Log.error("Router send pact is null")
		return
	if !session.is_activate():
		Log.error("session:[{}] is not activate and packet:[{}] cannot be sent", session.address(), packet.get_script().get_global_name())
		return
	session.send(EncodedPacketInfo.new(packet, attachment))
	if !ignored_packet_logs.has(packet.get_script()):
		Log.info("send packet ----> {} [{}] attachment:[{}]", packet.get_script().get_global_name(), JsonUtils.object_to_json(packet), attachment != null)
	pass

static func async_ask(session: ISession, packet: Object) -> Object:
	if packet == null:
		Log.error("Router async_ask pact is null")
		return
	var now := TimeUtils.now()
	var attachment: SignalAttachment = SignalAttachment.new()
	var signalId := IdUtils.local_id()
	attachment.signalId = signalId
	attachment.timestamp = now
	attachment.client = 12
	attachment.taskExecutorHash = -1
	var encodedPacketInfo: EncodedPacketInfo = EncodedPacketInfo.new(packet, attachment)
	# add attachment
	signalAttachmentMap[signalId] = encodedPacketInfo
	SchedulerBus.schedule(Callable(Router, "ask_timeout"), ASK_TIMEOUT_MILLIS + TimeUtils.MILLIS_PER_SECOND_5)
	send(session, packet, attachment)
	var returnPacket = await encodedPacketInfo.packet_signal
	# remove attachment
	signalAttachmentMap.erase(signalId)
	return returnPacket

# remove timeout async_ask packet
static func ask_timeout() -> void:
	var now := TimeUtils.now()
	for key in signalAttachmentMap.keys():
		var oldAttachment := signalAttachmentMap[key].attachment
		if oldAttachment != null && now - oldAttachment.timestamp > ASK_TIMEOUT_MILLIS:
			signalAttachmentMap.erase(key)
	pass

static func at_receiver(decodedPacketInfo: DecodedPacketInfo) -> void:
	if decodedPacketInfo == null:
		return
	var packet := decodedPacketInfo.packet
	var attachment := decodedPacketInfo.attachment
	if !ignored_packet_logs.has(packet.get_script()):
		Log.info("receive packet <- {} [{}] attachment:[{}]", packet.get_script().get_global_name(), JsonUtils.object_to_json(packet), attachment != null)

	if attachment == null:
		if !packetBus.has(packet.PROTOCOL_ID):
			Log.error("[protocol:{}][protocolId:{}] has no registration, please register for this protocol", packet.get_script().get_global_name(), packet.PROTOCOL_ID)
			return
		packetBus[packet.PROTOCOL_ID].call(packet)
	else:
		var clientAttachment: EncodedPacketInfo = signalAttachmentMap[attachment.signalId]
		clientAttachment.packet_signal.emit(packet)
	pass

####################################################################################################
static func register_receiver(protocol, callable: Callable) -> void:
	if packetBus.has(protocol.PROTOCOL_ID):
		var old := packetBus[protocol.PROTOCOL_ID]
		Log.error("Router register_receiver duplicate [protocol:{}] receiver [old:{}] [new:{}]", protocol, old, callable)
		return
	packetBus[protocol.PROTOCOL_ID] = callable
	pass

static func remove_receiver(protocol):
	packetBus.erase(protocol.PROTOCOL_ID)
	pass
