
extends KinematicBody

# Member variables
const ANIM_FLOOR = 0
const ANIM_AIR_UP = 1
const ANIM_AIR_DOWN = 2

const SHOOT_TIME = 1.5
const SHOOT_SCALE = 2

const CHAR_SCALE = Vector3(0.3, 0.3, 0.3)

var facing_dir = Vector3(1, 0, 0)
var movement_dir = Vector3()

var jumping = false

export(int) var turn_speed = 40
export(bool) var keep_jump_inertia = true
export(bool) var air_idle_deaccel = false
export(float) var accel = 19.0
export(float) var deaccel = 14.0
export(float) var sharp_turn_threshold = 140
export(float) var JumpHeight = 7.0



var prev_shoot = false



var shoot_blend = 0
#Signals
signal hit
signal shooting
signal dead
signal HasObjective
signal paused
signal reload_weapon

#Just ignore this variables. They are used for camera.
var yaw = 0
var pitch = 0
var cameraaim = Vector3()


#Change this stuff
export (float) var WALKSPEED = 3.1
export (float) var RUNSPEED = 4.5
export (PackedScene) var Playermodel
export (Vector3) var worldsize #This should be a 3d area that delmits the space of the scene
export(bool) var active=true
export(float) var view_sensitivity = 5

##Physics
export(float) var grav = 9.8
var gravity = Vector3(0,-grav,0)

var max_speed
var velocity = Vector3()
var linear_velocity=Vector3()


#Rotates the model to where the camera points
func adjust_facing(p_facing, p_target, p_step, p_adjust_rate, current_gn):
	var n = p_target # Normal
	var t = n.cross(current_gn).normalized()

	var x = n.dot(p_facing)
	var y = t.dot(p_facing)

	var ang = atan2(y,x)

	if (abs(ang) < 0.001): # Too small
		return p_facing

	var s = sign(ang)
	ang = ang*s
	var turn = ang*p_adjust_rate*p_step
	var a
	if (ang < turn):
		a = ang
	else:
		a = turn
	ang = (ang - a)*s

	return (n*cos(ang) + t*sin(ang))*p_facing.length()


func _physics_process(delta):
	#	var d = 1.0 - delta*state.get_total_density()
#	if (d < 0):
#		d = 0
#Changes acceleration and max speed.
	if (Input.is_action_pressed("run")):
		max_speed=RUNSPEED
	else:
		max_speed=WALKSPEED


	linear_velocity += gravity*delta # Apply gravity

	var anim = ANIM_FLOOR

	var up = -gravity.normalized() # (up is against gravity)
	var vertical_velocity = up.dot(linear_velocity) # Vertical velocity
	var horizontal_velocity = linear_velocity - up*vertical_velocity # Horizontal velocity
	var hdir = horizontal_velocity.normalized() # Horizontal direction
	var hspeed = horizontal_velocity.length() # Horizontal speed



	var dir = Vector3() # Where does the player intend to walk to
	var aim = $Camera.get_global_transform().basis

	if (Input.is_action_pressed("move_forwards")):
		dir -= aim[2]
	if (Input.is_action_pressed("move_backwards")):
		dir += aim[2]
	if (Input.is_action_pressed("move_left")):
		dir -= aim[0]
	if (Input.is_action_pressed("move_right")):
		dir += aim[0]

	var jump_attempt = Input.is_action_pressed("jump")
	var shoot_attempt = Input.is_action_pressed("shoot")

	var target_dir = (dir - up*dir.dot(up)).normalized()

	if (is_on_floor()):
		var sharp_turn = hspeed > 0.1 and rad2deg(acos(target_dir.dot(hdir))) > sharp_turn_threshold

		if (dir.length() > 0.1 and !sharp_turn):
			if (hspeed > 0.001):
				#linear_dir = linear_h_velocity/linear_vel
				#if (linear_vel > brake_velocity_limit and linear_dir.dot(ctarget_dir) < -cos(Math::deg2rad(brake_angular_limit)))
				#	brake = true
				#else
				hdir = adjust_facing(hdir, target_dir, delta, 1.0/hspeed*turn_speed, up)
				facing_dir = hdir
			else:
				hdir = target_dir

			if (hspeed < max_speed):
				hspeed += accel*delta
		else:
			hspeed -= deaccel*delta
			if (hspeed < 0):
				hspeed = 0

		horizontal_velocity = hdir*hspeed
#Yaw is a placeholder for the actual model that is going to be used
		var mesh_xform = $Yaw.get_transform()
		var facing_mesh = -mesh_xform.basis[0].normalized()
		facing_mesh = (facing_mesh - up*facing_mesh.dot(up)).normalized()

		if (hspeed>0):
			facing_mesh = adjust_facing(facing_mesh, target_dir, delta, 1.0/hspeed*turn_speed, up)
		var m3 = Basis(-facing_mesh, up, -facing_mesh.cross(up).normalized()).scaled(CHAR_SCALE)

		$Yaw.set_transform(Transform(m3, mesh_xform.origin))

		if (not jumping and jump_attempt):
			vertical_velocity = JumpHeight
			jumping = true
			#get_node("sound_jump").play()
	else:
		if (vertical_velocity > 0):
			print(ANIM_AIR_UP)
		else:
			print(ANIM_AIR_DOWN)
		if (dir.length() > 0.1):
			horizontal_velocity += target_dir*accel*delta
			if (horizontal_velocity.length() > max_speed):
				horizontal_velocity = horizontal_velocity.normalized()*max_speed
		else:
			if (air_idle_deaccel):
				hspeed = hspeed - (deaccel*0.2)*delta
				if (hspeed < 0):
					hspeed = 0

				horizontal_velocity = hdir*hspeed

	if (jumping and vertical_velocity < 0):
		jumping = false

	linear_velocity = horizontal_velocity + up*vertical_velocity

	if (is_on_floor()):
		movement_dir = linear_velocity

	linear_velocity = move_and_slide(linear_velocity,-gravity.normalized())

	if (shoot_blend > 0):
		shoot_blend -= delta*SHOOT_SCALE
		if (shoot_blend < 0):
			shoot_blend = 0

	#if (shoot_attempt and not prev_shoot):
		#shoot_blend = SHOOT_TIME
		#var bullet = preload("res://bullet.scn").instance()
#		bullet.set_transform(get_node("Armature/bullet").get_global_transform().orthonormalized())
	#	get_parent().add_child(bullet)
		#bullet.set_linear_velocity(get_node("Armature/bullet").get_global_transform().basis[2].normalized()*20)
		#bullet.add_collision_exception_with(self) # Add it to bullet
		#get_node("sound_shoot").play()

	prev_shoot = shoot_attempt

	#if (is_on_floor()):
		#get_node("AnimationTreePlayer").blend2_node_set_amount("walk", hspeed/max_speed)

	#get_node("AnimationTreePlayer").transition_node_set_current("state", anim)
	#get_node("AnimationTreePlayer").blend2_node_set_amount("gun", min(shoot_blend, 1.0))
#	state.set_angular_velocity(Vector3())

func _ready():
#	get_node("AnimationTreePlayer").set_active(true)
	set_process_input(true)
	set_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


		#get_node("Crosshair").set_crosshair(1)

	##Ported succesfuly from eco-controller
func _input(ev):

	if not active:
		return
	if (ev is InputEventMouseMotion):
		yaw = yaw - ev.relative.x * view_sensitivity
		pitch = clamp(pitch - ev.relative.y * view_sensitivity,-4500,4500)
		$Camera.rotation_degrees = Vector3(deg2rad(pitch), deg2rad(yaw), 0)
