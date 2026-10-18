extends Node

## Manages Google Play Games Services authentication and leaderboards.
## Leaderboard ID: CgkIgsuN5fIZEAIQAA
## Project ID: 889807136130

signal authenticated(success: bool)
signal score_submitted(success: bool, leaderboard_id: String)
signal leaderboard_status_changed(message: String)

const LEADERBOARD_ID := "CgkIgsuN5fIZEAIQAA"
const PROJECT_ID := "889807136130"

const _SignInClient := preload("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd")
const _LeaderboardsClient := preload("res://addons/GodotPlayGameServices/scripts/leaderboards/leaderboards_client.gd")

var is_authenticated: bool = false
var is_plugin_available: bool = false

var _sign_in_client: Node
var _leaderboards_client: Node
var _pending_score: int = -1
var _pending_show_leaderboard: bool = false
var _is_signing_in: bool = false


func _ready() -> void:
	_init_services()


func _init_services() -> void:
	if Engine.has_singleton("GodotPlayGameServices"):
		var err = GodotPlayGameServices.initialize()
		if err == GodotPlayGameServices.PlayGamesPluginError.OK:
			is_plugin_available = true
			print("[LeaderboardManager] GodotPlayGameServices initialized successfully.")
		else:
			print("[LeaderboardManager] GodotPlayGameServices initialization failed.")
	else:
		print("[LeaderboardManager] GodotPlayGameServices singleton not found (running in editor or desktop).")

	# Instantiate helper clients
	_sign_in_client = _SignInClient.new()
	add_child(_sign_in_client)
	_sign_in_client.user_authenticated.connect(_on_user_authenticated)

	_leaderboards_client = _LeaderboardsClient.new()
	add_child(_leaderboards_client)
	_leaderboards_client.score_submitted.connect(_on_score_submitted)

	if is_plugin_available:
		# Check if already authenticated at startup (Play Games v2 sign-in is automatic)
		_sign_in_client.is_authenticated()


func _on_user_authenticated(success: bool) -> void:
	is_authenticated = success
	_is_signing_in = false
	print("[LeaderboardManager] User authenticated: %s" % str(success))
	authenticated.emit(success)

	if success:
		# If there was a score waiting while authentication finished, submit it now
		if _pending_score >= 0:
			var score_to_submit := _pending_score
			_pending_score = -1
			submit_score(score_to_submit)

		# If user requested to view the leaderboard while unauthenticated, show it now
		if _pending_show_leaderboard:
			_pending_show_leaderboard = false
			leaderboard_status_changed.emit("OPENING LEADERBOARD...")
			# Brief delay to allow sign-in overlay to fully dismiss and return window focus
			await get_tree().create_timer(0.35).timeout
			_display_leaderboard_internal()
	else:
		if _pending_show_leaderboard:
			_pending_show_leaderboard = false
			leaderboard_status_changed.emit("SIGN-IN REQUIRED FOR LEADERBOARDS")


func _on_score_submitted(success: bool, leaderboard_id: String) -> void:
	print("[LeaderboardManager] Score submitted: %s (Leaderboard: %s)" % [str(success), leaderboard_id])
	score_submitted.emit(success, leaderboard_id)


## Submit a score to Google Play Games leaderboard
func submit_score(score: int) -> void:
	if score <= 0:
		return

	if not is_plugin_available:
		print("[LeaderboardManager (Simulated)] Score %d submitted to leaderboard %s" % [score, LEADERBOARD_ID])
		score_submitted.emit(true, LEADERBOARD_ID)
		return

	if is_authenticated:
		print("[LeaderboardManager] Submitting score %d to leaderboard %s" % [score, LEADERBOARD_ID])
		_leaderboards_client.submit_score(LEADERBOARD_ID, score)
	else:
		# Save pending score and try signing in
		_pending_score = max(_pending_score, score)
		print("[LeaderboardManager] Not yet authenticated, queued score %d for submission" % score)
		sign_in()


## Show the Play Games Leaderboard overlay
func show_leaderboard() -> void:
	if not is_plugin_available:
		print("[LeaderboardManager (Simulated)] Showing leaderboard %s" % LEADERBOARD_ID)
		leaderboard_status_changed.emit("PLAY GAMES NOT AVAILABLE")
		return

	if is_authenticated:
		leaderboard_status_changed.emit("OPENING LEADERBOARD...")
		_display_leaderboard_internal()
	else:
		_pending_show_leaderboard = true
		leaderboard_status_changed.emit("CONNECTING TO PLAY GAMES...")
		print("[LeaderboardManager] Requesting sign-in before showing leaderboard...")
		sign_in()
		# Safety timeout to avoid hanging pending state indefinitely
		get_tree().create_timer(10.0).timeout.connect(func():
			if _pending_show_leaderboard:
				_pending_show_leaderboard = false
				_is_signing_in = false
		)


func _display_leaderboard_internal() -> void:
	if _leaderboards_client != null:
		_leaderboards_client.show_leaderboard(LEADERBOARD_ID)


## Show all leaderboards configured for the project
func show_all_leaderboards() -> void:
	if not is_plugin_available:
		print("[LeaderboardManager (Simulated)] Showing all leaderboards")
		leaderboard_status_changed.emit("PLAY GAMES NOT AVAILABLE")
		return

	if is_authenticated:
		leaderboard_status_changed.emit("OPENING LEADERBOARDS...")
		_leaderboards_client.show_all_leaderboards()
	else:
		_pending_show_leaderboard = true
		leaderboard_status_changed.emit("CONNECTING TO PLAY GAMES...")
		sign_in()
		get_tree().create_timer(10.0).timeout.connect(func():
			if _pending_show_leaderboard:
				_pending_show_leaderboard = false
				_is_signing_in = false
		)


## Manually trigger sign-in dialog
func sign_in() -> void:
	if is_plugin_available:
		if _is_signing_in:
			return
		_is_signing_in = true
		_sign_in_client.sign_in()
