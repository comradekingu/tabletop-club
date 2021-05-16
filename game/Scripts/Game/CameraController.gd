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

extends Spatial

enum {
	TOOL_CURSOR,
	TOOL_RULER,
	TOOL_HIDDEN_AREA,
	TOOL_PAINT,
	TOOL_ERASE
}

signal adding_cards_to_hand(cards, id) # If id is 0, add to nearest hand.
signal adding_pieces_to_container(container, pieces)
signal clipboard_paste(position)
signal clipboard_yank(pieces)
signal collect_pieces_requested(pieces)
signal container_release_random_requested(container, n)
signal container_release_these_requested(container, names)
signal dealing_cards(stack, n)
signal erasing(position, size)
signal hover_piece_requested(piece, offset)
signal painting(position, color, size)
signal placing_hidden_area(point1, point2)
signal pop_stack_requested(stack, n)
signal removing_hidden_area(hidden_area)
signal selecting_all_pieces()
signal setting_hidden_area_preview_points(point1, point2)
signal setting_hidden_area_preview_visible(is_visible)
signal setting_spawn_point(position)
signal spawning_piece_at(position)
signal spawning_piece_in_container(container_name)
signal stack_collect_all_requested(stack, collect_stacks)

onready var _box_selection_rect = $BoxSelectionRect
onready var _brush_color_picker = $PaintToolMenu/MarginContainer/VBoxContainer/BrushColorPickerButton
onready var _brush_size_label = $PaintToolMenu/MarginContainer/VBoxContainer/HBoxContainer/BrushSizeValueLabel
onready var _brush_size_slider = $PaintToolMenu/MarginContainer/VBoxContainer/HBoxContainer/BrushSizeValueSlider
onready var _camera = $Camera
onready var _camera_ui = $CameraUI
onready var _container_content_dialog = $ContainerContentDialog
onready var _control_hint_label = $CameraUI/ControlHintLabel
onready var _cursors = $CameraUI/Cursors
onready var _debug_info_label = $CameraUI/DebugInfoLabel
onready var _erase_tool_menu = $EraseToolMenu
onready var _eraser_size_label = $EraseToolMenu/MarginContainer/VBoxContainer/HBoxContainer/EraserSizeValueLabel
onready var _eraser_size_slider = $EraseToolMenu/MarginContainer/VBoxContainer/HBoxContainer/EraserSizeValueSlider
onready var _hand_preview_rect = $HandPreviewRect
onready var _paint_tool_menu = $PaintToolMenu
onready var _piece_context_menu = $PieceContextMenu
onready var _piece_context_menu_container = $PieceContextMenu/VBoxContainer
onready var _ruler_scale_slider = $RulerToolMenu/MarginContainer/VBoxContainer/HBoxContainer/RulerScaleSlider
onready var _ruler_scale_spin_box = $RulerToolMenu/MarginContainer/VBoxContainer/HBoxContainer/RulerScaleSpinBox
onready var _ruler_system_button = $RulerToolMenu/MarginContainer/VBoxContainer/SystemButton
onready var _ruler_tool_menu = $RulerToolMenu
onready var _rulers = $Rulers
onready var _track_dialog = $TrackDialog

const CURSOR_LERP_SCALE = 100.0
const GRABBING_SLOW_TIME = 0.25
const HOVER_Y_MIN = 1.0
const MOVEMENT_ACCEL_SCALAR = 0.125
const MOVEMENT_DECEL_SCALAR = 0.25
const RAY_LENGTH = 1000
const ROTATION_Y_MAX = -0.2
const ROTATION_Y_MIN = -1.5
const TIMER_UPDATE_INTERVAL = 0.5
const ZOOM_ACCEL_SCALAR = 3.0
const ZOOM_CAMERA_NEAR_SCALAR = 0.01
const ZOOM_DISTANCE_MIN = 2.0
const ZOOM_DISTANCE_MAX = 200.0

export(bool) var hand_preview_enabled: bool = true
export(float) var hand_preview_delay: float = 0.5
export(bool) var hold_left_click_to_move: bool = false
export(float) var lift_sensitivity: float = 1.0
export(float) var max_speed: float = 10.0
export(bool) var piece_rotate_invert: bool = false
export(float) var rotation_sensitivity_x: float = -0.01
export(float) var rotation_sensitivity_y: float = -0.01
export(float) var zoom_sensitivity: float = 1.0

var clipboard_contents: Dictionary = {}
var clipboard_yank_position: Vector3 = Vector3()
var send_cursor_position: bool = false

var _box_select_init_pos = Vector2()
var _color_picker: ColorPicker = null
var _container_multi_context: PieceContainer = null
var _cursor_on_table = false
var _cursor_position = Vector3()
var _drag_camera_anchor = Vector3()
var _future_clipboard_position = Vector3()
var _grabbing_time = 0.0
var _hidden_area_mouse_is_over: HiddenArea = null
var _hidden_area_placing_point2 = false
var _hidden_area_point1 = Vector3()
var _hidden_area_point2 = Vector3()
var _hover_y_offset = 0.0
var _hover_y_pos = 10.0
var _initial_transform = Transform.IDENTITY
var _initial_zoom = 0.0
var _is_box_selecting = false
var _is_dragging_camera = false
var _is_erasing = false
var _is_grabbing_selected = false
var _is_hovering_selected = false
var _is_painting = false
var _last_sent_cursor_position = Vector3()
var _move_down = false
var _move_left = false
var _move_right = false
var _move_up = false
var _movement_accel = 0.0
var _movement_dir = Vector3()
var _movement_vel = Vector3()
var _perform_box_select = false
var _piece_mouse_is_over: Piece = null
var _piece_mouse_is_over_last: Piece = null
var _piece_mouse_is_over_time: float = 0.0
var _piece_rotation_amount = 1.0
var _right_click_pos = Vector2()
var _rotation = Vector2()
var _ruler_placing_point2 = false
var _selected_pieces = []
var _send_erase_position = false
var _send_paint_position = false
var _spawn_point_position = Vector3()
var _speaker_connected: SpeakerPiece = null
var _speaker_track_label: Label = null
var _speaker_pause_button: Button = null
var _speaker_play_stop_button: Button = null
var _speaker_volume_awaiting_update = false
var _speaker_volume_slider: Slider = null
var _target_zoom = 0.0
var _timer_connected: TimerPiece = null
var _timer_countdown_time: TimeEdit = null
var _timer_last_time_update = 0
var _timer_pause_button: Button = null
var _timer_start_stop_countdown_button: Button = null
var _timer_start_stop_stopwatch_button: Button = null
var _timer_time_label: Label = null
var _tool = TOOL_CURSOR
var _viewport_size_original = Vector2()

# Append an array of pieces to the list of selected pieces.
# pieces: The array of pieces to now be selected.
func append_selected_pieces(pieces: Array) -> void:
	for piece in pieces:
		if piece is Piece and (not piece in _selected_pieces):
			# If a piece is not visible (e.g. if it is in a hidden area), do
			# not allow for it to be selected, otherwise players could just
			# select it and drag it out of the hidden area.
			if piece.visible:
				_selected_pieces.append(piece)
				
				var color = Color.white
				var player = Lobby.get_player(get_tree().get_network_unique_id())
				if player.has("color"):
					color = player["color"]
				piece.set_outline_color(color)

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_camera.fov = config.get_value("video", "fov")
	
	rotation_sensitivity_x = -0.1 * config.get_value("controls", "mouse_horizontal_sensitivity")
	if config.get_value("controls", "mouse_horizontal_invert"):
		rotation_sensitivity_x *= -1
	
	rotation_sensitivity_y = -0.1 * config.get_value("controls", "mouse_vertical_sensitivity")
	if config.get_value("controls", "mouse_vertical_invert"):
		rotation_sensitivity_y *= -1
	
	max_speed = 10.0 + 190.0 * config.get_value("controls", "camera_movement_speed")
	
	hold_left_click_to_move = config.get_value("controls", "left_click_to_move")
	
	zoom_sensitivity = 1.0 + 15.0 * config.get_value("controls", "zoom_sensitivity")
	if config.get_value("controls", "zoom_invert"):
		zoom_sensitivity *= -1
	
	lift_sensitivity = 0.5 + 4.5 * config.get_value("controls", "piece_lift_sensitivity")
	if config.get_value("controls", "piece_lift_invert"):
		lift_sensitivity *= -1
	
	piece_rotate_invert = config.get_value("controls", "piece_rotation_invert")
	
	hand_preview_enabled = config.get_value("controls", "hand_preview_enabled")
	hand_preview_delay = config.get_value("controls", "hand_preview_delay")
	_hand_preview_rect.rect_size.y = int(50 + 250 * config.get_value("controls", "hand_preview_size"))
	
	_control_hint_label.visible = not config.get_value("controls", "hide_control_hints")
	_cursors.visible = not config.get_value("multiplayer", "hide_cursors")

# Clear the list of selected pieces.
func clear_selected_pieces() -> void:
	for piece in _selected_pieces:
		piece.set_outline_color(Color.transparent)
	
	_selected_pieces.clear()

# Erase a piece from the list of selected pieces.
# piece: The piece to erase from the list.
func erase_selected_pieces(piece: Piece) -> void:
	if _selected_pieces.has(piece):
		_selected_pieces.erase(piece)
		piece.set_outline_color(Color.transparent)

# Get the current position that pieces should hover at, given the camera and
# mouse positions.
# Returns: The position that hovering pieces should hover at.
func get_hover_position() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var hover_pos = _calculate_hover_position(mouse_pos, _hover_y_pos)
	hover_pos.y += _hover_y_offset
	return hover_pos

