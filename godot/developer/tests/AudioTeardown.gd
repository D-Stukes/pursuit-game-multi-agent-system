extends RefCounted
## Native runs only: stopping a stream is finished by the audio thread and the main loop a frame or two
## later. Release GameAudio's streams and let those frames run before quit, or the engine reports
## leaked MP3 playbacks at exit.
static func release(tree: SceneTree) -> void:
	var audio: Node = tree.root.get_node_or_null("GameAudio")
	if audio != null: audio.release()
	for _i: int in range(8): await tree.process_frame
