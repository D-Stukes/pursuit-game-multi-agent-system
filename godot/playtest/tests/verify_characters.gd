extends SceneTree
## Import, skinning, morph and named-animation checks against actual new GLBs.
var checks:int=0
var failures:int=0
var view:Node3D
func _initialize()->void:call_deferred("run")
func check(label:String,ok:bool,detail:Variant="")->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label," ",detail)
func frames(n:int)->void:
	for i in range(n):await process_frame
func run()->void:
	view=load("res://CharacterReview.tscn").instantiate();root.add_child(view)
	await frames(8)
	check("isolated character scene ready",view.ready_for_test)
	check("MrP skeleton imported",view.skeleton!=null and view.skeleton.get_bone_count()==13)
	check("all MrP named clips imported",view.animation!=null and view.animation.has_animation("Idle") and view.animation.has_animation("Welcome") and view.animation.has_animation("Guide"))
	var meshes:Array[Node]=view.model.find_children("*","MeshInstance3D",true,false)
	var skinned:int=0
	var blink:int=0
	for m:MeshInstance3D in meshes:
		if m.skin!=null:skinned+=1
		if m.mesh.get_blend_shape_count()>0:blink+=1
	check("all exported meshes retain skin bindings",skinned==meshes.size(),[skinned,meshes.size()])
	check("both blink meshes survive glTF import",blink==2,blink)
	for clip:String in ["Idle","Welcome","Guide"]:
		view.play_clip(clip);view.animation.pause();view.animation.seek(0,true);view.animation.advance(0)
		await frames(2)
		var bone:int=view.skeleton.find_bone("hand_L")
		var first:Transform3D=view.skeleton.get_bone_global_pose(bone)
		var duration:float=view.animation.get_animation(clip).length
		view.animation.seek(duration*.25,true);view.animation.advance(0);await frames(2)
		var middle:Transform3D=view.skeleton.get_bone_global_pose(bone)
		check(clip+" has nonzero duration",duration>1,duration)
		check(clip+" drives actual imported skeleton",not middle.is_equal_approx(first),middle.origin)
	view.play_clip("Idle");view.animation.pause();view.animation.seek(46.0/24,true);view.animation.advance(0);await frames(2)
	var closed:int=0
	for m:MeshInstance3D in meshes:
		if m.mesh.get_blend_shape_count()>0 and m.get_blend_shape_value(0)>.85:closed+=1
	check("Idle closes paired eyelids in engine",closed==2,closed)
	view.load_asset("robot");await frames(5)
	check("robot scene ready",view.ready_for_test and view.asset_id=="robot")
	check("robot skeleton has17 mechanical bones",view.skeleton!=null and view.skeleton.get_bone_count()==17)
	meshes=view.model.find_children("*","MeshInstance3D",true,false)
	var found:Dictionary={}
	for m:MeshInstance3D in meshes:
		var extras:Dictionary=m.get_meta("extras",{});found[extras.get("part_id","")]=m
	check("seven independently tagged robot modules",meshes.size()==7 and found.size()==7 and not found.has(""))
	check("all robot clips imported",view.animation.has_animation("Idle") and view.animation.has_animation("PowerOn") and view.animation.has_animation("Assemble"))
	for clip:String in ["Idle","PowerOn","Assemble"]:
		view.play_clip(clip);view.animation.pause();view.animation.seek(0,true);view.animation.advance(0);await frames(2)
		var bone:int=view.skeleton.find_bone("head" if clip=="Idle" else "hand_L")
		var first:Transform3D=view.skeleton.get_bone_global_pose(bone)
		view.animation.seek(view.animation.get_animation(clip).length*.25,true);view.animation.advance(0);await frames(2)
		check(clip+" drives imported robot joints",not view.skeleton.get_bone_global_pose(bone).is_equal_approx(first))
	check("assembly is one-shot",view.animation.get_animation("Assemble").loop_mode==Animation.LOOP_NONE)
	check("all seven registered2D layers load",view.sprite_images.size()==7)
	check("torso layer correctly covers hip modules",view.sprite_images.torso.z_index>view.sprite_images.left_leg.z_index and view.sprite_images.torso.z_index>view.sprite_images.right_leg.z_index)
	check("core layer correctly covers torso",view.sprite_images.power_core.z_index>view.sprite_images.torso.z_index)
	for part:String in view.ROBOT_PARTS:
		if not view.sprite_images.has(part):continue
		var texture:Texture2D=view.sprite_images[part].texture
		check("registered layer size "+part,texture.get_width()==768 and texture.get_height()==1024)
		check("transparent layer corner "+part,texture.get_image().get_pixel(0,0).a<.01)
	view.show_2d_button.button_pressed=true;await frames(2)
	check("2D control showslayers and hides3D model",view.sprite_panel.visible and not view.model.visible)
	var toggle:Button=view.parts_buttons.get_child(5)
	toggle.button_pressed=false;await frames(2)
	check("part toggle hides matching2D and3D head",not found.head.visible and not view.sprite_images.head.visible)
	toggle.button_pressed=true;view.show_2d_button.button_pressed=false;await frames(2)
	check("returnto3D preserves complete assembly",view.model.visible and not view.sprite_panel.visible and found.head.visible)
	view.play_clip("Assemble");view.animation.pause();view.animation.seek(0,true);view.animation.advance(0);await frames(2)
	var index:int=view.skeleton.find_bone("head");var expanded:Vector3=view.skeleton.get_bone_global_pose(index).origin
	var projected:Vector2=view.camera.unproject_position(view.skeleton.to_global(expanded+Vector3.UP*.41))
	check("exploded head framed below review toolbar",projected.y>185,projected)
	view.animation.seek(view.animation.get_animation("Assemble").length-.01,true);view.animation.advance(0);await frames(2)
	check("assembly visibly closes head-to-torso gap",expanded.distance_to(view.skeleton.get_bone_global_pose(index).origin)>.40)
	print("CHARACTER_RESULT checks=",checks," failures=",failures)
	view.queue_free();await process_frame;quit(0 if failures==0 else 1)