# Get the list of selected pieces.
# Returns: The list of selected pieces.
func get_selected_pieces() -> Array:
	return _selected_pieces

# Request the server to set your cursor to the "grabbing" cursor on all other
# clients.
# grabbing: Whether the cursor should be the "grabbing" cursor.
master func request_set_cursor_grabbing(grabbing: bool) -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc("set_player_cursor_grabbing", id, grabbing)

# Request the server to set your 3D cursor position to all other players.
# position: Your new 3D cursor position.
# x_basis: The x-basis of your camera.
master func request_set_cursor_position(position: Vector3, x_basis: Vector3) -> void:
	var id = get_tree().get_rpc_sender_id()
	for other_id in Lobby.get_player_list():
		if other_id != id:
			rpc_unreliable_id(other_id, "set_player_cursor_position", id, position, x_basis)

# Set if the camera is hovering it's selected pieces.
# is_hovering: If the camera is hovering it's selected pieces.
func set_is_hovering(is_hovering: bool) -> void:
	_is_hovering_selected = is_hovering
	
	var cursor = Input.CURSOR_ARROW
	if is_hovering:
		cursor = Input.CURSOR_DRAG
		
		# If we have started hovering, we have stopped grabbing.
		_is_grabbing_selected = false
	
	Input.set_default_cursor_shape(cursor)
	
	rpc_id(1, "request_set_cursor_grabbing", is_hovering)

