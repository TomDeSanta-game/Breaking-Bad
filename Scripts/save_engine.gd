extends Node

const SAVE_DIR = "user://saves/"
const METADATA_FILE = "metadata.json"
const SAVE_RESOURCE = "gamestate.tres"
const ENCRYPTION_KEY = "breaking_bad_encryption_seed"

func _ready():
	var dir = DirAccess.open("user://")
	if not dir:
		Log.err("Cannot access user directory")
		return
		
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)

func save_game():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir(SAVE_DIR)
	
	var save_resource = Resource.new()
	save_resource.set_meta("timestamp", Time.get_unix_time_from_system())
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		save_resource.set_meta("player_pos_x", player.global_position.x)
		save_resource.set_meta("player_pos_y", player.global_position.y)
		
		if "health" in player:
			save_resource.set_meta("player_health", player.health)
	
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager:
		save_resource.set_meta("current_mission", mission_manager.current_mission)
		if "completed_missions" in mission_manager:
			save_resource.set_meta("completed_missions", mission_manager.completed_missions)
	
	var err = ResourceSaver.save(save_resource, SAVE_DIR + SAVE_RESOURCE, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		Log.err("Failed to save game resource: " + str(err))
		return false
	
	var metadata = {
		"timestamp": Time.get_unix_time_from_system(),
		"save_date": Time.get_datetime_string_from_system(),
		"version": "1.0",
		"mission": mission_manager.current_mission if mission_manager else "unknown"
	}
	
	var json_data = JSON.stringify(metadata, "  ")
	var metadata_file = FileAccess.open(SAVE_DIR + METADATA_FILE, FileAccess.WRITE)
	if metadata_file:
		metadata_file.store_string(json_data)
		Log.info("Game saved with metadata")
		return true
	else:
		Log.err("Failed to save game metadata")
		return false

func load_game():
	if not FileAccess.file_exists(SAVE_DIR + SAVE_RESOURCE):
		Log.warn("No save resource found")
		return false
	
	var save_resource = ResourceLoader.load(SAVE_DIR + SAVE_RESOURCE, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not save_resource:
		Log.err("Failed to load save resource")
		return false
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if save_resource.has_meta("player_pos_x") and save_resource.has_meta("player_pos_y"):
			var pos_x = save_resource.get_meta("player_pos_x")
			var pos_y = save_resource.get_meta("player_pos_y")
			player.global_position = Vector2(pos_x, pos_y)
		
		if "health" in player and save_resource.has_meta("player_health"):
			player.health = save_resource.get_meta("player_health")
	
	var mission_manager = get_node_or_null("/root/MissionManager")
	if mission_manager:
		if save_resource.has_meta("current_mission"):
			mission_manager.current_mission = save_resource.get_meta("current_mission")
		
		if "completed_missions" in mission_manager and save_resource.has_meta("completed_missions"):
			mission_manager.completed_missions = save_resource.get_meta("completed_missions")
	
	Log.info("Game loaded from resource")
	return true

func has_save():
	return FileAccess.file_exists(SAVE_DIR + SAVE_RESOURCE)

func delete_save():
	var resource_path = SAVE_DIR + SAVE_RESOURCE
	var metadata_path = SAVE_DIR + METADATA_FILE
	
	var deleted = false
	
	if FileAccess.file_exists(resource_path):
		DirAccess.remove_absolute(resource_path)
		deleted = true
	
	if FileAccess.file_exists(metadata_path):
		DirAccess.remove_absolute(metadata_path)
		deleted = true
	
	if deleted:
		Log.info("Save data deleted")
	
	return deleted

func get_save_metadata():
	var metadata_path = SAVE_DIR + METADATA_FILE
	
	if not FileAccess.file_exists(metadata_path):
		return null
	
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		return null
	
	var json_text = file.get_as_text()
	var parse_result = JSON.parse_string(json_text)
	
	if parse_result != null:
		return parse_result
	else:
		Log.err("Failed to parse save metadata JSON")
		return null

func encrypt_save():
	if has_save():
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.rename(SAVE_RESOURCE, SAVE_RESOURCE + ".bak")
			
			var source_file = FileAccess.open(SAVE_DIR + SAVE_RESOURCE + ".bak", FileAccess.READ)
			var dest_file = FileAccess.open_encrypted_with_pass(SAVE_DIR + SAVE_RESOURCE, FileAccess.WRITE, ENCRYPTION_KEY)
			
			if source_file and dest_file:
				dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
				dir.remove(SAVE_RESOURCE + ".bak")
				Log.info("Save file encrypted")
				return true
			else:
				dir.rename(SAVE_RESOURCE + ".bak", SAVE_RESOURCE)
				Log.err("Failed to encrypt save file")
				return false
	
	return false

func decrypt_save():
	if has_save():
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.rename(SAVE_RESOURCE, SAVE_RESOURCE + ".enc")
			
			var source_file = FileAccess.open_encrypted_with_pass(SAVE_DIR + SAVE_RESOURCE + ".enc", FileAccess.READ, ENCRYPTION_KEY)
			var dest_file = FileAccess.open(SAVE_DIR + SAVE_RESOURCE, FileAccess.WRITE)
			
			if source_file and dest_file:
				dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
				dir.remove(SAVE_RESOURCE + ".enc")
				Log.info("Save file decrypted")
				return true
			else:
				dir.rename(SAVE_RESOURCE + ".enc", SAVE_RESOURCE)
				Log.err("Failed to decrypt save file")
				return false
	
	return false