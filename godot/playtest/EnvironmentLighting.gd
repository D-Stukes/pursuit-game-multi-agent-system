extends RefCounted
## Shared game/review lighting, so appearance evidence uses the played environment.

static func setup(parent: Node3D) -> void:
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38, 0.60, 0.77)
	sky_material.sky_horizon_color = Color(0.91, 0.84, 0.70)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color(0.36, 0.38, 0.36)
	sky_material.sky_curve = 0.3
	sky_material.sun_angle_max = 3.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.92, 0.95, 1.0)
	environment.ambient_light_energy = 0.55
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 1.5
	environment.ssao_light_affect = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0018
	environment.fog_light_color = Color(0.72, 0.80, 0.84)
	environment.fog_sky_affect = 0.15
	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(sun)
	# The visible solar disk affects the sky; the first light shades geometry.
	var sky_sun := DirectionalLight3D.new()
	sky_sun.name = "BackdropSun"
	sky_sun.rotation_degrees = Vector3(-18, -25, 0)
	sky_sun.light_color = Color(1.0, 0.87, 0.61)
	sky_sun.light_angular_distance = 1.0
	sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	parent.add_child(sky_sun)
