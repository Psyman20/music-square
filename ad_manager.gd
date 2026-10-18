extends Node

# Your Real AdMob Rewarded Ad Unit ID:
const REWARDED_PROD_UNIT_ID := "ca-app-pub-4818290372464100/1568393180"

# Google Official Test Rewarded Ad Unit ID (for debug/testing):
const REWARDED_TEST_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

var _admob: Node = null
var _on_reward_callback: Callable
var _on_dismiss_callback: Callable
var _is_ad_loading: bool = false
var _is_initialized: bool = false
var _pending_load: bool = false
var _show_when_loaded: bool = false
var _load_request_id: int = 0
var _retry_attempt: int = 0

func _ready() -> void:
	if Engine.has_singleton("AdmobPlugin"):
		_setup_admob_node()
	else:
		print("[AdManager] Running in Desktop / Editor (Admob native plugin inactive).")

func _setup_admob_node() -> void:
	var admob_script = load("res://addons/AdmobPlugin/Admob.gd")
	if admob_script == null:
		return

	_admob = admob_script.new()
	_admob.name = "AdMobNode"
	# Disable per-frame _process on Admob node (only used for Native Ad control bindings)
	_admob.set_process(false)

	# Configure ad IDs & application IDs:
	_admob.is_real = not OS.is_debug_build()
	_admob.android_debug_application_id = "ca-app-pub-3940256099942544~3347511713"
	_admob.android_real_application_id = "ca-app-pub-4818290372464100~8189641857"
	_admob.android_debug_rewarded_id = REWARDED_TEST_UNIT_ID
	_admob.android_real_rewarded_id = REWARDED_PROD_UNIT_ID

	# Connect initialization and ad lifecycle signals
	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
	_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
	_admob.rewarded_ad_user_earned_reward.connect(_on_rewarded_ad_user_earned_reward)
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(_on_rewarded_ad_failed_to_show)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(_on_rewarded_ad_dismissed)

	add_child(_admob)

	print("[AdManager] Initializing AdMob plugin (is_real=%s)..." % str(_admob.is_real))
	_pending_load = true
	if _admob.has_method("initialize"):
		_admob.initialize()

	# Safety retry: if initialization_completed signal hasn't arrived after 5 seconds,
	# re-trigger initialize() (never call load_rewarded_ad before initialization completes,
	# because the native plugin drops uninitialized load calls without emitting a signal).
	get_tree().create_timer(5.0).timeout.connect(func():
		if not _is_initialized and _admob != null and _admob.has_method("initialize"):
			print("[AdManager] Initialization still pending after 5s; re-requesting initialize()...")
			_admob.initialize()
	)

func _on_initialization_completed(_status_data: Variant) -> void:
	_is_initialized = true
	_is_ad_loading = false
	print("[AdManager] AdMob initialization completed successfully. Preloading rewarded ad...")
	load_rewarded_ad()

func is_rewarded_ad_loaded() -> bool:
	if _admob != null and _is_initialized and _admob.has_method("is_rewarded_ad_loaded"):
		return _admob.is_rewarded_ad_loaded()
	return false

func preload_rewarded_ad() -> void:
	if not is_rewarded_ad_loaded():
		load_rewarded_ad()

func load_rewarded_ad() -> void:
	if _admob == null:
		return
	if not _is_initialized:
		_pending_load = true
		return
	if _is_ad_loading or is_rewarded_ad_loaded():
		return

	_pending_load = false
	_is_ad_loading = true
	_load_request_id += 1
	var req_id := _load_request_id
	print("[AdManager] Requesting rewarded ad load from AdMob (req #%d)..." % req_id)
	if _admob.has_method("load_rewarded_ad"):
		_admob.load_rewarded_ad()

	# Watchdog: reset _is_ad_loading if native callback never arrives within 15 seconds
	get_tree().create_timer(15.0).timeout.connect(func():
		if _is_ad_loading and _load_request_id == req_id:
			print("[AdManager] Load watchdog timeout (req #%d) — resetting _is_ad_loading." % req_id)
			_is_ad_loading = false
			if _show_when_loaded:
				_show_when_loaded = false
				_grant_fallback_reward()
	)

