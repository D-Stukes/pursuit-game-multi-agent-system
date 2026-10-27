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
		view.animation.seek(duration*.5,true);view.animation.advance(0);await frames(2)
		var middle:Transform3D=view.skeleton.get_bone_global_pose(bone)
		check(clip+" has nonzero duration",duration>1,duration)
		check(clip+" drives actual imported skeleton",not middle.is_equal_approx(first),middle.origin)
	view.play_clip("Idle");view.animation.pause();view.animation.seek(46.0/24,true);view.animation.advance(0);await frames(2)
	var closed:int=0
	for m:MeshInstance3D in meshes:
		if m.mesh.get_blend_shape_count()>0 and m.get_blend_shape_value(0)>.85:closed+=1
	check("Idle closes paired eyelids in engine",closed==2,closed)
	print("CHARACTER_RESULT checks=",checks," failures=",failures)
	view.queue_free();await process_frame;quit(0 if failures==0 else 1)
