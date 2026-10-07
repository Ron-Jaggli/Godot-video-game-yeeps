extends SceneTree
## Installs the pinned Godot OpenXR Vendors plugin (Meta Quest support) into
## res://addons. Its prebuilt binaries are ~86 MB, so they aren't committed.
##
##   godot --headless -s tools/setup_quest.gd
##   godot --headless -s tools/setup_quest.gd -- --zip=path/to/godotopenxrvendorsaddon.zip
##   godot --headless -s tools/setup_quest.gd -- --force
##
## Bump VERSION and SHA256 together when upgrading Godot or the plugin.

const VERSION := "5.1.0-stable"
const URL := "https://github.com/GodotVR/godot_openxr_vendors/releases/download/%s/godotopenxrvendorsaddon.zip"
const SHA256 := "6a838dbdf4115549e4511ebee0da9a5dcc8f9f6258d4cc2f2ee57a907a3e2911"
const ZIP_PREFIX := "asset/addons/"
const ADDON_DIR := "res://addons/godotopenxrvendors"
const MARKER := ADDON_DIR + "/.installed_version"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true

	if not args.has("force") and FileAccess.get_file_as_string(MARKER).strip_edges() == VERSION:
		print("OpenXR Vendors %s already installed." % VERSION)
		quit()
		return

	var zip_path: String = args.get("zip", "")
	if zip_path.is_empty():
		zip_path = ProjectSettings.globalize_path("user://godotopenxrvendorsaddon-%s.zip" % VERSION)
		print("Downloading OpenXR Vendors %s..." % VERSION)
		var err := await _download(URL % VERSION, zip_path)
		if err != OK:
			_fail("Download failed (%s). Download the zip by hand from\n  %s\nand pass it with -- --zip=<path>." % [error_string(err), URL % VERSION])
			return

	var actual := FileAccess.get_sha256(zip_path)
	if actual != SHA256:
		_fail("Checksum mismatch for %s\n  expected %s\n  got      %s" % [zip_path, SHA256, actual])
		return

	_remove_dir(ADDON_DIR)
	var extracted := _extract(zip_path)
	if extracted == 0:
		_fail("Nothing extracted; is this the right zip?")
		return
	FileAccess.open(MARKER, FileAccess.WRITE).store_string(VERSION)
	print("Installed OpenXR Vendors %s (%d files). Reopen the project in the editor so it loads the plugin." % [VERSION, extracted])
	quit()


func _download(url: String, path: String) -> Error:
	var http := HTTPRequest.new()
	http.download_file = path
	http.max_redirects = 10
	var proxy := OS.get_environment("HTTPS_PROXY")
	if not proxy.is_empty():
		var host_port := proxy.trim_prefix("http://").trim_prefix("https://").trim_suffix("/").split(":")
		http.set_https_proxy(host_port[0], int(host_port[1]) if host_port.size() > 1 else 443)
	root.add_child(http)
	var err := http.request(url)
	if err != OK:
		return err
	var response: Array = await http.request_completed
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return FAILED
	return OK if response[1] == 200 else ERR_FILE_NOT_FOUND


func _extract(zip_path: String) -> int:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return 0
	var count := 0
	for file in zip.get_files():
		if not file.begins_with(ZIP_PREFIX) or file.ends_with("/"):
			continue
		var out := "res://addons/" + file.trim_prefix(ZIP_PREFIX)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		FileAccess.open(out, FileAccess.WRITE).store_buffer(zip.read_file(file))
		count += 1
	zip.close()
	return count


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
