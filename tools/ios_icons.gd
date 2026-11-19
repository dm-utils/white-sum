extends SceneTree
## iOS app icons from icon.svg: godot --headless --path . -s res://tools/ios_icons.gd
## Opaque full squares (App Store rejects alpha); every size rendered from the svg, none scaled down.

# 114, 128, 136, 192: options of the 4.7.2 preset that have no exact size otherwise
const SIZES: Array[int] = [1024, 192, 180, 167, 152, 136, 128, 120, 114, 87, 80, 76, 60, 58, 40, 29, 20]
const BG := Color("#1B1F26")
const DIR := "res://export/ios/icons"


static func render(n: int) -> Image:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var src := Image.new()
	src.load_svg_from_string(svg, n / 128.0)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
	img.convert(Image.FORMAT_RGB8)
	return img


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for n in SIZES:
		var path := "%s/icon_%d.png" % [DIR, n]
		var err := render(n).save_png(path)
		print("%s %s" % [path, "ok" if err == OK else "error %d" % err])
		if err != OK:
			quit(1)
			return
	quit()
