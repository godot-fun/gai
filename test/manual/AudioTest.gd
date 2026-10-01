extends Node

@onready var playMusicButton: Button = $PlayMusic
@onready var playSoundButton: Button = $PlaySound
@onready var startRecordButton: Button = $StartRecord
@onready var stopRecordButton: Button = $StopRecord

func _ready() -> void:
	playMusicButton.pressed.connect(pressedPlayMusicButton)
	playSoundButton.pressed.connect(pressedPlaySoundButton)
	startRecordButton.pressed.connect(pressedStartRecordButton)
	stopRecordButton.pressed.connect(pressedStopRecordButton)
	Linear_test()
	pass


func Linear_test() -> void:
	var a: float = linear_to_db(1)
	assert(a == 0)
	var b: float = db_to_linear(0)
	assert(b == 1)
	pass

func pressedPlayMusicButton():
	Audio.play_musics(["test/asset/All_the_Way_North.mp3", "test/asset/White_Windmill.mp3"])
	Audio.set_audio_bus_volume_linear(Audio.AudioBusType.Music, 0.6)
	pass

func pressedPlaySoundButton():
#	Audio.play_sound("test/asset/cheer.mp3")
	Audios.play("test/asset/cheer.mp3")
	Audios.set_bus_volume_linear(0.9)
	pass

func pressedStartRecordButton() -> void:
	AudioRecorder.start()
	Log.info("AudioRecorder started")
	pass

func pressedStopRecordButton() -> void:
	var wav := AudioRecorder.stop()
	var path := OS.get_user_data_dir().path_join("manual_recording.wav")
	var err := AudioRecorder.save(wav, path)
	if err == OK:
		Log.info("AudioRecorder saved:[{}]", path)
	else:
		Log.error("AudioRecorder save failed err:[{}] path:[{}]", err, path)
	pass
