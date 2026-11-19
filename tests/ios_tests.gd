extends RefCounted
## iOS export preset and app icons (design 16.11 A).

const IosIcons := preload("res://tools/ios_icons.gd")
const BG := Color("#1B1F26")
const ICON_DIR := "res://export/ios/icons/"

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	var cfg := ConfigFile.new()
	_check.call(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	_preset_tests(cfg)
	_web_tests(cfg)
	_icon_tests()


func _presets(cfg: ConfigFile) -> Array[String]:
	var out: Array[String] = []
	for s in cfg.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options"):
			out.append(s)
	return out


func _preset_tests(cfg: ConfigFile) -> void:
	var ios: Array[String] = []
	for s in _presets(cfg):
		if cfg.get_value(s, "platform", "") == "iOS":
			ios.append(s)
	_check.call(ios.size() == 1, "exactly one iOS preset")
	if ios.size() != 1:
		return
	var p := ios[0]
	var o := p + ".options"
	var web := _web_section(cfg)
	_check.call(cfg.get_value(p, "name") == "iOS", "iOS preset is named iOS")
	_check.call(cfg.get_value(p, "export_path") == "build/ios/WhiteSum.ipa", "iOS export path is build/ios/WhiteSum.ipa")
	_check.call(str(cfg.get_value(p, "include_filter")).contains("*.json"), "iOS preset includes json (the pool)")
	_check.call(cfg.get_value(p, "exclude_filter") == cfg.get_value(web, "exclude_filter"),
			"iOS exclude filter equals the web one")
	_check.call(cfg.get_value(p, "encrypt_pck") == false, "iOS pck is not encrypted")
	_check.call(cfg.get_value(o, "application/bundle_identifier") == "nl.steefbeest.whitesum", "bundle id")
	_check.call(cfg.get_value(o, "application/targeted_device_family") == 0, "iPhone only")
	_check.call(cfg.get_value(o, "application/export_project_only") == true, "export_project_only for the Linux export")
	_check.call(cfg.get_value(o, "application/export_method_release") == 0, "release export method is App Store")
	_check.call(cfg.get_value(o, "application/code_sign_identity_release") == "Apple Distribution",
			"release signing identity is Apple Distribution")
	_check.call(cfg.get_value(o, "application/min_ios_version") == "16.0", "minimum iOS version 16.0")
	_check.call(cfg.get_value(o, "application/app_store_team_id") == "", "no team id in git")
	_check.call(cfg.get_value(o, "application/short_version") == "", "no hand-written short version in git")
	_check.call(cfg.get_value(o, "application/version") == "", "no hand-written build number in git")
	var plist := str(cfg.get_value(o, "application/additional_plist_content"))
	_check.call(plist.contains("CFBundleLocalizations") and plist.contains("<string>en</string>")
			and plist.contains("<string>nl</string>"), "plist lists the en and nl localizations")
	# Godot 4.7.2 writes this key itself; a second one would make the plist ambiguous
	_check.call(not plist.contains("ITSAppUsesNonExemptEncryption"), "plist does not repeat the Godot-written encryption key")
	_check.call(cfg.get_value(o, "privacy/tracking_enabled") == false, "tracking off")
	_check.call(cfg.get_value(o, "storyboard/use_custom_bg_color") == true, "launch screen uses a custom colour")
	var col: Color = cfg.get_value(o, "storyboard/custom_bg_color")
	_check.call(_near(col, BG), "launch screen colour is #1B1F26")
	var blank_ok := true
	for key in ["storyboard/custom_image@2x", "storyboard/custom_image@3x"]:
		var img := Image.load_from_file(str(cfg.get_value(o, key, "")))
		blank_ok = blank_ok and img != null and img.get_width() <= IosIcons.BLANK_SIZE \
				and img.get_height() <= IosIcons.BLANK_SIZE and _fully_clear(img)
	_check.call(blank_ok, "both launch image options point to an existing small transparent file")
	var icons_ok := true
	var count := 0
	var has_1024 := false
	for key in cfg.get_section_keys(o):
		if not key.begins_with("icons/"):
			continue
		var path := str(cfg.get_value(o, key))
		if path.is_empty():
			continue
		count += 1
		icons_ok = icons_ok and path.begins_with(ICON_DIR) and FileAccess.file_exists(path)
		has_1024 = has_1024 or key.ends_with("1024x1024")
	_check.call(count > 0 and icons_ok, "every icon option points to an existing file below export/ios/icons")
	_check.call(has_1024, "the 1024 icon option is set")


func _web_section(cfg: ConfigFile) -> String:
	for s in _presets(cfg):
		if cfg.get_value(s, "platform", "") == "Web":
			return s
	return ""


func _web_tests(cfg: ConfigFile) -> void:
	var w := _web_section(cfg)
	_check.call(w != "", "web preset exists")
	if w == "":
		return
	var o := w + ".options"
	_check.call(cfg.get_value(w, "name") == "Web" and cfg.get_value(w, "export_path") == "build/web/index.html",
			"web preset name and export path unchanged")
	_check.call(cfg.get_value(w, "include_filter") == "*.json"
			and cfg.get_value(w, "exclude_filter") == "tests/*,tools/*,addons/white_kit/tests/*,addons/white_kit/tools/*",
			"web preset filters unchanged")
	_check.call(cfg.get_value(o, "variant/thread_support") == false and cfg.get_value(o, "html/canvas_resize_policy") == 2
			and cfg.get_value(o, "progressive_web_app/enabled") == false, "web preset options unchanged")


func _icon_tests() -> void:
	var all_ok := true
	for n in IosIcons.SIZES:
		var img := Image.load_from_file("%sicon_%d.png" % [ICON_DIR, n])
		var ok := img != null and img.get_width() == n and img.get_height() == n
		ok = ok and img.get_format() == Image.FORMAT_RGB8 and img.detect_alpha() == Image.ALPHA_NONE
		if ok:
			ok = _near(img.get_pixel(0, 0), BG) and _near(img.get_pixel(n - 1, n - 1), BG)
		if not ok:
			print("icon %d is not an opaque n x n square with #1B1F26 corners" % n)
		all_ok = all_ok and ok
	_check.call(all_ok, "every iOS icon exists, is n x n, opaque RGB8 and has #1B1F26 corners")
	for n in [1024, 180, 120]:
		var img := Image.load_from_file("%sicon_%d.png" % [ICON_DIR, n])
		var want := IosIcons.render(n)
		_check.call(img != null and img.get_data() == want.get_data(), "icon %d is up to date with icon.svg" % n)
	var blank := Image.load_from_file(IosIcons.BLANK)
	_check.call(blank != null and blank.get_data() == IosIcons.blank().get_data(), "blank launch image is up to date")


func _fully_clear(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return false
	return true


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 1.5 / 255.0 and absf(a.g - b.g) <= 1.5 / 255.0 and absf(a.b - b.b) <= 1.5 / 255.0
