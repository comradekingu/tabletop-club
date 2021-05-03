# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends Node

enum {
	MODE_NONE,
	MODE_ERROR,
	MODE_CLIENT,
	MODE_SERVER,
	MODE_SINGLEPLAYER
}

const LOADING_BLOCK_TIME = 20

var system_locale: String = ""

var _current_scene: Node = null
var _loader: ResourceInteractiveLoader = null
var _loader_args: Dictionary = {}
var _wait_frames = 0

# Restart the game.
func restart_game() -> void:
	call_deferred("_terminate_peer")
	_goto_scene(ProjectSettings.get_setting("application/run/main_scene"), {
		"mode": MODE_NONE
	})

# Start the game as a client.
# server: The server to connect to.
# port: The port to connect to.
func start_game_as_client(server: String, port: int) -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_CLIENT,
		"server": server,
		"port": port
	})

# Start the game as a server.
# max_players: The maximum number of allowed players.
# port: The port to host the server on.
func start_game_as_server(max_players: int, port: int) -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_SERVER,
		"max_players": max_players,
		"port": port
	})

# Start the game in singleplayer mode.
func start_game_singleplayer() -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_SINGLEPLAYER
	})

# Start the main menu.
func start_main_menu() -> void:
	call_deferred("_terminate_peer")
	_goto_scene("res://Scenes/MainMenu.tscn", {
		"mode": MODE_NONE
	})

# Start the main menu, and display an error message.
# error: The error message to display.
func start_main_menu_with_error(error: String) -> void:
	call_deferred("_terminate_peer")
	_goto_scene("res://Scenes/MainMenu.tscn", {
		"mode": MODE_ERROR,
		"error": error
	})

func _ready():
	var root = get_tree().get_root()
	_current_scene = root.get_child(root.get_child_count() - 1)
	
	set_process(false)
	
	# We're assuming the locale hasn't been modified yet.
	system_locale = TranslationServer.get_locale()

func _process(_delta):
	if _loader == null:
		set_process(false)
		return
	
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	
	var time = OS.get_ticks_msec()
	while OS.get_ticks_msec() < time + LOADING_BLOCK_TIME:
		var err = _loader.poll()
		
		if err == ERR_FILE_EOF:
			var scene = _loader.get_resource()
			call_deferred("_set_scene", scene.instance(), _loader_args)
			
			_loader = null
			_loader_args = {}
			break
		elif err == OK:
			# The current scene should be the loading scene, so we should be
			# able to update the progress it is displaying.
			var progress = 0.0
			var stages = _loader.get_stage_count()
			if stages > 0:
				progress = float(_loader.get_stage()) / stages
			_current_scene.set_progress(progress)
		else:
			push_error("Loader encountered an error (error code %d)!" % err)
			_loader = null
			break

# Go to a given scene, with a set of arguments.
# path: The file path of the scene to load.
# args: The arguments for the scene to use after it has loaded.
func _goto_scene(path: String, args: Dictionary) -> void:
	# Create the interactive loader for the new scene.
	_loader = ResourceLoader.load_interactive(path)
	if _loader == null:
		push_error("Failed to create loader for '%s'!" % path)
		return
	_loader_args = args
	
	# Load the loading scene so the player can see the progress in loading the
	# new scene.
	var loading_scene = preload("res://Scenes/Loading.tscn").instance()
	call_deferred("_set_scene", loading_scene, { "mode": MODE_NONE })
	
	set_process(true)
	_wait_frames = 1

# Immediately set the scene tree's current scene.
# NOTE: This function should be called via call_deferred, since it will free
# the existing scene.
# scene: The scene to load.
# args: The arguments for the scene to use after it has loaded.
func _set_scene(scene: Node, args: Dictionary) -> void:
	if not args.has("mode"):
		push_error("Scene argument 'mode' is missing!")
		return
	
	if not args["mode"] is int:
		push_error("Scene argument 'mode' is not an integer!")
		return
	
	match args["mode"]:
		MODE_NONE:
			pass
		
		MODE_ERROR:
			if not args.has("error"):
				push_error("Scene argument 'error' is missing!")
				return
			
			if not args["error"] is String:
				push_error("Scene argument 'error' is not a string!")
				return
		
		MODE_CLIENT:
			if not args.has("server"):
				push_error("Scene argument 'server' is missing!")
				return
			
			if not args["server"] is String:
				push_error("Scene argument 'server' is not a string!")
				return
			
			if not args.has("port"):
				push_error("Scene argument 'port' is missing!")
				return
			
			if not args["port"] is int:
				push_error("Scene argument 'port' is not an integer!")
				return
		
		MODE_SERVER:
			if not args.has("max_players"):
				push_error("Scene argument 'max_players' is missing!")
				return
			
			if not args["max_players"] is int:
				push_error("Scene argument 'max_players' is not an integer!")
				return
			
			if not args.has("port"):
				push_error("Scene argument 'port' is missing!")
				return
			
			if not args["port"] is int:
				push_error("Scene argument 'port' is not an integer!")
				return
		
		MODE_SINGLEPLAYER:
			pass
		
		_:
			push_error("Invalid mode " + str(args["mode"]) + "!")
			return
	
	var root = get_tree().get_root()
	
	# Free the current scene - this should not be done during the main loop!
	root.remove_child(_current_scene)
	_current_scene.free()
	
	PieceBuilder.free_cache()
	
	root.add_child(scene)
	get_tree().set_current_scene(scene)
	_current_scene = scene
	
	match args["mode"]:
		MODE_ERROR:
			_current_scene.display_error(args["error"])
		MODE_CLIENT:
			_current_scene.init_client(args["server"], args["port"])
		MODE_SERVER:
			_current_scene.init_server(args["max_players"], args["port"])
		MODE_SINGLEPLAYER:
			_current_scene.init_singleplayer()

# Terminate the network peer if it exists.
# NOTE: This function should be called via call_deferred.
func _terminate_peer() -> void:
	# TODO: Send a message to say we are leaving first.
	get_tree().network_peer = null
