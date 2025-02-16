extends Button

# Référence à la scène que tu veux charger
var scene_to_load = "res://scenes/Game_Over.tscn"  # Remplace par le chemin de ta scène

func _input(event):
	if event is InputEventMouseButton and event.pressed and self.is_hovered():
		get_tree().paused = true
		print("Bouton pressé - Chargement de la scène")
		
		# Charger et instancier la scène
		var new_scene = load(scene_to_load).instantiate()
		
		# Ajouter la nouvelle scène à la scène actuelle
		get_tree().current_scene.add_child(new_scene)
