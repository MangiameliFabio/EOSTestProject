extends Control

const product_id: String = "8a60a3308aab4f4d9853d719b2946bbd"
const sandbox_id: String = "236058128610414a89b2df274651e937"
const deployment_id: String = "c1a3bca1987e4b8eacdd60490cb88b56"
const client_id: String = "xyza78919hRQE7JfpxAHpWZgGkXHizPN"
const client_secret: String = "8ub30YmgRJ8iqSPvgz5Sg0bIchWBdRiT1OKiMXNnTyQ"
const encryption_key: String = "" 

const MAX_CONNECTIONS = 20

var  eos_main_peer : EOSGMultiplayerPeer

var user_id_patrick : String = "00029e58b276424b9c85d3b97c5a62f8"
var user_id_fabio_laptop : String = "0002819d72664b7fb09f898104452f58"
var user_id_office_pc : String = ""
var own_user_id : String = ""

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
	eos_main_peer = EOSGMultiplayerPeer.new()
	eos_main_peer.peer_connected.connect(_on_peer_connected)
	
	var error := eos_main_peer.create_mesh("main")
	if error:
		%EOSMessagesLabel.text += "Cannot create mesh | Error: %s \n" % error
	else:
		%EOSMessagesLabel.text += "Created mesh with socket id: main \n"
		%CreateMesh.disabled = true

func _connect_to_fabio():
	if own_user_id == user_id_fabio_laptop:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_main_peer:
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_main_peer.add_mesh_peer(user_id_fabio_laptop)
	%ConnectToFabio.disabled = true

func _connect_to_patrick():
	if own_user_id == user_id_patrick:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_main_peer:
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_main_peer.add_mesh_peer(user_id_patrick)
	%ConnectToPatrick.disabled = true

func _connect_to_office_pc():
	if own_user_id == user_id_office_pc:
		%EOSMessagesLabel.text += "Don't connect to yourself!\n"
		return
	if not eos_main_peer:
		%EOSMessagesLabel.text += "MultiplayerPeer not initialized\n"
		return
	
	eos_main_peer.add_mesh_peer(user_id_office_pc)
	%ConnectToOffice.disabled = true

func _on_peer_connected(id: int):
	%SendButton.disabled = false
	%EOSMessagesLabel.text += "Peer %d connected\n" % id

func _process(_delta: float) -> void:
	if not eos_main_peer: return
	
	eos_main_peer.poll()
	
	while(eos_main_peer.get_available_packet_count()):
		var sender := eos_main_peer.get_packet_peer()
		
		var recived_packed := eos_main_peer.get_packet()
		
		if not recived_packed:
			printerr("PAcket is invalid")
			return
		
		var type : int = recived_packed.decode_u8(0)
		
		match(type):
			1: %Chat.text += "%d: %s \n" % [sender, recived_packed.decode_var(1)]
	
	#while (_multiplayer_peer->get_available_packet_count()) {
		#int sender = _multiplayer_peer->get_packet_peer();
		#const uint8_t *packet;
		#int len;
#
		#Error err = _multiplayer_peer->get_packet(&packet, len);
		#ERR_FAIL_COND_V_MSG(err != OK, err, vformat("Error getting packet! %d", err));
#
		#_remote_sender_id = sender;
		#process_packet(sender, packet, len);
		#_remote_sender_id = 0;
#
		#update_status();
		#if (last_connection_status != MultiplayerPeer::CONNECTION_CONNECTED) { // It's possible that processing a packet might have resulted in a disconnection, so check here.
			#return OK;
		#}
	#}
	
	%ConnectedPeers.text = ""
	
	var peers := eos_main_peer.get_all_peers()
	for peer in peers:
		%ConnectedPeers.text += "Peer ID: %d | User ID: %s \n" % [peer, peers[peer]]

func _on_send():
	var msg = %ChatMessage.text
	%ChatMessage.text = ""
	
	%Chat.text += "%d: %s \n" % [eos_main_peer.get_unique_id(), msg]
	
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_8(1)
	buffer.put_string(msg)
	
	eos_main_peer.put_packet(buffer.data_array)
