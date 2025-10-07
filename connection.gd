extends Control

const product_id: String = "8a60a3308aab4f4d9853d719b2946bbd"
const sandbox_id: String = "236058128610414a89b2df274651e937"
const deployment_id: String = "c1a3bca1987e4b8eacdd60490cb88b56"
const client_id: String = "xyza78919hRQE7JfpxAHpWZgGkXHizPN"
const client_secret: String = "8ub30YmgRJ8iqSPvgz5Sg0bIchWBdRiT1OKiMXNnTyQ"
const encryption_key: String = "" 

const MAX_CONNECTIONS = 20

var user_id_patrick : String = "00029e58b276424b9c85d3b97c5a62f8"
var user_id_fabio_laptop : String = "0002819d72664b7fb09f898104452f58"
var user_id_office_pc : String = "0002fc098f044e70a0fec3e04e3d7a0b"
var own_user_id : String = ""

var current_mesh_id : String = ""

var eos_peers = {}
var chat_contents = {}

enum State {
	NotInitialized,
	Initializing,
	InitializedAndLoggedIn,
	CreatingServer,
	ServerCreated,
	JoiningServer,
	ServerJoined
}
var current_state : State = State.NotInitialized
# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_state(State.NotInitialized)
	
func set_state(new_state:State):
	current_state = new_state

func _on_init_EOS_clicked():
	set_state(State.Initializing)
	# Initialize the SDK
	var init_options = EOS.Platform.InitializeOptions.new()
	init_options.product_name = "Codename Frozen Bulgur"
	init_options.product_version = "1.0"

	var init_result := EOS.Platform.PlatformInterface.initialize(init_options)
	if init_result != EOS.Result.Success:
		print("Failed to initialize EOS SDK: ", EOS.result_str(init_result))
		%EOSMessagesLabel.text = "Failed to initialize EOS SDK: %s\n" % EOS.result_str(init_result)
		set_state(State.NotInitialized)
		return
	%EOSMessagesLabel.text = "Initialized EOS Platform\n"

	# Create platform
	var create_options = EOS.Platform.CreateOptions.new()
	create_options.product_id = product_id
	create_options.sandbox_id = sandbox_id
	create_options.deployment_id = deployment_id
	create_options.client_id = client_id
	create_options.client_secret = client_secret
	create_options.encryption_key = encryption_key
	
	EOS.Platform.PlatformInterface.create(create_options)
		
	%EOSMessagesLabel.text += "EOS Platform Created\n"

	# Setup Logs from EOS
	EOS.get_instance().logging_interface_callback.connect(_on_logging_interface_callback)
	EOS.get_instance().p2p_interface_query_nat_type_callback.connect(_update_nat_type)

	var res := EOS.Logging.set_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Info)
	if res != EOS.Result.Success:
		%EOSMessagesLabel.text += "Failed to set log level: %s\n" % EOS.result_str(res)
	
	EOS.get_instance().connect_interface_login_callback.connect(_on_connect_login_callback)

	await get_tree().process_frame
	_anon_login()

func _on_logging_interface_callback(msg) -> void:
	msg = EOS.Logging.LogMessage.from(msg) as EOS.Logging.LogMessage
	print("SDK %s | %s" % [msg.category, msg.message])
	%EOSLogLabel.text += "SDK %s | %s\n" % [msg.category, msg.message]

func _anon_login() -> void:
	# Login using Device ID (no user interaction/credentials required)
	var opts = EOS.Connect.CreateDeviceIdOptions.new()
	opts.device_model = OS.get_name() + " " + OS.get_model_name()
	EOS.Connect.ConnectInterface.create_device_id(opts)
	await EOS.get_instance().connect_interface_create_device_id_callback

	var credentials = EOS.Connect.Credentials.new()
	credentials.token = null
	credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken

	var login_options = EOS.Connect.LoginOptions.new()
	login_options.credentials = credentials
	var user_login_info = EOS.Connect.UserLoginInfo.new()
	user_login_info.display_name = "User"
	login_options.user_login_info = user_login_info
	EOS.Connect.ConnectInterface.login(login_options)
	
	%InitializeButton.disabled = true

