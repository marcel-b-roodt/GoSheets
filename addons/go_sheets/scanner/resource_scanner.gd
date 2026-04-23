## ResourceScanner
##
## Walks a directory tree recursively and returns every .tres / .res file path.
## Pure logic — no editor dependency; fully testable headlessly.
##
## Usage:
##   var paths: Array[String] = ResourceScanner.scan("res://data/")
class_name ResourceScanner
extends RefCounted


## Scan [param root_path] recursively and return all .tres/.res file paths.
## Returns an empty array if [param root_path] does not exist.
## Paths are returned alphabetically (depth-first).
##
## Note: "res://" is a valid root — the scheme is preserved as-is.
static func scan(root_path: String) -> Array[String]:
	var results: Array[String] = []
	_walk(root_path, results)
	return results


static func _walk(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.include_hidden = false
	dir.include_navigational = false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			_walk(path.path_join(entry), results)
		else:
			if entry.ends_with(".tres") or entry.ends_with(".res"):
				results.append(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
