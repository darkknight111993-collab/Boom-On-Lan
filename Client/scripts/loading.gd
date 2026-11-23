extends Control
# Loading placeholder: no loading asset found in CA.exe.c (only Ladder/Ladder_loading, which is in-game). GUESS layout.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(800, 600)
	add_child(bg)
	var l := Label.new()
	l.text = "Loading..."
	l.position = Vector2(350, 280)
	add_child(l)
	var bar := ProgressBar.new()
	bar.position = Vector2(250, 310)
	bar.size = Vector2(300, 16)
	add_child(bar)
	var t := create_tween()
	t.tween_property(bar, "value", 100.0, 1.2)
	t.tween_callback(Session.goto.bind("login"))