func _on_connect_login_callback(data: Dictionary) -> void:
	if not data.success:
		print("Login failed")
		EOS.print_result(data)
		%EOSMessagesLabel.text += "Login Failed\n"
		set_state(State.NotInitialized)
		return
		
	own_user_id = data.local_user_id
	%UserID.text = data.local_user_id
	print_rich("[b]Login successfull[/b]: local_user_id=", data.local_user_id)
	EOS.P2P.P2PInterface.query_nat_type()
	
	set_state(State.InitializedAndLoggedIn)

func _update_nat_type(data: Dictionary) -> void:
	if current_state == State.NotInitialized: return
	
	if not data.has("nat_type"): return
	
	var nat_type = data["nat_type"]
	%NatType.text = "NatType: %s" % EOS.P2P.NATType.keys()[nat_type]

func _create_mesh():
	var eos_peer = EOSGMultiplayerPeer.new()
	eos_peer.peer_connected.connect(_on_peer_connected)
	
	var socket_id = %SocketID.text
	if socket_id == "":
		socket_id = "main"
	
	var error := eos_peer.create_mesh(socket_id)
	if error:
		%EOSMessagesLabel.text += "Cannot create mesh | Error: %s \n" % error
		return

	%EOSMessagesLabel.text += "Created mesh with socket id: main \n"

	var tab_amount = %MeshTabs.tab_count

	for i in range(tab_amount):
		var titel : String = %MeshTabs.get_tab_title(i)
		if titel == socket_id:
			%EOSMessagesLabel.text += "Socket id already added!\n"
			return
	
	%MeshTabs.add_tab(socket_id)
	%MeshTabs.current_tab = %MeshTabs.tab_count - 1
	current_mesh_id = socket_id
	
	eos_peers[socket_id] = eos_peer

func _connect_to_fabio():
	if own_user_id == user_id_fabio_laptop:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_peers.has(current_mesh_id):
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_peers[current_mesh_id].add_mesh_peer(user_id_fabio_laptop)
	%ConnectToFabio.disabled = true

func _connect_to_patrick():
	if own_user_id == user_id_patrick:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_peers.has(current_mesh_id):
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_peers[current_mesh_id].add_mesh_peer(user_id_patrick)
	%ConnectToPatrick.disabled = true

func _connect_to_office_pc():
	if own_user_id == user_id_office_pc:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_peers.has(current_mesh_id):
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_peers[current_mesh_id].add_mesh_peer(user_id_office_pc)
	%ConnectToOffice.disabled = true

func _on_peer_connected(id: int):
	%SendButton.disabled = false
	%EOSMessagesLabel.text += "Peer %d connected\n" % id

func _process(_delta: float) -> void:
	for socket_id in eos_peers:
		if not eos_peers[socket_id]: return
		
		eos_peers[socket_id].poll()
		
		while(eos_peers[socket_id].get_available_packet_count()):
			var sender : int = eos_peers[socket_id].get_packet_peer()
			
			var recived_packed : PackedByteArray = eos_peers[socket_id].get_packet()
			
			if not recived_packed:
				printerr("Packet is invalid")
				return

			var buffer := StreamPeerBuffer.new()
			buffer.data_array = recived_packed
			
			var type : int = buffer.get_8()
			
			match(type):
				1: 
					if current_mesh_id == socket_id:
						%Chat.text += "%d: %s \n" % [sender, buffer.get_string()]
					else:
						chat_contents[socket_id] += "%d: %s \n" % [sender, buffer.get_string()]
		
		%ConnectedPeers.text = ""
	
	if eos_peers.has(current_mesh_id):
		var peers : Dictionary = eos_peers[current_mesh_id].get_all_peers()
		for peer in peers:
			%ConnectedPeers.text += "Peer ID: %d | User ID: %s \n" % [peer, peers[peer]]

func _on_send():
	var msg = %ChatMessage.text
	%ChatMessage.text = ""
	
	%Chat.text += "%d: %s \n" % [eos_peers[current_mesh_id].get_unique_id(), msg]
	
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_8(1)
	buffer.put_string(msg)
	
	#eos_main_peer.set_target_peer()
	eos_peers[current_mesh_id].put_packet(buffer.data_array)


func _on_mesh_tabs_tab_changed(tab: int) -> void:
	chat_contents[current_mesh_id] = %Chat.text
	%Chat.text = ""
	current_mesh_id = %MeshTabs.get_tab_title(tab)
	
	if chat_contents.has(current_mesh_id):
		%Chat.text = chat_contents[current_mesh_id]
