extends RefCounted
## Original small solid props; common palette with the cast and environment.
static func handheld(kind: String) -> bool:
	return kind not in ["plant","fridge","bench","drum"]

static func piece(root: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	node.material_override = mat
	root.add_child(node)

static func build(kind: String, p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "StoryProp_"+kind
	var paper: Color = p.get("paper",Color("dddbc3"))
	var ink: Color = p.get("ink",Color("172e38"))
	var accent: Color = p.get("accent",Color("bc6652"))
	var wood: Color = p.get("wood",Color("8f6a50"))
	var warm: Color = p.get("warm",Color("efbd76"))
	match kind:
		"book","ledger","notebook","contract","report","bill","exam":
			piece(root,Vector3(.38,.045,.29),Vector3.ZERO,accent if kind in ["book","ledger","notebook"] else ink)
			piece(root,Vector3(.34,.025,.265),Vector3(0,.032,0),paper)
			for line in range(4): piece(root,Vector3(.22,.005,.012),Vector3(0,.048,-.08+line*.045),ink)
		"photo","badge":
			piece(root,Vector3(.32,.30,.035),Vector3.ZERO,paper)
			piece(root,Vector3(.26,.22,.015),Vector3(0,.02,.025),p.sky)
			piece(root,Vector3(.075,.07,.02),Vector3(0,.05,.04),warm)
			piece(root,Vector3(.13,.09,.02),Vector3(0,-.025,.04),accent)
		"phone":
			piece(root,Vector3(.16,.28,.045),Vector3.ZERO,ink)
			piece(root,Vector3(.13,.21,.015),Vector3(0,.01,.03),p.sky)
			for line in range(3): piece(root,Vector3(.09,.015,.01),Vector3(0,.06-line*.045,.04),paper)
		"flashlight":
			piece(root,Vector3(.10,.11,.32),Vector3.ZERO,ink)
			piece(root,Vector3(.16,.16,.065),Vector3(0,0,.17),warm)
			piece(root,Vector3(.12,.12,.018),Vector3(0,0,.212),paper)
		"key":
			piece(root,Vector3(.12,.035,.12),Vector3(-.12,0,0),warm)
			piece(root,Vector3(.24,.035,.035),Vector3(.03,0,0),warm)
			for x in [.07,.13]: piece(root,Vector3(.035,.035,.07),Vector3(x,0,.035),warm)
		"plant":
			piece(root,Vector3(.26,.23,.26),Vector3(0,.115,0),accent)
			piece(root,Vector3(.035,.28,.035),Vector3(0,.34,0),p.leaf)
			for row in range(3): piece(root,Vector3(.28-row*.055,.07,.13),Vector3((row%2-.5)*.08,.28+row*.09,0),p.leaf.lightened(row*.06))
		"fridge":
			piece(root,Vector3(.85,1.55,.65),Vector3(0,.775,0),paper)
			piece(root,Vector3(.78,.035,.035),Vector3(0,1.06,.34),ink)
			piece(root,Vector3(.035,.26,.07),Vector3(.28,.84,.36),ink)
			piece(root,Vector3(.18,.16,.015),Vector3(-.18,1.3,.34),warm)
		"bench":
			for x in [-.60,.60]: piece(root,Vector3(.10,.48,.48),Vector3(x,.24,0),ink)
			piece(root,Vector3(1.6,.10,.55),Vector3(0,.53,0),wood)
			piece(root,Vector3(1.6,.36,.09),Vector3(0,.88,-.25),wood)
		"drum":
			piece(root,Vector3(.43,.35,.40),Vector3.ZERO,accent)
			piece(root,Vector3(.47,.035,.44),Vector3(0,.19,0),paper)
			for x in [-.20,.20]: piece(root,Vector3(.025,.37,.025),Vector3(x,0,.2),ink)
		"eggs":
			piece(root,Vector3(.35,.10,.25),Vector3(0,-.08,0),wood)
			for x in [-.10,.10]:
				for z in [-.065,.065]: piece(root,Vector3(.12,.16,.10),Vector3(x,.02,z),paper)
			piece(root,Vector3(.025,.25,.025),Vector3(-.17,.08,0),accent)
			piece(root,Vector3(.025,.25,.025),Vector3(.17,.08,0),accent)
			piece(root,Vector3(.36,.025,.025),Vector3(0,.21,0),accent)
		"meal","noodles":
			piece(root,Vector3(.32,.14,.30),Vector3.ZERO,paper)
			for i in range(4): piece(root,Vector3(.22,.015,.025),Vector3(0,.08,-.09+i*.055),warm)
		"biscuit":
			piece(root,Vector3(.24,.05,.23),Vector3.ZERO,warm)
			for x in [-.06,.06]: piece(root,Vector3(.025,.01,.025),Vector3(x,.03,.04),wood)
		"eraser":
			piece(root,Vector3(.21,.07,.10),Vector3.ZERO,paper)
			piece(root,Vector3(.12,.075,.105),Vector3(-.04,0,0),p.sky)
		"tooth":
			piece(root,Vector3(.10,.09,.09),Vector3.ZERO,paper)
			for x in [-.035,.035]: piece(root,Vector3(.025,.08,.035),Vector3(x,-.07,0),paper)
		_:
			piece(root,Vector3(.34,.055,.28),Vector3.ZERO,paper)
			piece(root,Vector3(.34,.02,.05),Vector3(0,.04,.10),p.mid)
	return root
