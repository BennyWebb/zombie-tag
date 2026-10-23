@tool
extends EditorPlugin
## Gives the Android TV app its banner: the wide picture on the TV's home screen (icons/banner.png).
## Godot's Android export has no setting for it, so just before the app is built this puts the
## picture into the Android build template (the android/ folder that Project → Install Android
## Build Template makes) and tells the app's manifest to use it.

var exporter := BannerExporter.new()


func _enter_tree() -> void:
	add_export_plugin(exporter)


func _exit_tree() -> void:
	remove_export_plugin(exporter)


class BannerExporter extends EditorExportPlugin:
	const TEMPLATE := "res://android/build/"
	const MANIFEST := TEMPLATE + "src/main/AndroidManifest.xml"
	const BANNER := TEMPLATE + "res/drawable-xhdpi/banner.png"

	func _get_name() -> String:
		return "TV banner"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not "android" in features or not FileAccess.file_exists(MANIFEST):
			return # (not Android, or no build template yet)
		DirAccess.make_dir_recursive_absolute(BANNER.get_base_dir())
		DirAccess.copy_absolute("res://icons/banner.png", BANNER)
		var manifest := FileAccess.get_file_as_string(MANIFEST)
		if not "android:banner" in manifest:
			manifest = manifest.replace("android:icon=\"@mipmap/icon\"", "android:icon=\"@mipmap/icon\"\n        android:banner=\"@drawable/banner\"")
			var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
			file.store_string(manifest)
