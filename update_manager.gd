extends Node

## Manages checking for game updates from Google Play Store / remote version endpoint
## Package: com.psygames.musicsquare
## Current Release: 1.0.5 (versionCode: 6)

signal update_available(version_info: Dictionary)
signal update_check_completed(has_update: bool)

const CURRENT_VERSION_NAME: String = "1.0.5"
const CURRENT_VERSION_CODE: int = 6
const PACKAGE_NAME: String = "com.psygames.musicsquare"
const STORE_MARKET_URI: String = "market://details?id=com.psygames.musicsquare"
const STORE_WEB_URL: String = "https://play.google.com/store/apps/details?id=com.psygames.musicsquare"

const VERSION_URL_PRIMARY: String = "https://psyman20.github.io/version.json"
const VERSION_URL_FALLBACK: String = "https://raw.githubusercontent.com/Psyman20/Psyman20.github.io/main/version.json"

var is_update_available: bool = false
var latest_version_info: Dictionary = {}
var is_checking: bool = false
var has_checked: bool = false

var _http_request: HTTPRequest = null
var _using_fallback: bool = false


func _ready() -> void:
	_setup_http_node()


func _setup_http_node() -> void:
	if _http_request == null:
		_http_request = HTTPRequest.new()
		_http_request.name = "UpdateCheckHTTP"
		_http_request.timeout = 5.0
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)


func check_for_updates(force_refresh: bool = false) -> void:
	if is_checking:
		return
	if has_checked and not force_refresh:
		if is_update_available:
			update_available.emit(latest_version_info)
		update_check_completed.emit(is_update_available)
		return

	is_checking = true
	_using_fallback = false
	_make_request(VERSION_URL_PRIMARY)


func _make_request(url: String) -> void:
	if _http_request == null:
		_setup_http_node()

	# Add cache-busting headers to bypass stale CDN caches
	var headers := [
		"User-Agent: MusicSquare-Godot",
		"Accept: application/json",
		"Cache-Control: no-cache, no-store, must-revalidate",
		"Pragma: no-cache"
	]
	var err := _http_request.request(url, headers)
	if err != OK:
		print("[UpdateManager] Failed to start request to: ", url)
		_on_fetch_failed()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json_str := body.get_string_from_utf8()
		var json := JSON.new()
		var parse_err := json.parse(json_str)
		if parse_err == OK and typeof(json.data) == TYPE_DICTIONARY:
			_process_version_data(json.data)
			return

	print("[UpdateManager] Response code: %d, result: %d" % [response_code, result])
	_on_fetch_failed()


func _on_fetch_failed() -> void:
	if not _using_fallback:
		_using_fallback = true
		print("[UpdateManager] Primary endpoint failed. Retrying with fallback: ", VERSION_URL_FALLBACK)
		_make_request(VERSION_URL_FALLBACK)
	else:
		is_checking = false
		has_checked = true
		print("[UpdateManager] Update check completed: offline or endpoint unreachable.")
		update_check_completed.emit(false)


func _process_version_data(data: Dictionary) -> void:
	is_checking = false
	has_checked = true
	latest_version_info = data

	var remote_code: int = int(data.get("version_code", 0))
	var remote_version: String = str(data.get("latest_version", ""))

	# Authoritative check: Google Play versionCode integer
	var update_needed: bool = false
	if remote_code > CURRENT_VERSION_CODE:
		update_needed = true
	elif remote_code == 0 and not remote_version.is_empty():
		# Fallback: Semver string comparison
		update_needed = _is_newer_semver(remote_version, CURRENT_VERSION_NAME)

	is_update_available = update_needed

	if is_update_available:
		print("[UpdateManager] Update available! Local: %s (%d) -> Remote: %s (%d)" % [
			CURRENT_VERSION_NAME, CURRENT_VERSION_CODE, remote_version, remote_code
		])
		update_available.emit(latest_version_info)
	else:
		print("[UpdateManager] Game is up to date: v%s (%d)" % [CURRENT_VERSION_NAME, CURRENT_VERSION_CODE])

	update_check_completed.emit(is_update_available)


func _is_newer_semver(remote: String, local: String) -> bool:
	var r_parts := remote.split(".")
	var l_parts := local.split(".")
	for i in range(maxi(r_parts.size(), l_parts.size())):
		var r_num := int(r_parts[i]) if i < r_parts.size() else 0
		var l_num := int(l_parts[i]) if i < l_parts.size() else 0
		if r_num > l_num:
			return true
		elif r_num < l_num:
			return false
	return false


func open_store_page() -> void:
	print("[UpdateManager] Opening Google Play Store for: ", PACKAGE_NAME)
	if OS.get_name() == "Android":
		var err := OS.shell_open(STORE_MARKET_URI)
		if err != OK:
			OS.shell_open(STORE_WEB_URL)
	else:
		OS.shell_open(STORE_WEB_URL)


## Simulation helper for testing in debug/editor mode
func simulate_update_available(test_version: String = "1.0.6", test_notes: String = "• Testing update modal!\n• New songs and features.") -> void:
	var test_data: Dictionary = {
		"latest_version": test_version,
		"version_code": CURRENT_VERSION_CODE + 1,
		"release_notes": test_notes,
		"force_update": false
	}
	_process_version_data(test_data)