# Set the height the controller hovers pieces at.
# hover_height: The height pieces are hovered at by the controller.
remotesync func set_hover_height(hover_height: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_hover_y_pos = max(0, hover_height)

# Called by the server when a player updates their hovering state.
# id: The ID of the player.
# grabbing: Whether the cursor should be the "grabbing" shape.
remotesync func set_player_cursor_grabbing(id: int, grabbing: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	cursor.texture = _create_player_cursor_texture(id, grabbing)

# Called by the server when a player updates their 3D cursor position.
# id: The ID of the player.
# position: The position of the player's 3D cursor.
# x_basis: The x-basis of the player's camera.
remotesync func set_player_cursor_position(id: int, position: Vector3, x_basis: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	cursor.set_meta("cursor_position", position)
	cursor.set_meta("x_basis", x_basis)

# Set the controller's piece rotation amount.
# rotation_amount: The piece rotation amount in radians.
func set_piece_rotation_amount(rotation_amount: float) -> void:
	_piece_rotation_amount = min(max(rotation_amount, 0.0), 2 * PI)

# Set the list of selected pieces.
# pieces: The new list of selected pieces.
func set_selected_pieces(pieces: Array) -> void:
	clear_selected_pieces()
	append_selected_pieces(pieces)

func _ready():
	_viewport_size_original.x = ProjectSettings.get_setting("display/window/size/width")
	_viewport_size_original.y = ProjectSettings.get_setting("display/window/size/height")
	get_viewport().connect("size_changed", self, "_on_Viewport_size_changed")
	
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Get the initial transform and zoom of the camera so we can set it back
	# to these values later.
	_initial_transform = transform
	_initial_zoom = _camera.translation.z
	_reset_camera()

func _process(delta):
	_process_input(delta)
	_process_movement(delta)
	
	if _is_grabbing_selected:
		_grabbing_time += delta
		
		# Have we been grabbing this piece for a long time?
		if _grabbing_time > GRABBING_SLOW_TIME:
			_start_hovering_grabbed_piece(false)
	
	if _piece_mouse_is_over == _piece_mouse_is_over_last:
		_piece_mouse_is_over_time += delta
	else:
		_piece_mouse_is_over_time = 0.0
	_piece_mouse_is_over_last = _piece_mouse_is_over
	
	_hand_preview_rect.visible = false
	if hand_preview_enabled:
		if _piece_mouse_is_over_time > hand_preview_delay:
			if _piece_mouse_is_over is Card:
				if _piece_mouse_is_over.over_hand == get_tree().get_network_unique_id():
					if not _selected_pieces.has(_piece_mouse_is_over):
						_hand_preview_rect.visible = true
	
	if _hand_preview_rect.visible:
		var card_entry = _piece_mouse_is_over.piece_entry
		
		var texture_path_key = "texture_path"
		if _piece_mouse_is_over.transform.basis.y.y < 0.0:
			texture_path_key = "texture_path_1"
		var texture_path = card_entry[texture_path_key]
		
		var texture_changed = true
		if _hand_preview_rect.texture:
			if _hand_preview_rect.texture.resource_path == texture_path:
				texture_changed = false
		
		if texture_changed:
			_hand_preview_rect.texture = load(texture_path)
		
		var preview_height = _hand_preview_rect.rect_size.y
		var card_scale = card_entry["scale"]
		var aspect_ratio = card_scale.x / card_scale.z
		_hand_preview_rect.rect_size.x = aspect_ratio * preview_height
		
		var position = get_viewport().get_mouse_position()
		position.y -= preview_height
		_hand_preview_rect.rect_position = position
	
	# TODO: Only do this if the state of the camera changes.
	if _control_hint_label.visible:
		_set_control_hint_label()
	
	if _debug_info_label.visible:
		_set_debug_info_label()
	
	for cursor in _cursors.get_children():
		if cursor is TextureRect:
			if cursor.has_meta("cursor_position") and cursor.has_meta("x_basis"):
				var current_position = cursor.rect_position
				var target_position = _camera.unproject_position(cursor.get_meta("cursor_position"))
				cursor.rect_position = current_position.linear_interpolate(target_position, CURSOR_LERP_SCALE * delta)
				
				var our_basis = transform.basis.x.normalized()
				var their_basis = cursor.get_meta("x_basis").normalized()
				var cos_theta = our_basis.dot(their_basis)
				var cross = our_basis.cross(their_basis)
				var sin_theta = cross.length()
				if cross.y < 0:
					sin_theta = -sin_theta
				var target_theta = acos(cos_theta)
				# If the camera goes one way, the cursor needs to go the other
				# way. This is why the if statement isn't < 0.
				if sin_theta > 0:
					target_theta = -target_theta
				var current_theta = deg2rad(cursor.rect_rotation)
				cursor.rect_rotation = rad2deg(lerp_angle(current_theta, target_theta, CURSOR_LERP_SCALE * delta))
	
	if _ruler_placing_point2:
		var num_rulers = _rulers.get_child_count()
		if num_rulers > 0:
			var last_ruler = _rulers.get_child(num_rulers - 1)
			last_ruler.point2 = _cursor_position
		else:
			push_error("Placing point two of ruler, but no rulers exist!")
	
	for ruler in _rulers.get_children():
		ruler.update_ruler(_camera)
	
	if _hidden_area_placing_point2:
		_hidden_area_point2 = _cursor_position
		var point1_v2 = Vector2(_hidden_area_point1.x, _hidden_area_point1.z)
		var point2_v2 = Vector2(_hidden_area_point2.x, _hidden_area_point2.z)
		emit_signal("setting_hidden_area_preview_points", point1_v2, point2_v2)
	
	if _timer_connected:
		if _timer_time_label:
			_timer_last_time_update += delta
			if _timer_last_time_update > TIMER_UPDATE_INTERVAL:
				_timer_time_label.text = _timer_connected.get_time_string()
				_timer_last_time_update -= TIMER_UPDATE_INTERVAL

func _physics_process(_delta):
	# Perform a raycast out into the world from the camera.
	var mouse_pos = get_viewport().get_mouse_position()
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to)
	
	_cursor_on_table = result.has("collider")
	_hidden_area_mouse_is_over = null
	_piece_mouse_is_over = null
	
	if _cursor_on_table:
		_cursor_position = result["position"]
		if result.collider is Piece:
			_piece_mouse_is_over = result.collider
		
		var area_result = space_state.intersect_ray(from, to, [], 1, false, true)
		if area_result.has("collider"):
			if area_result.collider is HiddenArea:
				_hidden_area_mouse_is_over = area_result.collider
	
	if send_cursor_position and _cursor_position:
		if _cursor_position != _last_sent_cursor_position:
			if _is_hovering_selected and (not _selected_pieces.empty()):
				if _piece_mouse_is_over and _selected_pieces.has(_piece_mouse_is_over):
					_cursor_position = _piece_mouse_is_over.transform.origin
				else:
					var total = Vector3()
					for piece in _selected_pieces:
						total += piece.transform.origin
					_cursor_position = total / _selected_pieces.size()
			rpc_unreliable_id(1, "request_set_cursor_position", _cursor_position,
				transform.basis.x)
			_last_sent_cursor_position = _cursor_position
	
	if _perform_box_select:
		var query_params = PhysicsShapeQueryParameters.new()
		
		var box_rect = Rect2(_box_selection_rect.rect_position, _box_selection_rect.rect_size)
		
		# Create a frustum from the box position and size.
		var shape = ConvexPolygonShape.new()
		var points = []
		
		var middle = box_rect.position + box_rect.size / 2
		var box_from = _camera.project_ray_origin(middle)
		points.append(box_from)
		
		for dx in [0, 1]:
			for dy in [0, 1]:
				var size = Vector2(box_rect.size.x * dx, box_rect.size.y * dy)
				var box_pos = box_rect.position + size
				var box_to = box_from + _camera.project_ray_normal(box_pos) * RAY_LENGTH
				points.append(box_to)
		
		shape.points = points
		query_params.set_shape(shape)
		
		var results = space_state.intersect_shape(query_params, 1024)
		
		for box_result in results:
			if box_result.has("collider"):
				if box_result.collider is Piece:
					append_selected_pieces([box_result.collider])
		
		_perform_box_select = false
	
	if _send_paint_position:
		emit_signal("painting", _cursor_position, _brush_color_picker.color,
			_brush_size_slider.value)
		_send_paint_position = false
	
	if _send_erase_position:
		emit_signal("erasing", _cursor_position, _eraser_size_slider.value)
		_send_erase_position = false

func _process_input(_delta):
	
	# Calculating the direction the user wants to move parallel to the table.
	var movement_input = Vector2()
	
	if _move_left:
		movement_input.x -= 1
	if _move_right:
		movement_input.x += 1
	if _move_up:
		movement_input.y += 1
	if _move_down:
		movement_input.y -= 1
	
	movement_input = movement_input.normalized()
	
	_movement_dir = Vector3()
	
	# Moving side-to-side is fine, since the x basis should always be parallel
	# to the table...
	_movement_dir += transform.basis.x * movement_input.x
	
	# ... but we want to move forward along the horizontal plane parallel to
	# the table, and since we can move the camera to be looking at the table,
	# we need to adjust the z basis here.
	var z_basis = transform.basis.z
	z_basis.y = 0
	z_basis = z_basis.normalized()
	_movement_dir += -z_basis * movement_input.y
	
	var is_accelerating = _movement_dir.dot(_movement_vel) > 0
	
	_movement_accel = max_speed
	if is_accelerating:
		_movement_accel *= MOVEMENT_ACCEL_SCALAR
	else:
		_movement_accel *= MOVEMENT_DECEL_SCALAR

func _process_movement(delta):
	var target_vel = _movement_dir * max_speed
	var delta_vel = clamp(_movement_accel * delta, 0.0, 1.0)
	_movement_vel = _movement_vel.linear_interpolate(target_vel, delta_vel)
	
	# A global translation, as we want to move on the plane parallel to the
	# table, regardless of the direction we are facing.
	var old_translation = translation
	translation += _movement_vel * delta
	
	# If we ended up moving...
	if translation != old_translation:
		_on_moving()
	
	# Go towards the target zoom level.
	var target_offset = Vector3(0, 0, _target_zoom)
	var zoom_accel = zoom_sensitivity * ZOOM_ACCEL_SCALAR
	var zoom_delta = clamp(zoom_accel * delta, 0.0, 1.0)
	_camera.translation = _camera.translation.linear_interpolate(target_offset, zoom_delta)
	
	# Adjust the near value of the camera based on how far away the camera is
	# from the table. If the camera is really far away, it probably won't have
	# anything directly in front of it, so we can make the depth buffer more
	# accurate by having it cover a smaller area.
	_camera.near = clamp(ZOOM_CAMERA_NEAR_SCALAR * _target_zoom, 0.05, 2.0)

func _unhandled_input(event):
	if not Input.is_key_pressed(KEY_CONTROL):
		if event.is_action_pressed("game_left"):
			_move_left = true
		elif event.is_action_released("game_left"):
			_move_left = false
		
		elif event.is_action_pressed("game_right"):
			_move_right = true
		elif event.is_action_released("game_right"):
			_move_right = false
		
		elif event.is_action_pressed("game_up"):
			_move_up = true
		elif event.is_action_released("game_up"):
			_move_up = false
		
		elif event.is_action_pressed("game_down"):
			_move_down = true
		elif event.is_action_released("game_down"):
			_move_down = false
	
	if event.is_action_pressed("game_reset_camera"):
		_reset_camera()
	elif event.is_action_pressed("game_delete_piece"):
		_delete_selected_pieces()
	elif event.is_action_pressed("game_lock_piece"):
		var all_locked = true
		for piece in _selected_pieces:
			if piece is Piece:
				if not piece.is_locked():
					all_locked = false
					break
		if all_locked:
			_unlock_selected_pieces()
		else:
			_lock_selected_pieces()
	elif event.is_action_pressed("game_flip_piece"):
		for piece in _selected_pieces:
			if piece is Piece:
				piece.rpc_id(1, "flip_vertically")
	elif event.is_action_pressed("game_reset_piece"):
		for piece in _selected_pieces:
			if piece is Piece:
				piece.rpc_id(1, "reset_orientation")
	elif event.is_action_pressed("game_toggle_debug_info"):
		_debug_info_label.visible = not _debug_info_label.visible
	elif event.is_action_pressed("game_toggle_ui"):
		_camera_ui.visible = not _camera_ui.visible
	
	if event is InputEventKey:
		if event.pressed and event.control:
			if event.scancode == KEY_A:
				emit_signal("selecting_all_pieces")
			elif event.scancode == KEY_X:
				_future_clipboard_position = _cursor_position
				_cut_selected_pieces()
			elif event.scancode == KEY_C:
				_future_clipboard_position = _cursor_position
				_copy_selected_pieces()
			elif event.scancode == KEY_V:
				_future_clipboard_position = _cursor_position
				_paste_clipboard()
	
	# NOTE: Mouse events are caught by the MouseGrab node, see
	# _on_MouseGrab_gui_input().

# Calculate the hover position of a piece, given a mouse position on the screen.
# Returns: The hover position of a piece, based on the given mouse position.
# mouse_position: The mouse position on the screen.
# y_position: The y-position of the hover position.
func _calculate_hover_position(mouse_position: Vector2, y_position: float) -> Vector3:
	# Get vectors representing a raycast from the camera.
	var from = _camera.project_ray_origin(mouse_position)
	var to = from + _camera.project_ray_normal(mouse_position) * RAY_LENGTH
	
	# Figure out at which point along this line the piece should hover at,
	# given we want it to hover at a particular Y-level.
	var lambda = (y_position - from.y) / (to.y - from.y)
	
	var x = from.x + lambda * (to.x - from.x)
	var z = from.z + lambda * (to.z - from.z)
	
	return Vector3(x, y_position, z)

# Create a cursor texture representing a given player.
# Returns: A cursor texture representing a given player.
# id: The ID of the player.
# grabbing: If the cursor should be the "grabbing" cursor.
func _create_player_cursor_texture(id: int, grabbing: bool) -> ImageTexture:
	var cursor_image: Image = null
	if grabbing:
		cursor_image = preload("res://Images/GrabbingCursor.png")
	else:
		cursor_image = preload("res://Images/ArrowCursor.png")
	
	# Create a clone of the image, so we don't modify the original.
	var clone_image = Image.new()
	cursor_image.lock()
	clone_image.create_from_data(cursor_image.get_width(),
		cursor_image.get_height(), false, cursor_image.get_format(),
		cursor_image.get_data())
	cursor_image.unlock()
	
	# Get the player's color.
	var mask_color = Color.white
	if Lobby.player_exists(id):
		var player = Lobby.get_player(id)
		if player.has("color"):
			mask_color = player["color"]
			mask_color.a = 1.0
	
	# Perform a multiply operation on the image.
	clone_image.lock()
	for x in range(clone_image.get_width()):
		for y in range(clone_image.get_height()):
			var pixel = clone_image.get_pixel(x, y)
			clone_image.set_pixel(x, y, pixel * mask_color)
	clone_image.unlock()
	
	var new_texture = ImageTexture.new()
	new_texture.create_from_image(clone_image)
	return new_texture

# Copy the selected pieces to the clipboard.
func _copy_selected_pieces() -> void:
	_hide_context_menu()
	clipboard_yank_position = _future_clipboard_position
	emit_signal("clipboard_yank", _selected_pieces)

# Cut the selected pieces to the clipboard.
func _cut_selected_pieces() -> void:
	_copy_selected_pieces()
	_delete_selected_pieces()

# Delete the currently selected pieces from the game.
func _delete_selected_pieces() -> void:
	_hide_context_menu()
	# Go in reverse order, as we are removing the pieces as we go.
	for i in range(_selected_pieces.size() - 1, -1, -1):
		var piece = _selected_pieces[i]
		if piece is Piece:
			piece.rpc_id(1, "request_remove_self")

# Get the scale nessesary to make cursors appear the same size regardless of
# resolution.
# Returns: The scale.
func _get_cursor_scale() -> Vector2:
	var from = get_viewport().size
	var to = _viewport_size_original
	
	var out = Vector2(to.x / from.x, to.y / from.y)
	
	return out

# Get the inheritance of a piece, which is the array of classes represented as
# strings, that the piece is based on. The last element of the array should
# always represent the Piece class.
# Returns: The array of inheritance of the piece.
# piece: The piece to get the inheritance of.
func _get_piece_inheritance(piece: Piece) -> Array:
	var inheritance = []
	var script = piece.get_script()
	
	while script:
		inheritance.append(script.resource_path)
		script = script.get_base_script()
	
	return inheritance

# Hide the context menu.
func _hide_context_menu():
	_piece_context_menu.visible = false

# Check if an inheritance array has a particular class.
# Returns: If the queried class is in the inheritance array.
# inheritance: The inheritance array to check. Generated with
# _get_piece_inheritance.
# query: The class to query, as a string.
func _inheritance_has(inheritance: Array, query: String) -> bool:
	for piece_class in inheritance:
		if piece_class.ends_with("/" + query + ".gd"):
			return true
	return false

# Lock the currently selected pieces.
func _lock_selected_pieces() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_lock")

func _on_context_add_objects_pressed() -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is PieceContainer:
			emit_signal("spawning_piece_in_container", piece.name)

func _on_context_add_selected_pressed() -> void:
	_hide_context_menu()
	
	if _container_multi_context == null:
		return
	
	var pieces = []
	for piece in _selected_pieces:
		if piece != _container_multi_context:
			pieces.append(piece)
	
	emit_signal("adding_pieces_to_container", _container_multi_context, pieces)

func _on_context_collect_all_pressed() -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			emit_signal("stack_collect_all_requested", piece, true)

func _on_context_collect_individuals_pressed() -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			emit_signal("stack_collect_all_requested", piece, false)

func _on_context_collect_selected_pressed() -> void:
	_hide_context_menu()
	if _selected_pieces.size() > 1:
		emit_signal("collect_pieces_requested", _selected_pieces)

func _on_context_color_changed(color: Color) -> void:
	for piece in _selected_pieces:
		piece.rpc_unreliable_id(1, "request_set_albedo_color", color, true)

func _on_context_color_popup_closed() -> void:
	if _color_picker == null:
		return
	
	for piece in _selected_pieces:
		piece.rpc_id(1, "request_set_albedo_color", _color_picker.color, false)

func _on_context_copy_pressed() -> void:
	_copy_selected_pieces()

func _on_context_cut_pressed() -> void:
	_cut_selected_pieces()

func _on_context_deal_cards_pressed(n: int) -> void:
	_hide_context_menu()
	emit_signal("dealing_cards", _selected_pieces[0], n)

func _on_context_delete_pressed() -> void:
	_delete_selected_pieces()

func _on_context_lock_pressed() -> void:
	_lock_selected_pieces()

func _on_context_orient_down_pressed() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_orient_pieces", false)

func _on_context_orient_up_pressed() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_orient_pieces", true)

func _on_context_paste_pressed() -> void:
	_paste_clipboard()

func _on_context_peek_inside_pressed() -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is PieceContainer:
			_container_content_dialog.display_contents(piece)
			_container_content_dialog.popup_centered()

func _on_context_put_in_hand_pressed() -> void:
	_hide_context_menu()
	emit_signal("adding_cards_to_hand", _selected_pieces, get_tree().get_network_unique_id())

func _on_context_shuffle_pressed() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_shuffle")

func _on_context_sort_pressed() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_sort")

func _on_context_spawn_object_pressed() -> void:
	_hide_context_menu()
	emit_signal("spawning_piece_at", _spawn_point_position)

func _on_context_spawn_point_pressed() -> void:
	_hide_context_menu()
	emit_signal("setting_spawn_point", _spawn_point_position)

func _on_context_speaker_pause_pressed() -> void:
	if _speaker_connected:
		if _speaker_connected.is_track_paused():
			_speaker_connected.rpc_id(1, "request_resume_track")
		else:
			_speaker_connected.rpc_id(1, "request_pause_track")

func _on_context_speaker_play_stop_pressed() -> void:
	if _speaker_connected:
		if _speaker_connected.is_playing_track():
			_speaker_connected.rpc_id(1, "request_stop_track")
		else:
			_speaker_connected.rpc_id(1, "request_play_track")

func _on_context_speaker_select_track_pressed() -> void:
	_track_dialog.popup_centered()

func _on_context_speaker_volume_value_changed(value: float) -> void:
	if _speaker_connected:
		_speaker_volume_awaiting_update = true
		_speaker_connected.rpc_id(1, "request_set_unit_size", value)

func _on_context_take_top_pressed(n: int) -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			clear_selected_pieces()
			emit_signal("pop_stack_requested", piece, n)

func _on_context_take_out_pressed(n: int) -> void:
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is PieceContainer:
			clear_selected_pieces()
			emit_signal("container_release_random_requested", piece, n)

func _on_context_timer_pause_pressed() -> void:
	if _timer_connected:
		if _timer_connected.is_timer_paused():
			_timer_connected.rpc_id(1, "request_resume_timer")
		else:
			_timer_connected.rpc_id(1, "request_pause_timer")

func _on_context_timer_start_stop_countdown_pressed() -> void:
	if _timer_connected:
		if _timer_connected.get_mode() == TimerPiece.MODE_COUNTDOWN:
			_timer_connected.rpc_id(1, "request_stop_timer")
		else:
			var time = _timer_countdown_time.get_seconds()
			_timer_connected.rpc_id(1, "request_start_countdown", time)

func _on_context_timer_start_stop_stopwatch_pressed() -> void:
	if _timer_connected:
		if _timer_connected.get_mode() == TimerPiece.MODE_STOPWATCH:
			_timer_connected.rpc_id(1, "request_stop_timer")
		else:
			_timer_connected.rpc_id(1, "request_start_stopwatch")

func _on_context_unlock_pressed() -> void:
	_unlock_selected_pieces()

func _on_speaker_started_playing() -> void:
	_set_speaker_controls()

func _on_speaker_stopped_playing() -> void:
	_set_speaker_controls()

func _on_speaker_track_changed(_track_entry: Dictionary, _music: bool) -> void:
	_set_speaker_controls()

func _on_speaker_track_paused() -> void:
	_set_speaker_controls()

func _on_speaker_track_resumed() -> void:
	_set_speaker_controls()

func _on_speaker_unit_size_changed(_unit_size: float) -> void:
	if not _speaker_volume_awaiting_update:
		_set_speaker_controls()
	
	_speaker_volume_awaiting_update = false

func _on_timer_mode_changed(_new_mode: int) -> void:
	_set_timer_controls()

func _on_timer_paused() -> void:
	_set_timer_controls()

func _on_timer_resumed() -> void:
	_set_timer_controls()

# Paste the contents of the clipboard.
func _paste_clipboard() -> void:
	_hide_context_menu()
	
	if not clipboard_contents.empty():
		emit_signal("clipboard_paste", _future_clipboard_position)

# Popup the piece context menu.
func _popup_piece_context_menu() -> void:
	if _selected_pieces.size() == 0:
		return
	
	# Get the inheritance (e.g. Dice <- Piece) of the first piece in the array,
	# then reduce the inheritance down to the most common inheritance of all of
	# the pieces in the array.
	var inheritance = _get_piece_inheritance(_selected_pieces[0])
	
	for i in range(1, _selected_pieces.size()):
		if inheritance.size() <= 1:
			break
		
		var other_inheritance = _get_piece_inheritance(_selected_pieces[i])
		var cut_off = 0
		for piece_class in inheritance:
			if other_inheritance.has(piece_class):
				break
			cut_off += 1
		inheritance = inheritance.slice(cut_off, inheritance.size() - 1)
	
	# Populate the context menu, given the inheritance.
	for child in _piece_context_menu_container.get_children():
		_piece_context_menu_container.remove_child(child)
		child.queue_free()
	
	########
	# INFO #
	########
	
	if _inheritance_has(inheritance, "Stack"):
		
		# TODO: Figure out a way to update this label if the count changes.
		var count = 0
		for stack in _selected_pieces:
			count += stack.get_piece_count()
		
		var count_label = Label.new()
		count_label.text = tr("Count: %d") % count
		_piece_context_menu_container.add_child(count_label)
	
	################
	# MULTI-OBJECT #
	################
	
	_container_multi_context = null
	if _piece_mouse_is_over is PieceContainer:
		if _selected_pieces.size() > 1:
			var add_selected_button = Button.new()
			add_selected_button.text = tr("Add selected objects...")
			add_selected_button.connect("pressed", self, "_on_context_add_selected_pressed")
			_piece_context_menu_container.add_child(add_selected_button)
			
			_container_multi_context = _piece_mouse_is_over
	
	###########
	# LEVEL 2 #
	###########
	
	# If the pieces consist of both cards and stacks of cards, then the
	# inheritance should include the StackablePiece class.
	if _inheritance_has(inheritance, "StackablePiece"):
		var only_cards = true
		for piece in _selected_pieces:
			if not (piece is Card or (piece is Stack and piece.is_card_stack())):
				only_cards = false
				break
		
		if only_cards:
			var put_in_hand_button = Button.new()
			put_in_hand_button.text = tr("Put in hand")
			put_in_hand_button.connect("pressed", self, "_on_context_put_in_hand_pressed")
			_piece_context_menu_container.add_child(put_in_hand_button)
	
	if _inheritance_has(inheritance, "Stack"):
		if _selected_pieces.size() == 1:
			var collect_individuals_button = Button.new()
			collect_individuals_button.text = tr("Collect individuals")
			collect_individuals_button.connect("pressed", self, "_on_context_collect_individuals_pressed")
			_piece_context_menu_container.add_child(collect_individuals_button)
			
			var collect_all_button = Button.new()
			collect_all_button.text = tr("Collect all")
			collect_all_button.connect("pressed", self, "_on_context_collect_all_pressed")
			_piece_context_menu_container.add_child(collect_all_button)
			
			var stack = _selected_pieces[0]
			if stack.is_card_stack():
				var deal_button = SpinBoxButton.new()
				deal_button.button.text = tr("Deal X cards")
				deal_button.spin_box.prefix = "X ="
				deal_button.spin_box.min_value = 1
				deal_button.spin_box.max_value = stack.get_piece_count()
				deal_button.connect("pressed", self, "_on_context_deal_cards_pressed")
				_piece_context_menu_container.add_child(deal_button)
			
			var take_top_button = SpinBoxButton.new()
			take_top_button.button.text = tr("Take X off top")
			take_top_button.spin_box.prefix = "X ="
			take_top_button.spin_box.min_value = 1
			take_top_button.spin_box.max_value = stack.get_piece_count()
			take_top_button.connect("pressed", self, "_on_context_take_top_pressed")
			_piece_context_menu_container.add_child(take_top_button)
		
		var orient_up_button = Button.new()
		orient_up_button.text = tr("Orient all up")
		orient_up_button.connect("pressed", self, "_on_context_orient_up_pressed")
		_piece_context_menu_container.add_child(orient_up_button)
		
		var orient_down_button = Button.new()
		orient_down_button.text = tr("Orient all down")
		orient_down_button.connect("pressed", self, "_on_context_orient_down_pressed")
		_piece_context_menu_container.add_child(orient_down_button)
		
		var shuffle_button = Button.new()
		shuffle_button.text = tr("Shuffle")
		shuffle_button.connect("pressed", self, "_on_context_shuffle_pressed")
		_piece_context_menu_container.add_child(shuffle_button)
		
		var sort_button = Button.new()
		sort_button.text = tr("Sort")
		sort_button.connect("pressed", self, "_on_context_sort_pressed")
		_piece_context_menu_container.add_child(sort_button)
	
	elif _inheritance_has(inheritance, "TimerPiece"):
		if _selected_pieces.size() == 1:
			_timer_connected = _selected_pieces[0]
			_timer_connected.connect("mode_changed", self, "_on_timer_mode_changed")
			_timer_connected.connect("timer_paused", self, "_on_timer_paused")
			_timer_connected.connect("timer_resumed", self, "_on_timer_resumed")
			
			_timer_time_label = Label.new()
			_timer_time_label.align = Label.ALIGN_CENTER
			_piece_context_menu_container.add_child(_timer_time_label)
			
			_timer_pause_button = Button.new()
			_timer_pause_button.connect("pressed", self, "_on_context_timer_pause_pressed")
			_piece_context_menu_container.add_child(_timer_pause_button)
			
			var countdown_container = HBoxContainer.new()
			
			_timer_countdown_time = TimeEdit.new()
			countdown_container.add_child(_timer_countdown_time)
			
			_timer_start_stop_countdown_button = Button.new()
			_timer_start_stop_countdown_button.connect("pressed", self, "_on_context_timer_start_stop_countdown_pressed")
			countdown_container.add_child(_timer_start_stop_countdown_button)
			
			_piece_context_menu_container.add_child(countdown_container)
			
			_timer_start_stop_stopwatch_button = Button.new()
			_timer_start_stop_stopwatch_button.connect("pressed", self, "_on_context_timer_start_stop_stopwatch_pressed")
			_piece_context_menu_container.add_child(_timer_start_stop_stopwatch_button)
			
			_set_timer_controls()
			
			# Start updating the time label in _process().
			_timer_last_time_update = 0
	
	###########
	# LEVEL 1 #
	###########
	
	if _inheritance_has(inheritance, "StackablePiece"):
		if _selected_pieces.size() > 1:
			var collect_selected_button = Button.new()
			collect_selected_button.text = tr("Collect selected")
			collect_selected_button.connect("pressed", self, "_on_context_collect_selected_pressed")
			_piece_context_menu_container.add_child(collect_selected_button)
	
	elif _inheritance_has(inheritance, "PieceContainer"):
		if _selected_pieces.size() == 1:
			var add_button = Button.new()
			add_button.text = tr("Add objects...")
			add_button.connect("pressed", self, "_on_context_add_objects_pressed")
			_piece_context_menu_container.add_child(add_button)
			
			var peek_button = Button.new()
			peek_button.text = tr("Peek inside")
			peek_button.connect("pressed", self, "_on_context_peek_inside_pressed")
			_piece_context_menu_container.add_child(peek_button)
			
			var take_button = SpinBoxButton.new()
			take_button.button.text = tr("Take X out")
			take_button.spin_box.prefix = "X ="
			take_button.spin_box.min_value = 1
			# We don't set the maximum value here, as we don't want the player
			# knowing how many items are in the container.
			take_button.connect("pressed", self, "_on_context_take_out_pressed")
			_piece_context_menu_container.add_child(take_button)
	
	elif _inheritance_has(inheritance, "SpeakerPiece"):
		if _selected_pieces.size() == 1:
			_speaker_connected = _selected_pieces[0]
			_speaker_connected.connect("started_playing", self, "_on_speaker_started_playing")
			_speaker_connected.connect("stopped_playing", self, "_on_speaker_stopped_playing")
			_speaker_connected.connect("track_changed", self, "_on_speaker_track_changed")
			_speaker_connected.connect("track_paused", self, "_on_speaker_track_paused")
			_speaker_connected.connect("track_resumed", self, "_on_speaker_track_resumed")
			_speaker_connected.connect("unit_size_changed", self, "_on_speaker_unit_size_changed")
			
			_speaker_track_label = Label.new()
			_piece_context_menu_container.add_child(_speaker_track_label)
			
			var speaker_select_track_button = Button.new()
			speaker_select_track_button.text = tr("Select track")
			speaker_select_track_button.connect("pressed", self, "_on_context_speaker_select_track_pressed")
			_piece_context_menu_container.add_child(speaker_select_track_button)
			
			_speaker_play_stop_button = Button.new()
			_speaker_play_stop_button.connect("pressed", self, "_on_context_speaker_play_stop_pressed")
			_piece_context_menu_container.add_child(_speaker_play_stop_button)
			
			_speaker_pause_button = Button.new()
			_speaker_pause_button.connect("pressed", self, "_on_context_speaker_pause_pressed")
			_piece_context_menu_container.add_child(_speaker_pause_button)
			
			var volume_label = Label.new()
			volume_label.text = tr("Range:")
			_piece_context_menu_container.add_child(volume_label)
			
			_speaker_volume_slider = HSlider.new()
			_speaker_volume_slider.connect("value_changed", self, "_on_context_speaker_volume_value_changed")
			_piece_context_menu_container.add_child(_speaker_volume_slider)
			
			_set_speaker_controls()
	
	###########
	# LEVEL 0 #
	###########
	
	if _inheritance_has(inheritance, "Piece"):
		var all_albedo_color_exposed = true
		for piece in _selected_pieces:
			if not piece.is_albedo_color_exposed():
				all_albedo_color_exposed = false
				break
		
		if all_albedo_color_exposed:
			var color_label = Label.new()
			color_label.text = tr("Color:")
			_piece_context_menu_container.add_child(color_label)
			
			var color_button = ColorPickerButton.new()
			color_button.color = _selected_pieces[0].get_albedo_color()
			color_button.edit_alpha = false
			color_button.connect("color_changed", self, "_on_context_color_changed")
			color_button.connect("popup_closed", self, "_on_context_color_popup_closed")
			_piece_context_menu_container.add_child(color_button)
			
			_color_picker = color_button.get_picker()
		
		var cut_button = Button.new()
		cut_button.text = tr("Cut")
		cut_button.connect("pressed", self, "_on_context_cut_pressed")
		_piece_context_menu_container.add_child(cut_button)
		
		var copy_button = Button.new()
		copy_button.text = tr("Copy")
		copy_button.connect("pressed", self, "_on_context_copy_pressed")
		_piece_context_menu_container.add_child(copy_button)
		
		var paste_button = Button.new()
		paste_button.disabled = clipboard_contents.empty()
		paste_button.text = tr("Paste")
		paste_button.connect("pressed", self, "_on_context_paste_pressed")
		_piece_context_menu_container.add_child(paste_button)
		
		_future_clipboard_position = _cursor_position
		
		var num_locked = 0
		for piece in _selected_pieces:
			if piece.is_locked():
				num_locked += 1
		
		if num_locked == _selected_pieces.size():
			var unlock_button = Button.new()
			unlock_button.text = tr("Unlock")
			unlock_button.connect("pressed", self, "_on_context_unlock_pressed")
			_piece_context_menu_container.add_child(unlock_button)
		else:
			var lock_button = Button.new()
			lock_button.text = tr("Lock")
			lock_button.connect("pressed", self, "_on_context_lock_pressed")
			_piece_context_menu_container.add_child(lock_button)
		
		var delete_button = Button.new()
		delete_button.text = tr("Delete")
		delete_button.connect("pressed", self, "_on_context_delete_pressed")
		_piece_context_menu_container.add_child(delete_button)
	
	# We've connected a signal elsewhere that will change the size of the popup
	# to match the container.
	_piece_context_menu.rect_position = get_viewport().get_mouse_position()
	_piece_context_menu.popup()

# Popup the table context menu.
func _popup_table_context_menu() -> void:
	for child in _piece_context_menu_container.get_children():
		_piece_context_menu_container.remove_child(child)
		child.queue_free()
	
	var paste_button = Button.new()
	paste_button.disabled = clipboard_contents.empty()
	paste_button.text = tr("Paste")
	paste_button.connect("pressed", self, "_on_context_paste_pressed")
	_piece_context_menu_container.add_child(paste_button)
	
	_future_clipboard_position = _cursor_position
	
	var spawn_point_button = Button.new()
	spawn_point_button.text = tr("Set spawn point here")
	spawn_point_button.connect("pressed", self, "_on_context_spawn_point_pressed")
	_piece_context_menu_container.add_child(spawn_point_button)
	
	var spawn_object_button = Button.new()
	spawn_object_button.text = tr("Spawn object here")
	spawn_object_button.connect("pressed", self, "_on_context_spawn_object_pressed")
	_piece_context_menu_container.add_child(spawn_object_button)
	
	_piece_context_menu.rect_position = get_viewport().get_mouse_position()
	_piece_context_menu.popup()

# Reset the camera transform and zoom to their initial states.
func _reset_camera() -> void:
	transform = _initial_transform
	var euler = transform.basis.get_euler()
	_rotation = Vector2(euler.y, euler.x)
	
	_camera.translation.z = _initial_zoom
	_target_zoom = _initial_zoom

# Set the control hint label's text based on the camera's state.
func _set_control_hint_label() -> void:
	var text = "[right][table=2]"
	
	var alt     = tr("Alt + %s")
	var ctrl    = tr("Ctrl + %s")
	var hold    = tr("Hold %s")
	var release = tr("Release %s")
	
	var hovering = _is_hovering_selected or _is_grabbing_selected
	
	############
	# MOVEMENT #
	############
	var sw = tr("Scroll Wheel")
	
	if not hold_left_click_to_move:
		text += _set_control_hint_label_row_actions(tr("Move camera"),
			["game_up", "game_left", "game_down", "game_right"])
	
	if not hovering:
		text += _set_control_hint_label_row_actions(tr("Rotate camera"),
			["game_rotate"], tr("Hold %s + Move Mouse"))
		
		text += _set_control_hint_label_row(tr("Zoom camera"), sw)
	
	#####################
	# LEFT MOUSE BUTTON #
	#####################
	var lmb = tr("Left Mouse Button")
	
	if _tool == TOOL_CURSOR:
		
		if _is_hovering_selected:
			text += _set_control_hint_label_row(tr("Release selected"), lmb, release)
		elif _is_grabbing_selected:
			text += _set_control_hint_label_row(tr("Quick grab"), tr("Move Mouse"))
			text += _set_control_hint_label_row(tr("Stop grabbing"), lmb, release)
		elif _is_box_selecting:
			text += _set_control_hint_label_row(tr("Stop box selecting"), lmb, release)
		elif _piece_mouse_is_over:
			if not _piece_mouse_is_over in _selected_pieces:
				text += _set_control_hint_label_row(tr("Select object"), lmb)
				if not _selected_pieces.empty():
					text += _set_control_hint_label_row(tr("Add to selection"), lmb, ctrl)
			
			if _piece_mouse_is_over is PieceContainer:
				text += _set_control_hint_label_row(tr("Take random object"), lmb,
					tr("%s + Move Mouse"))
			elif _piece_mouse_is_over is Stack:
				text += _set_control_hint_label_row(tr("Take top object"), lmb,
					tr("%s + Move Mouse"))
			
			var name = tr("Grab selected") if _piece_mouse_is_over in _selected_pieces else tr("Grab object")
			text += _set_control_hint_label_row(name, lmb, hold)
		elif hold_left_click_to_move:
			var name = tr("Stop moving") if _is_dragging_camera else tr("Start moving")
			var mod  = release if _is_dragging_camera else hold
			text += _set_control_hint_label_row(name, lmb, mod)
		else:
			text += _set_control_hint_label_row(tr("Box select"), lmb, hold)
	
	elif _tool == TOOL_RULER:
		if _ruler_placing_point2:
			text += _set_control_hint_label_row(tr("Stop measuring"), lmb)
		else:
			text += _set_control_hint_label_row(tr("Start measuring"), lmb)
	
	elif _tool == TOOL_HIDDEN_AREA:
		if _hidden_area_placing_point2:
			text += _set_control_hint_label_row(tr("Create hidden area"), lmb)
		else:
			text += _set_control_hint_label_row(tr("Draw hidden area"), lmb)
	
	elif _tool == TOOL_PAINT:
		text += _set_control_hint_label_row(tr("Paint Table"), lmb, hold)
	
	elif _tool == TOOL_ERASE:
		text += _set_control_hint_label_row(tr("Erase Paint"), lmb, hold)
	
	######################
	# RIGHT MOUSE BUTTON #
	######################
	var rmb = tr("Right Mouse Button")
	
	if _tool == TOOL_CURSOR and (not hovering):
		
		if _piece_mouse_is_over:
			text += _set_control_hint_label_row(tr("Object menu"), rmb)
		elif _cursor_on_table:
			text += _set_control_hint_label_row(tr("Table menu"), rmb)
	
	elif _tool == TOOL_RULER:
		if _rulers.get_child_count() > 0:
			text += _set_control_hint_label_row(tr("Remove last ruler"), rmb)
	
	elif _tool == TOOL_HIDDEN_AREA:
		if _hidden_area_mouse_is_over:
			text += _set_control_hint_label_row(tr("Remove hidden area"), rmb)
	
	elif _tool == TOOL_PAINT:
		pass
	
	elif _tool == TOOL_ERASE:
		pass
	
	#########
	# OTHER #
	#########
	
	if not _selected_pieces.empty():
		if _is_hovering_selected:
			text += _set_control_hint_label_row_actions(tr("Flip orientation"),
				["game_flip_piece"])
			text += _set_control_hint_label_row_actions(tr("Reset orientation"),
				["game_reset_piece"])
			
			text += _set_control_hint_label_row(tr("Zoom selected"), sw)
			text += _set_control_hint_label_row(tr("Lift selected"), sw, ctrl)
			text += _set_control_hint_label_row(tr("Rotate selected"), sw, alt)
		
		var all_locked = true
		for piece in _selected_pieces:
			if piece is Piece:
				if not piece.is_locked():
					all_locked = false
					break
		var lock = tr("Unlock selected") if all_locked else tr("Lock selected")
		text += _set_control_hint_label_row_actions(lock, ["game_lock_piece"])
		
		text += _set_control_hint_label_row_actions(tr("Delete selected"),
			["game_delete_piece"])
	
	text += _set_control_hint_label_row_actions(tr("Reset camera"), ["game_reset_camera"])
	
	text += "[/table][/right]"
	
	# Make sure the label is flush with the bottom of the frame.
	var old_height = _control_hint_label.rect_size.y
	_control_hint_label.bbcode_text = ""
	# This doesn't actually set the height to 0, it just sets it to the
	# smallest height possible.
	_control_hint_label.rect_size.y = 0
	_control_hint_label.rect_position.y += old_height - _control_hint_label.rect_size.y
	_control_hint_label.bbcode_text = text

# Generate a row of text for the control hint label.
# Returns: A row of text formatted with BBCode.
# name: The name of the row.
# desc: The description of the row.
# mod: String to modify the row description - should contain one '%s'.
func _set_control_hint_label_row(name: String, desc: String, mod: String = "%s") -> String:
	return "[cell][b]%s:[/b][/cell][cell]%s[/cell]" % [name, mod % desc]

# Generate a row of text for the control hint label using an array of actions.
# Returns: A row of text formatted with BBCode.
# name: The name of the row.
# actions: An array of action strings, which will be converted into their input
# event bindings.
# mod: String to modify the row description - should contain one '%s'.
func _set_control_hint_label_row_actions(name: String, actions: Array,
	mod: String = "%s") -> String:
	
	var desc = ""
	var first = true
	for action in actions:
		if not first:
			desc += "/"
		desc += BindManager.get_action_input_event_text(action)
		first = false
	
	return _set_control_hint_label_row(name, desc, mod)

# Set the debug info label's text based on the state of the game.
func _set_debug_info_label() -> void:
	var text = ""
	
	#######################
	# GAME/ENGINE VERSION #
	#######################
	
	text += ProjectSettings.get_setting("application/config/name")
	if ProjectSettings.has_setting("application/config/version"):
		text += " " + ProjectSettings.get_setting("application/config/version")
	text += " (%s)\n" % ("Debug" if OS.is_debug_build() else "Release")
	
	text += "Godot %s\n" % Engine.get_version_info()["string"]
	
	##########
	# DEVICE #
	##########
	
	text += "Video Adapter: %s\n" % VisualServer.get_video_adapter_name()
	
	###############
	# PERFORMANCE #
	###############
	
	text += "FPS: %.0f\n" % Performance.get_monitor(Performance.TIME_FPS)
	text += "Frame Time: %.3fms\n" % (1000 * Performance.get_monitor(Performance.TIME_PROCESS))
	text += "Physics Frame Time: %.3fms\n" % (1000 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	
	###########
	# OBJECTS #
	###########
	
	text += "Objects: %.0f\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	text += "Resources: %.0f\n" % Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	text += "Nodes: %.0f\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	text += "Orphan Nodes: %.0f\n" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	###########
	# PHYSICS #
	###########
	
	text += "Physics Objects: %.0f\n" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	
	##########
	# MEMORY #
	##########
	
	if OS.is_debug_build():
		var static_used = Performance.get_monitor(Performance.MEMORY_STATIC)
		var static_max = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
		var dynamic_used = Performance.get_monitor(Performance.MEMORY_DYNAMIC)
		var dynamic_max = Performance.get_monitor(Performance.MEMORY_DYNAMIC_MAX)
		
		text += "Static Memory: %s/%s\n" % [String.humanize_size(static_used),
			String.humanize_size(static_max)]
		text += "Dynamic Memory: %s/%s\n" % [String.humanize_size(dynamic_used),
			String.humanize_size(dynamic_max)]
	
	var video_memory = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	text += "Video Memory: %s\n" % String.humanize_size(video_memory)
	
	###########
	# NETWORK #
	###########
	
	text += "Network ID: %d\n" % get_tree().get_network_unique_id()
	
	##########
	# CAMERA #
	##########
	
	var camera_pos = _camera.global_transform.origin
	text += "Camera Position: %s\n" % str(camera_pos)
	var camera_rot = (180.0 / PI) * _camera.global_transform.basis.get_euler()
	text += "Camera Rotation: %s\n" % str(camera_rot)
	text += "Cursor Position: %s\n" % str(_cursor_position)
	
	var cursor_over = "None"
	if _piece_mouse_is_over:
		var piece_name = _piece_mouse_is_over.name
		var piece_entry = _piece_mouse_is_over.piece_entry
		cursor_over = "Piece %s (%s)" % [piece_name, piece_entry["name"]]
	elif _hidden_area_mouse_is_over:
		var area_name = _hidden_area_mouse_is_over.name
		cursor_over = "Hidden Area %s" % area_name
	elif _cursor_on_table:
		cursor_over = "Table"
	text += "Cursor Over: %s\n" % cursor_over
	
	var hovering_text = "No"
	if _is_hovering_selected:
		hovering_text = "Yes %s" % str(get_hover_position())
	text += "Hovering: %s\n" % hovering_text
	
	_debug_info_label.text = text

# Set the properties of controls relating to the selected speaker.
func _set_speaker_controls() -> void:
	if _speaker_connected:
		if _speaker_pause_button:
			_speaker_pause_button.disabled = true
			_speaker_pause_button.text = tr("Pause track")
			
			if _speaker_connected.is_playing_track():
				_speaker_pause_button.disabled = false
				if _speaker_connected.is_track_paused():
					_speaker_pause_button.text = tr("Resume track")
		
		if _speaker_play_stop_button:
			if _speaker_connected.is_playing_track():
				_speaker_play_stop_button.text = tr("Stop track")
			else:
				_speaker_play_stop_button.text = tr("Play track")
		
		if _speaker_track_label:
			var track_entry = _speaker_connected.get_track()
			if track_entry.empty():
				_speaker_track_label.text = tr("No track loaded")
			elif _speaker_connected.is_playing_track():
				_speaker_track_label.text = tr("Playing: %s") % track_entry["name"]
			else:
				_speaker_track_label.text = tr("Loaded: %s") % track_entry["name"]
		
		if _speaker_volume_slider:
			_speaker_volume_slider.value = _speaker_connected.get_unit_size()

# Set the properties of controls relating to the selected timer.
func _set_timer_controls() -> void:
	if _timer_connected:
		if _timer_pause_button:
			_timer_pause_button.disabled = false
			_timer_pause_button.text = tr("Pause timer")
			
			if _timer_connected.get_mode() == TimerPiece.MODE_SYSTEM_TIME:
				_timer_pause_button.disabled = true
			elif _timer_connected.is_timer_paused():
				_timer_pause_button.text = tr("Resume timer")
		
		if _timer_start_stop_countdown_button:
			if _timer_connected.get_mode() == TimerPiece.MODE_COUNTDOWN:
				_timer_start_stop_countdown_button.text = tr("Stop countdown")
			else:
				_timer_start_stop_countdown_button.text = tr("Start countdown")
		
		if _timer_start_stop_stopwatch_button:
			if _timer_connected.get_mode() == TimerPiece.MODE_STOPWATCH:
				_timer_start_stop_stopwatch_button.text = tr("Stop stopwatch")
			else:
				_timer_start_stop_stopwatch_button.text = tr("Start stopwatch")
		
		if _timer_time_label:
			_timer_time_label.text = _timer_connected.get_time_string()

# Set the tool used by the player.
# new_tool: The tool to be used. See the TOOL_* enum for possible values.
func _set_tool(new_tool: int) -> void:
	if new_tool < TOOL_CURSOR or new_tool > TOOL_ERASE:
		push_error("Invalid argument for _set_tool!")
		return
	
	if new_tool == _tool:
		return
	
	clear_selected_pieces()
	
	_ruler_placing_point2 = false
	for ruler in _rulers.get_children():
		_rulers.remove_child(ruler)
		ruler.queue_free()
	
	emit_signal("setting_hidden_area_preview_visible", false)
	_hidden_area_placing_point2 = false
	
	_tool = new_tool

# Start hovering the grabbed pieces.
# fast: Did the user hover them quickly after grabbing them? If so, this may
# have differing behaviour, e.g. if the piece is a stack.
func _start_hovering_grabbed_piece(fast: bool) -> void:
	if _is_grabbing_selected:
		# NOTE: The server might not accept our request to hover a particular
		# piece, so we'll clear the list of selected pieces, and add the pieces
		# that are accepted back in to the list. For this reason, we'll need to
		# make a copy of the list.
		var selected = []
		for piece in _selected_pieces:
			selected.append(piece)
		
		clear_selected_pieces()
		
		# Now that there are no selected pieces, it's possible that the hand
		# preview shows up again - this is a workaround to prevent that.
		_piece_mouse_is_over_time = 0.0
		
		if not selected.empty():
			_hover_y_offset = 0
			
			# We can figure out if the selected pieces are about to be
			# obstructed with the new hover y-position, and adjust it
			# accordingly.
			for piece in selected:
				var from = piece.transform.origin
				var to = Vector3(from.x, -10, from.z)
				
				var space_state = get_world().direct_space_state
				var result = space_state.intersect_ray(from, to, [piece])
				
				if result.has("position"):
					# Calculate the minimum y-position the piece has to be in
					# in order to not be obstructed.
					var collision_point = result["position"]
					var min_y_pos = collision_point.y + (piece.get_size().y / 2)
					
					_hover_y_pos = max(_hover_y_pos, min_y_pos)
			
			var origin_piece = selected[0]
			if _piece_mouse_is_over:
				if selected.has(_piece_mouse_is_over):
					origin_piece = _piece_mouse_is_over
			var origin = origin_piece.transform.origin
			
			for piece in selected:
				if selected.size() == 1 and piece is Stack and fast:
					emit_signal("pop_stack_requested", piece, 1)
				elif selected.size() == 1 and piece is PieceContainer and fast:
					if piece.get_piece_count() == 0:
						emit_signal("hover_piece_requested", piece, Vector3())
					else:
						emit_signal("container_release_random_requested", piece, 1)
				else:
					var offset = piece.transform.origin - origin
					emit_signal("hover_piece_requested", piece, offset)
		
		_is_grabbing_selected = false

# Unlock the currently selected pieces.
func _unlock_selected_pieces() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_unlock")

# Called when the camera starts moving either positionally or rotationally.
func _on_moving() -> bool:
	# If we were grabbing a piece while moving...
	if _is_grabbing_selected:
		
		# ... then send out a signal to start hovering the piece fast.
		_start_hovering_grabbed_piece(true)
		return true
	
	# Or if we were hovering a piece already...
	if _is_hovering_selected:
		
		# Set the maximum hover y-position so the pieces don't go above and
		# behind the camera.
		var max_y_pos = _camera.global_transform.origin.y - HOVER_Y_MIN
		_hover_y_pos = min(_hover_y_pos, max_y_pos)
		
		# ... then send out a signal with the new hover position.
		for piece in _selected_pieces:
			piece.rpc_unreliable_id(1, "set_hover_position", get_hover_position())
		return true
	
	if _is_painting:
		_send_paint_position = true
		return true
	
	if _is_erasing:
		_send_erase_position = true
		return true
	
	return false

func _on_BrushSizeValueSlider_value_changed(value: float):
	_brush_size_label.text = str(value)

func _on_ContainerContentDialog_take_all_from(container: PieceContainer):
	_container_content_dialog.visible = false
	clear_selected_pieces()
	emit_signal("container_release_random_requested", container, container.get_piece_count())

func _on_ContainerContentDialog_take_from(container: PieceContainer, names: Array):
	_container_content_dialog.visible = false
	clear_selected_pieces()
	emit_signal("container_release_these_requested", container, names)

func _on_CursorToolButton_pressed():
	_set_tool(TOOL_CURSOR)

func _on_EraserSizeValueSlider_value_changed(value: float):
	_eraser_size_label.text = str(value)

func _on_EraseOKButton_pressed():
	_erase_tool_menu.visible = false

func _on_EraseToolButton_pressed():
	_set_tool(TOOL_ERASE)
	
	_erase_tool_menu.rect_position = get_viewport().get_mouse_position()
	_erase_tool_menu.rect_position.y -= _erase_tool_menu.rect_size.y
	_erase_tool_menu.popup()

func _on_HiddenAreaToolButton_pressed():
	_set_tool(TOOL_HIDDEN_AREA)

func _on_Lobby_player_added(id: int) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if _cursors.has_node(str(id)):
		return
	
	var cursor = TextureRect.new()
	cursor.name = str(id)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.rect_scale = _get_cursor_scale()
	cursor.texture = _create_player_cursor_texture(id, false)
	
	cursor.set_meta("cursor_position", Vector3())
	cursor.set_meta("x_basis", Vector3.RIGHT)
	
	_cursors.add_child(cursor)

func _on_Lobby_player_modified(id: int, _old: Dictionary) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	cursor.texture = _create_player_cursor_texture(id, false)

func _on_Lobby_player_removed(id: int) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if cursor:
		_cursors.remove_child(cursor)
		cursor.queue_free()

func _on_MouseGrab_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			
			if _tool == TOOL_CURSOR:
				if event.is_pressed():
					if _piece_mouse_is_over:
						if event.control:
							append_selected_pieces([_piece_mouse_is_over])
						else:
							if not _selected_pieces.has(_piece_mouse_is_over):
								set_selected_pieces([_piece_mouse_is_over])
							_is_grabbing_selected = true
							_grabbing_time = 0.0
					else:
						if not (event.control or _is_hovering_selected):
							clear_selected_pieces()
						
						if hold_left_click_to_move:
							# Start dragging the camera with the mouse.
							_drag_camera_anchor = _calculate_hover_position(event.position, 0.0)
							_is_dragging_camera = true
						else:
							# Start box selecting.
							_box_select_init_pos = event.position
							_is_box_selecting = true
							
							_box_selection_rect.rect_position = _box_select_init_pos
							_box_selection_rect.rect_size = Vector2()
							_box_selection_rect.visible = true
				else:
					_is_dragging_camera = false
					_is_grabbing_selected = false
					
					if _is_hovering_selected:
						var cards = []
						var adding_card_to_hand = false
						for piece in _selected_pieces:
							if piece.get("over_hand") != null:
								cards.append(piece)
								if piece.over_hand > 0:
									adding_card_to_hand = true
							piece.rpc_id(1, "stop_hovering")
						
						set_is_hovering(false)
						
						if adding_card_to_hand:
							emit_signal("adding_cards_to_hand", cards, 0)
					
					# Stop box selecting.
					if _is_box_selecting:
						_box_selection_rect.visible = false
						_is_box_selecting = false
						_perform_box_select = true
			
			elif _tool == TOOL_RULER:
				if event.is_pressed() and _cursor_on_table:
					if not _ruler_placing_point2:
						var ruler = preload("res://Scenes/Game/UI/RulerLine.tscn").instance()
						ruler.is_metric = (_ruler_system_button.selected == 0)
						ruler.point1 = _cursor_position
						ruler.point2 = ruler.point1
						ruler.scale = _ruler_scale_spin_box.value
						_rulers.add_child(ruler)
					
					_ruler_placing_point2 = not _ruler_placing_point2
			
			elif _tool == TOOL_HIDDEN_AREA:
				if event.is_pressed() and _cursor_on_table:
					if _hidden_area_placing_point2:
						var point1_v2 = Vector2(_hidden_area_point1.x, _hidden_area_point1.z)
						var point2_v2 = Vector2(_hidden_area_point2.x, _hidden_area_point2.z)
						emit_signal("placing_hidden_area", point1_v2, point2_v2)
					else:
						_hidden_area_point1 = _cursor_position
						_hidden_area_point2 = _hidden_area_point1
					
					_hidden_area_placing_point2 = not _hidden_area_placing_point2
					emit_signal("setting_hidden_area_preview_visible", _hidden_area_placing_point2)
			
			elif _tool == TOOL_PAINT:
				_is_painting = event.is_pressed()
			
			elif _tool == TOOL_ERASE:
				_is_erasing = event.is_pressed()
		
		elif event.button_index == BUTTON_RIGHT:
			if _is_hovering_selected:
				# TODO: Consider doing something here, like randomizing dice
				# or shuffling stacks?
				pass
			else:
				# Only bring up the context menu if the mouse didn't move
				# between the press and the release of the RMB.
				if event.is_pressed():
					_right_click_pos = event.position
					
					if _tool == TOOL_CURSOR:
						if _piece_mouse_is_over:
							if not _selected_pieces.has(_piece_mouse_is_over):
								if _piece_mouse_is_over is PieceContainer:
									append_selected_pieces([_piece_mouse_is_over])
								else:
									set_selected_pieces([_piece_mouse_is_over])
						else:
							clear_selected_pieces()
				else:
					if _tool == TOOL_CURSOR:
						if event.position == _right_click_pos:
							if _selected_pieces.empty():
								_popup_table_context_menu()
								_spawn_point_position = _cursor_position
								_spawn_point_position.y += Piece.SPAWN_HEIGHT
							else:
								_popup_piece_context_menu()
					
					elif _tool == TOOL_RULER:
						if event.position == _right_click_pos:
							var num_rulers = _rulers.get_child_count()
							if num_rulers > 0:
								var last_ruler = _rulers.get_child(num_rulers - 1)
								_rulers.remove_child(last_ruler)
								last_ruler.queue_free()
							
							_ruler_placing_point2 = false
					
					elif _tool == TOOL_HIDDEN_AREA:
						if event.position == _right_click_pos:
							if _hidden_area_mouse_is_over:
								emit_signal("removing_hidden_area", _hidden_area_mouse_is_over)
					
					elif _tool == TOOL_PAINT:
						pass
					
					elif _tool == TOOL_ERASE:
						pass
		
		elif event.is_pressed() and (event.button_index == BUTTON_WHEEL_UP or
			event.button_index == BUTTON_WHEEL_DOWN):
			
			if _is_hovering_selected:
				if event.alt:
					# Changing the rotation of the hovered pieces.
					var amount = _piece_rotation_amount
					if event.button_index == BUTTON_WHEEL_DOWN:
						amount *= -1
					if piece_rotate_invert:
						amount *= -1
					for piece in _selected_pieces:
						piece.rpc_id(1, "rotate_y", amount)
				else:
					# Changing the y-position/offset of hovered pieces.
					var offset = 0
					
					if event.button_index == BUTTON_WHEEL_UP:
						offset = -lift_sensitivity
					else:
						offset = lift_sensitivity
					
					if event.control:
						var new_y_offset = _hover_y_offset + offset
						if _hover_y_pos + new_y_offset >= HOVER_Y_MIN:
							_hover_y_offset = new_y_offset
					else:
						var new_y_pos = _hover_y_pos + offset
						_hover_y_pos = max(new_y_pos, HOVER_Y_MIN)
						_hover_y_offset = max(_hover_y_offset, HOVER_Y_MIN - _hover_y_pos)
					
					_on_moving()
			else:
				# Zooming the camera in and away from the controller.
				var offset = 0
				
				if event.button_index == BUTTON_WHEEL_UP:
					offset = -zoom_sensitivity
				else:
					offset = zoom_sensitivity
				
				var new_zoom = _target_zoom + offset
				_target_zoom = max(min(new_zoom, ZOOM_DISTANCE_MAX), ZOOM_DISTANCE_MIN)
			
			get_tree().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		# Check if by moving the mouse, we either started hovering a piece, or
		# we have moved the hovered pieces position.
		if _on_moving():
			pass
		
		elif Input.is_action_pressed("game_rotate"):
		
			# Rotating the controller-camera system to get the camera to rotate
			# around a point, where the controller is.
			_rotation.x += event.relative.x * rotation_sensitivity_x
			_rotation.y += event.relative.y * rotation_sensitivity_y
			
			# Bound the rotation along the X axis.
			_rotation.y = max(_rotation.y, ROTATION_Y_MIN)
			_rotation.y = min(_rotation.y, ROTATION_Y_MAX)
			
			transform.basis = Basis()
			rotate_x(_rotation.y)
			rotate_y(_rotation.x)
			
			get_tree().set_input_as_handled()
		
		elif _is_dragging_camera:
			var new_anchor = _calculate_hover_position(event.position, 0.0)
			var diff_anchor = new_anchor - _drag_camera_anchor
			translation -= diff_anchor
		
		elif _is_box_selecting:
			
			var pos = _box_select_init_pos
			var size = event.position - _box_select_init_pos
			
			if size.x < 0:
				pos.x += size.x
				size.x = -size.x
			
			if size.y < 0:
				pos.y += size.y
				size.y = -size.y
			
			_box_selection_rect.rect_position = pos
			_box_selection_rect.rect_size = size
			
			get_tree().set_input_as_handled()

func _on_PaintOKButton_pressed():
	_paint_tool_menu.visible = false

func _on_PaintToolButton_pressed():
	_set_tool(TOOL_PAINT)
	
	_paint_tool_menu.rect_position = get_viewport().get_mouse_position()
	_paint_tool_menu.rect_position.y -= _paint_tool_menu.rect_size.y
	_paint_tool_menu.popup()

func _on_PieceContextMenu_popup_hide():
	# Any variables that were potentially set if the object was a timer need
	# to be reset.
	if _timer_connected:
		_timer_connected.disconnect("mode_changed", self, "_on_timer_mode_changed")
		_timer_connected.disconnect("timer_paused", self, "_on_timer_paused")
		_timer_connected.disconnect("timer_resumed", self, "_on_timer_resumed")
	_timer_connected = null
	
	_timer_countdown_time = null
	_timer_pause_button = null
	_timer_start_stop_countdown_button = null
	_timer_start_stop_stopwatch_button = null
	_timer_time_label = null
	
	# Any variables that were potentially set if the object was a speaker need
	# to be reset.
	if _speaker_connected:
		_speaker_connected.disconnect("started_playing", self, "_on_speaker_started_playing")
		_speaker_connected.disconnect("stopped_playing", self, "_on_speaker_stopped_playing")
		_speaker_connected.disconnect("track_changed", self, "_on_speaker_track_changed")
		_speaker_connected.disconnect("track_paused", self, "_on_speaker_track_paused")
		_speaker_connected.disconnect("track_resumed", self, "_on_speaker_track_resumed")
		_speaker_connected.disconnect("unit_size_changed", self, "_on_speaker_unit_size_changed")
	_speaker_connected = null
	
	_speaker_pause_button = null
	_speaker_play_stop_button = null
	_speaker_track_label = null
	_speaker_volume_slider = null

func _on_RulerOKButton_pressed():
	_ruler_tool_menu.visible = false

func _on_RulerScaleSlider_value_changed(value: float):
	_ruler_scale_spin_box.value = value

func _on_RulerScaleSpinBox_value_changed(value: float):
	_ruler_scale_slider.value = value

func _on_RulerToolButton_pressed():
	_set_tool(TOOL_RULER)
	
	_ruler_tool_menu.rect_position = get_viewport().get_mouse_position()
	_ruler_tool_menu.rect_position.y -= _ruler_tool_menu.rect_size.y
	_ruler_tool_menu.popup()

func _on_TrackDialog_entry_requested(_pack: String, type: String, entry: Dictionary):
	_track_dialog.visible = false
	if _speaker_connected:
		var music = (type == "MUSIC")
		_speaker_connected.rpc_id(1, "request_set_track", entry, music)
	else:
		push_warning("Don't know which speaker to set track for, doing nothing.")

func _on_VBoxContainer_item_rect_changed():
	if _piece_context_menu and _piece_context_menu_container:
		var size = _piece_context_menu_container.rect_size
		size.x += _piece_context_menu_container.margin_left
		size.y += _piece_context_menu_container.margin_top
		size.x -= _piece_context_menu_container.margin_right
		size.y -= _piece_context_menu_container.margin_bottom
		_piece_context_menu.rect_min_size = size
		_piece_context_menu.rect_size = size

func _on_Viewport_size_changed():
	# Scale the cursors so they always appear the same size, regardless of the
	# window resolution.
	for cursor in _cursors.get_children():
		if cursor is TextureRect:
			cursor.rect_scale = _get_cursor_scale()
