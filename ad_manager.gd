extends Node

# Your Real AdMob Rewarded Ad Unit ID:
const REWARDED_PROD_UNIT_ID := "ca-app-pub-4818290372464100/1568393180"

# Google Official Test Rewarded Ad Unit ID (for debug/testing):
const REWARDED_TEST_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

var _admob: Node = null
var _on_reward_callback: Callable
var _is_ad_loading: bool = false

func _ready() -> void:
	if Engine.has_singleton("AdmobPlugin"):
		_setup_admob_node()
	else:
		print("[AdManager] Running in Desktop / Editor (Admob native plugin inactive).")

func _setup_admob_node() -> void:
	var admob_script = load("res://addons/AdmobPlugin/Admob.gd")
	if admob_script != null:
		_admob = Node.new()
		_admob.set_script(admob_script)
		_admob.name = "AdMobNode"
		
		# Configure ad IDs:
		_admob.is_real = not OS.is_debug_build()
		_admob.android_debug_rewarded_id = REWARDED_TEST_UNIT_ID
		_admob.android_real_rewarded_id = REWARDED_PROD_UNIT_ID
		
		# Connect signals
		_admob.rewarded_ad_loaded.connect(_on_rewarded_ad_loaded)
		_admob.rewarded_ad_failed_to_load.connect(_on_rewarded_ad_failed_to_load)
		_admob.rewarded_ad_user_earned_reward.connect(_on_rewarded_ad_user_earned_reward)
		_admob.rewarded_ad_failed_to_show_full_screen_content.connect(_on_rewarded_ad_failed_to_show)
		_admob.rewarded_ad_dismissed_full_screen_content.connect(_on_rewarded_ad_dismissed)
		
		add_child(_admob)
		
		if _admob.has_method("initialize"):
			_admob.initialize()
		
		load_rewarded_ad()

func load_rewarded_ad() -> void:
	if _admob == null or _is_ad_loading:
		return
	_is_ad_loading = true
	if _admob.has_method("load_rewarded_ad"):
		_admob.load_rewarded_ad()

func show_rewarded_ad(on_reward: Callable) -> void:
	_on_reward_callback = on_reward
	
	# Fallback if running in editor or without native mobile plugin
	if _admob == null or not Engine.has_singleton("AdmobPlugin"):
		print("[AdManager] Editor / desktop mode: Simulating rewarded ad.")
		if _on_reward_callback.is_valid():
			_on_reward_callback.call()
		return
	
	# Check if an ad is ready to show
	if _admob.has_method("is_rewarded_ad_loaded") and _admob.is_rewarded_ad_loaded():
		_admob.show_rewarded_ad()
	else:
		print("[AdManager] Rewarded ad not cached yet, requesting load...")
		load_rewarded_ad()
		if _on_reward_callback.is_valid():
			_on_reward_callback.call()

func _on_rewarded_ad_loaded(_ad_info: Variant, _response_info: Variant) -> void:
	_is_ad_loading = false
	print("[AdManager] Rewarded ad loaded and ready.")

func _on_rewarded_ad_failed_to_load(_ad_info: Variant, error_data: Variant) -> void:
	_is_ad_loading = false
	print("[AdManager] Rewarded ad failed to load: ", error_data)

func _on_rewarded_ad_user_earned_reward(_ad_info: Variant, _reward_data: Variant) -> void:
	print("[AdManager] User earned reward!")
	if _on_reward_callback.is_valid():
		var cb := _on_reward_callback
		_on_reward_callback = Callable()
		cb.call()

func _on_rewarded_ad_failed_to_show(_ad_info: Variant, error_data: Variant) -> void:
	print("[AdManager] Rewarded ad failed to show: ", error_data)
	_on_reward_callback = Callable()
	load_rewarded_ad()

func _on_rewarded_ad_dismissed(_ad_info: Variant) -> void:
	print("[AdManager] Rewarded ad dismissed.")
	load_rewarded_ad()