func show_rewarded_ad(on_reward: Callable, on_dismiss: Callable = Callable()) -> void:
	_on_reward_callback = on_reward
	_on_dismiss_callback = on_dismiss

	# Fallback if running in editor or without native mobile plugin
	if _admob == null or not Engine.has_singleton("AdmobPlugin"):
		print("[AdManager] Editor / desktop mode: Simulating rewarded ad.")
		_grant_fallback_reward()
		return

	# Check if an ad is ready in cache
	if is_rewarded_ad_loaded():
		_show_when_loaded = false
		print("[AdManager] Showing cached rewarded ad.")
		_admob.show_rewarded_ad()
		return

	# Ad not yet cached: start/continue loading and wait up to 5 seconds for it to arrive
	print("[AdManager] Rewarded ad not yet in cache; waiting up to 5.0s for load before fallback...")
	_show_when_loaded = true
	load_rewarded_ad()
	get_tree().create_timer(5.0).timeout.connect(func():
		if _show_when_loaded:
			_show_when_loaded = false
			if is_rewarded_ad_loaded():
				print("[AdManager] Rewarded ad finished loading during wait; showing now.")
				_admob.show_rewarded_ad()
			else:
				print("[AdManager] Rewarded ad still not ready after 5.0s wait; granting fallback reward.")
				_grant_fallback_reward()
	)

func _grant_fallback_reward() -> void:
	if _on_reward_callback.is_valid():
		var cb := _on_reward_callback
		_on_reward_callback = Callable()
		_on_dismiss_callback = Callable()
		cb.call()

func _on_rewarded_ad_loaded(_ad_info: Variant, _response_info: Variant) -> void:
	_is_ad_loading = false
	_retry_attempt = 0
	print("[AdManager] SUCCESS: Rewarded ad loaded and cached ready to display.")
	if _show_when_loaded:
		_show_when_loaded = false
		print("[AdManager] Showing newly loaded rewarded ad immediately.")
		_admob.show_rewarded_ad()

func _on_rewarded_ad_failed_to_load(_ad_info: Variant, error_data: Variant) -> void:
	_is_ad_loading = false
	var code: int = -1
	var msg: String = "Unknown error"
	if error_data != null:
		if error_data.has_method("get_code"):
			code = error_data.get_code()
		elif typeof(error_data) == TYPE_DICTIONARY and error_data.has("code"):
			code = error_data["code"]
		if error_data.has_method("get_message"):
			msg = error_data.get_message()
		elif typeof(error_data) == TYPE_DICTIONARY and error_data.has("message"):
			msg = str(error_data["message"])
		else:
			msg = str(error_data)
	print("[AdManager] Rewarded ad failed to load: [Code %d] %s" % [code, msg])

	if _show_when_loaded:
		_show_when_loaded = false
		_grant_fallback_reward()

	# Auto-retry loading with progressive delay so an ad is ready for the next request
	_retry_attempt += 1
	var retry_delay := clampf(10.0 * float(_retry_attempt), 10.0, 30.0)
	get_tree().create_timer(retry_delay).timeout.connect(func():
		if not is_rewarded_ad_loaded():
			load_rewarded_ad()
	)

func _on_rewarded_ad_user_earned_reward(_ad_info: Variant, _reward_data: Variant) -> void:
	print("[AdManager] User earned reward!")
	if _on_reward_callback.is_valid():
		var cb := _on_reward_callback
		_on_reward_callback = Callable()
		cb.call()

func _on_rewarded_ad_failed_to_show(_ad_info: Variant, error_data: Variant) -> void:
	print("[AdManager] Rewarded ad failed to show: ", error_data)
	_show_when_loaded = false
	_on_reward_callback = Callable()
	if _on_dismiss_callback.is_valid():
		var dcb := _on_dismiss_callback
		_on_dismiss_callback = Callable()
		dcb.call()
	load_rewarded_ad()

func _on_rewarded_ad_dismissed(_ad_info: Variant) -> void:
	print("[AdManager] Rewarded ad dismissed. Preloading next ad...")
	_show_when_loaded = false
	if _on_reward_callback.is_valid():
		# Ad was dismissed before user earned reward
		_on_reward_callback = Callable()
		if _on_dismiss_callback.is_valid():
			var dcb := _on_dismiss_callback
			_on_dismiss_callback = Callable()
			dcb.call()
	else:
		_on_dismiss_callback = Callable()
	load_rewarded_ad()