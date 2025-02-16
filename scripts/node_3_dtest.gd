extends Node3D

@export var object_speed : float = 5.0
@export var max_speed : float = 10.0
@export var camera_speed : float = 5.0
@export var spawn_interval : float = 2.0
@export var detection_range : float = 3.0

# Points de vie
var player_health := 3

# Premier set de textures
@export var table_obs : Texture
@export var cartons : Texture
@export var meubletv : Texture
@export var sac_poubelle : Texture
@export var bouteilles : Texture

# Deuxième set de textures (après 60 secondes)
@export var chaise : Texture
@export var palette : Texture
@export var canapé : Texture
@export var valise : Texture
@export var boite : Texture

var columns = []  
var camera : Camera3D  
var camera_column_index : int = 0  
var target_camera_position : Vector3  
var detected_sprites = []  
var use_alternate_sprites = false  

# Sprites dangereux
var dangerous_sprites = ["Table", "MeubleTV", "Sac"]

# Premier set de sprites
var sprite_textures := {
	"Table": preload("res://assets/images/tx_table.png"),
	"Cartons": preload("res://assets/images/tx_cartons.png"),
	"MeubleTV": preload("res://assets/images/tx_meubletv.png"),
	"Sac": preload("res://assets/images/tx_sacspoubelles.png"),
	"Bouteilles": preload("res://assets/images/tx_bouteilles.png")
}


# Deuxième set de sprites
var alternate_sprite_textures := {
	"Chaise": chaise,
	"Palette": palette,
	"Canapé": canapé,
	"Valise": valise,
	"Boîte": boite
}

func _ready():
	# Récupérer la caméra et les colonnes
	camera = $Camera3D  
	columns.append($MeshInstance3D)  
	columns.append($MeshInstance3D2)  
	columns.append($MeshInstance3D3)  
	columns.append($MeshInstance3D4)  

	_align_camera_to_column(true)

	# Timer pour la génération des sprites (toutes les 2s)
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_generate_sprite)
	add_child(spawn_timer)

	# Timer pour changer les sprites après 60s
	var switch_timer = Timer.new()
	switch_timer.wait_time = 60.0
	switch_timer.one_shot = true
	switch_timer.autostart = true
	switch_timer.timeout.connect(_switch_sprites)
	add_child(switch_timer)

# Changer la liste des sprites après 60 secondes
func _switch_sprites():
	use_alternate_sprites = true

# Générer un sprite
func _generate_sprite():
	var rand_column = randi() % columns.size()
	var column = columns[rand_column]  
	var start_pos = column.get_node("Start").global_position
	var end_pos = column.get_node("End").global_position
	
	var new_sprite = Sprite3D.new()
	var sprite_list = alternate_sprite_textures if use_alternate_sprites else sprite_textures
	var keys = sprite_list.keys()
	var rand_key = keys[randi() % keys.size()]
	var rand_texture = sprite_list[rand_key]

	# Vérifier si la texture est bien chargée
	if rand_texture == null:
		print("⚠️ Erreur: la texture de ", rand_key, " est NULL !")
		return
	
	print("✅ Génération de: ", rand_key, " avec la texture: ", rand_texture.resource_path)

	# Appliquer la texture
	new_sprite.texture = rand_texture  # ✅ Correction ici !
	new_sprite.position = start_pos
	new_sprite.set_meta("name", rand_key)  # Stocke le nom du sprite
	new_sprite.position.y += 3
	add_child(new_sprite)  
	detected_sprites.append(new_sprite)

	# Animation de déplacement
	var tween = get_tree().create_tween()
	tween.tween_property(new_sprite, "position", end_pos, 2.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(new_sprite.queue_free)
	tween.tween_callback(func(): detected_sprites.erase(new_sprite))



# Déplacement fluide de la caméra
func _process(delta):
	if Input.is_action_just_pressed("motif1") and camera_column_index > 0:
		camera_column_index -= 1
		_align_camera_to_column()

	if Input.is_action_just_pressed("motif2") and camera_column_index < columns.size() - 1:
		camera_column_index += 1
		_align_camera_to_column()

	camera.position = camera.position.lerp(target_camera_position, camera_speed * delta)

	# Vérifier la proximité des sprites avec le joueur
	_check_proximity()

# Aligner la caméra sur la colonne actuelle
func _align_camera_to_column(instant := false):
	target_camera_position = columns[camera_column_index].position
	target_camera_position.z = 30
	target_camera_position.y = 4
	target_camera_position.x = -3
	if instant:
		camera.position = target_camera_position

# Vérifier la proximité des sprites avec le joueur
func _check_proximity():
	for sprite in detected_sprites:
		var distance = camera.position.distance_to(sprite.position)
		if distance < detection_range:
			var sprite_name = sprite.get_meta("name")
			print(sprite_name, " touché !")

			# Vérifier si l'objet est dangereux
			if sprite_name in dangerous_sprites:
				_take_damage()
			
			# Supprimer après détection
			detected_sprites.erase(sprite)

# Gestion des points de vie
func _take_damage():
	player_health -= 1
	print("PV restants : ", player_health)

	if player_health <= 0:
		_game_over()

# Fin de partie
func _game_over():
	print("GAME OVER !")
	get_tree().paused = true  # Met en pause le jeu
