/*
Magichet
Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include <iostream>
#include <algorithm>
#include <sstream>
#include <IFileSystem.h>
#include "jthread/jmutexautolock.h"
#include "util/auth.h"
#include "util/directiontables.h"
#include "util/pointedthing.h"
#include "util/serialize.h"
#include "util/string.h"
#include "util/srp.h"
#include "client.h"
#include "network/clientopcodes.h"
#include "filesys.h"
#include "porting.h"
#include "mapblock_mesh.h"
#include "mapblock.h"
#include "minimap.h"
#include "settings.h"
#include "profiler.h"
#include "gettext.h"
#include "log.h"
#include "nodemetadata.h"
#include "itemdef.h"
#include "shader.h"
#include "clientmap.h"
#include "clientmedia.h"
#include "sound.h"
#include "IMeshCache.h"
#include "config.h"
#include "version.h"
#include "drawscene.h"
#include "database-sqlite3.h"
#include "serialization.h"
#include "guiscalingfilter.h"

extern gui::IGUIEnvironment* guienv;

/*
	QueuedMeshUpdate
*/

QueuedMeshUpdate::QueuedMeshUpdate():
	p(-1337,-1337,-1337),
	data(NULL),
	ack_block_to_server(false)
{
}

QueuedMeshUpdate::~QueuedMeshUpdate()
{
	if(data)
		delete data;
}

/*
	MeshUpdateQueue
*/

MeshUpdateQueue::MeshUpdateQueue()
{
}

MeshUpdateQueue::~MeshUpdateQueue()
{
	JMutexAutoLock lock(m_mutex);

	for(std::vector<QueuedMeshUpdate*>::iterator
			i = m_queue.begin();
			i != m_queue.end(); i++)
	{
		QueuedMeshUpdate *q = *i;
		delete q;
	}
}

/*
	peer_id=0 adds with nobody to send to
*/
void MeshUpdateQueue::addBlock(v3s16 p, MeshMakeData *data, bool ack_block_to_server, bool urgent)
{
	DSTACK(__FUNCTION_NAME);

	assert(data);	// pre-condition

	JMutexAutoLock lock(m_mutex);

	if(urgent)
		m_urgents.insert(p);

	/*
		Find if block is already in queue.
		If it is, update the data and quit.
	*/
	for(std::vector<QueuedMeshUpdate*>::iterator
			i = m_queue.begin();
			i != m_queue.end(); i++)
	{
		QueuedMeshUpdate *q = *i;
		if(q->p == p)
		{
			if(q->data)
				delete q->data;
			q->data = data;
			if(ack_block_to_server)
				q->ack_block_to_server = true;
			return;
		}
	}

	/*
		Add the block
	*/
	QueuedMeshUpdate *q = new QueuedMeshUpdate;
	q->p = p;
	q->data = data;
	q->ack_block_to_server = ack_block_to_server;
	m_queue.push_back(q);
}

// Returned pointer must be deleted
// Returns NULL if queue is empty
QueuedMeshUpdate *MeshUpdateQueue::pop()
{
	JMutexAutoLock lock(m_mutex);

	bool must_be_urgent = !m_urgents.empty();
	for(std::vector<QueuedMeshUpdate*>::iterator
			i = m_queue.begin();
			i != m_queue.end(); i++)
	{
		QueuedMeshUpdate *q = *i;
		if(must_be_urgent && m_urgents.count(q->p) == 0)
			continue;
		m_queue.erase(i);
		m_urgents.erase(q->p);
		return q;
	}
	return NULL;
}

/*
	MeshUpdateThread
*/

void MeshUpdateThread::enqueueUpdate(v3s16 p, MeshMakeData *data,
		bool ack_block_to_server, bool urgent)
{
	m_queue_in.addBlock(p, data, ack_block_to_server, urgent);
	deferUpdate();
}

void MeshUpdateThread::doUpdate()
{
	QueuedMeshUpdate *q;
	while ((q = m_queue_in.pop())) {

		ScopeProfiler sp(g_profiler, "Client: Mesh making");

		MapBlockMesh *mesh_new = new MapBlockMesh(q->data, m_camera_offset);

		MeshUpdateResult r;
		r.p = q->p;
		r.mesh = mesh_new;
		r.ack_block_to_server = q->ack_block_to_server;

		m_queue_out.push_back(r);

		delete q;
	}
}

/*
	Client
*/

Client::Client(
		IrrlichtDevice *device,
		const char *playername,
		std::string password,
		MapDrawControl &control,
		IWritableTextureSource *tsrc,
		IWritableShaderSource *shsrc,
		IWritableItemDefManager *itemdef,
		IWritableNodeDefManager *nodedef,
		ISoundManager *sound,
		MtEventManager *event,
		bool ipv6
):
	m_packetcounter_timer(0.0),
	m_connection_reinit_timer(0.1),
	m_avg_rtt_timer(0.0),
	m_playerpos_send_timer(0.0),
	m_ignore_damage_timer(0.0),
	m_tsrc(tsrc),
	m_shsrc(shsrc),
	m_itemdef(itemdef),
	m_nodedef(nodedef),
	m_sound(sound),
	m_event(event),
	m_mesh_update_thread(),
	m_env(
		new ClientMap(this, this, control,
			device->getSceneManager()->getRootSceneNode(),
			device->getSceneManager(), 666),
		device->getSceneManager(),
		tsrc, this, device
	),
	m_particle_manager(&m_env),
	m_con(PROTOCOL_ID, 512, CONNECTION_TIMEOUT, ipv6, this),
	m_device(device),
	m_server_ser_ver(SER_FMT_VER_INVALID),
	m_proto_ver(0),
	m_playeritem(0),
	m_inventory_updated(false),
	m_inventory_from_server(NULL),
	m_inventory_from_server_age(0.0),
	m_show_highlighted(false),
	m_animation_time(0),
	m_crack_level(-1),
	m_crack_pos(0,0,0),
	m_highlighted_pos(0,0,0),
	m_map_seed(0),
	m_password(password),
	m_chosen_auth_mech(AUTH_MECHANISM_NONE),
	m_auth_data(NULL),
	m_access_denied(false),
	m_access_denied_reconnect(false),
	m_itemdef_received(false),
	m_nodedef_received(false),
	m_media_downloader(new ClientMediaDownloader()),
	m_time_of_day_set(false),
	m_last_time_of_day_f(-1),
	m_time_of_day_update_timer(0),
	m_recommended_send_interval(0.1),
	m_removed_sounds_check_timer(0),
	m_state(LC_Created),
	m_localdb(NULL)
{
	// Add local player
	m_env.addPlayer(new LocalPlayer(this, playername));

	m_mapper = new Mapper(device, this);
	m_cache_save_interval = g_settings->getU16("server_map_save_interval");

	m_cache_smooth_lighting = g_settings->getBool("smooth_lighting");
	m_cache_enable_shaders  = g_settings->getBool("enable_shaders");
}

void Client::Stop()
{
	//request all client managed threads to stop
	m_mesh_update_thread.Stop();
	// Save local server map
	if (m_localdb) {
		infostream << "Local map saving ended." << std::endl;
		m_localdb->endSave();
	}
}

bool Client::isShutdown()
{

	if (!m_mesh_update_thread.IsRunning()) return true;

	return false;
}

Client::~Client()
{
	m_con.Disconnect();

	m_mesh_update_thread.Stop();
	m_mesh_update_thread.Wait();
	while(!m_mesh_update_thread.m_queue_out.empty()) {
		MeshUpdateResult r = m_mesh_update_thread.m_queue_out.pop_frontNoEx();
		delete r.mesh;
	}


	delete m_inventory_from_server;

	// Delete detached inventories
	for(std::map<std::string, Inventory*>::iterator
			i = m_detached_inventories.begin();
			i != m_detached_inventories.end(); i++){
		delete i->second;
	}

	// cleanup 3d model meshes on client shutdown
	while (m_device->getSceneManager()->getMeshCache()->getMeshCount() != 0) {
		scene::IAnimatedMesh * mesh =
			m_device->getSceneManager()->getMeshCache()->getMeshByIndex(0);

		if (mesh != NULL)
			m_device->getSceneManager()->getMeshCache()->removeMesh(mesh);
	}
}

void Client::connect(Address address,
		const std::string &address_name,
		bool is_local_server)
{
	DSTACK(__FUNCTION_NAME);

	initLocalMapSaving(address, address_name, is_local_server);

	m_con.SetTimeoutMs(0);
	m_con.Connect(address);
}

void Client::step(float dtime)
{
	DSTACK(__FUNCTION_NAME);

	// Limit a bit
	if(dtime > 2.0)
		dtime = 2.0;

	if(m_ignore_damage_timer > dtime)
		m_ignore_damage_timer -= dtime;
	else
		m_ignore_damage_timer = 0.0;

	m_animation_time += dtime;
	if(m_animation_time > 60.0)
		m_animation_time -= 60.0;

	m_time_of_day_update_timer += dtime;

	ReceiveAll();

	/*
		Packet counter
	*/
	{
		float &counter = m_packetcounter_timer;
		counter -= dtime;
		if(counter <= 0.0)
		{
			counter = 20.0;

			infostream << "Client packetcounter (" << m_packetcounter_timer
					<< "):"<<std::endl;
			m_packetcounter.print(infostream);
			m_packetcounter.clear();
		}
	}

	// UGLY hack to fix 2 second startup delay caused by non existent
	// server client startup synchronization in local server or singleplayer mode
	static bool initial_step = true;
	if (initial_step) {
		initial_step = false;
	}
	else if(m_state == LC_Created) {
		float &counter = m_connection_reinit_timer;
		counter -= dtime;
		if(counter <= 0.0) {
			counter = 2.0;

			Player *myplayer = m_env.getLocalPlayer();
			FATAL_ERROR_IF(myplayer == NULL, "Local player not found in environment.");

			// Send TOSERVER_INIT_LEGACY
			// [0] u16 TOSERVER_INIT_LEGACY
			// [2] u8 SER_FMT_VER_HIGHEST_READ
			// [3] u8[20] player_name
			// [23] u8[28] password (new in some version)
			// [51] u16 minimum supported network protocol version (added sometime)
			// [53] u16 maximum supported network protocol version (added later than the previous one)

			char pName[PLAYERNAME_SIZE];
			char pPassword[PASSWORD_SIZE];
			memset(pName, 0, PLAYERNAME_SIZE * sizeof(char));
			memset(pPassword, 0, PASSWORD_SIZE * sizeof(char));

			std::string hashed_password = translatePassword(myplayer->getName(), m_password);
			snprintf(pName, PLAYERNAME_SIZE, "%s", myplayer->getName());
			snprintf(pPassword, PASSWORD_SIZE, "%s", hashed_password.c_str());

			sendLegacyInit(pName, pPassword);
			if (LATEST_PROTOCOL_VERSION >= 25)
				sendInit(myplayer->getName());
		}

		// Not connected, return
		return;
	}

	/*
		Do stuff if connected
	*/

	/*
		Run Map's timers and unload unused data
	*/
	const float map_timer_and_unload_dtime = 5.25;
	if(m_map_timer_and_unload_interval.step(dtime, map_timer_and_unload_dtime)) {
		ScopeProfiler sp(g_profiler, "Client: map timer and unload");
		std::vector<v3s16> deleted_blocks;
		m_env.getMap().timerUpdate(map_timer_and_unload_dtime,
				g_settings->getFloat("client_unload_unused_data_timeout"),
				&deleted_blocks);

		/*
			Send info to server
			NOTE: This loop is intentionally iterated the way it is.
		*/

		std::vector<v3s16>::iterator i = deleted_blocks.begin();
		std::vector<v3s16> sendlist;
		for(;;) {
			if(sendlist.size() == 255 || i == deleted_blocks.end()) {
				if(sendlist.empty())
					break;
				/*
					[0] u16 command
					[2] u8 count
					[3] v3s16 pos_0
					[3+6] v3s16 pos_1
					...
				*/

				sendDeletedBlocks(sendlist);

				if(i == deleted_blocks.end())
					break;

				sendlist.clear();
			}

			sendlist.push_back(*i);
			++i;
		}
	}

	/*
		Handle environment
	*/
	// Control local player (0ms)
	LocalPlayer *player = m_env.getLocalPlayer();
	assert(player != NULL);
	player->applyControl(dtime, &m_env);

	// Step environment
	m_env.step(dtime);

	/*
		Get events
	*/
	for(;;) {
		ClientEnvEvent event = m_env.getClientEvent();
		if(event.type == CEE_NONE) {
			break;
		}
		else if(event.type == CEE_PLAYER_DAMAGE) {
			if(m_ignore_damage_timer <= 0) {
				u8 damage = event.player_damage.amount;

				if(event.player_damage.send_to_server)
					sendDamage(damage);

				// Add to ClientEvent queue
				ClientEvent event;
				event.type = CE_PLAYER_DAMAGE;
				event.player_damage.amount = damage;
				m_client_event_queue.push(event);
			}
		}
		else if(event.type == CEE_PLAYER_BREATH) {
				u16 breath = event.player_breath.amount;
				sendBreath(breath);
		}
	}

	/*
		Print some info
	*/
	float &counter = m_avg_rtt_timer;
	counter += dtime;
	if(counter >= 10) {
		counter = 0.0;
		// connectedAndInitialized() is true, peer exists.
		float avg_rtt = getRTT();
		infostream << "Client: avg_rtt=" << avg_rtt << std::endl;
	}

	/*
		Send player position to server
	*/
	{
		float &counter = m_playerpos_send_timer;
		counter += dtime;
		if((m_state == LC_Ready) && (counter >= m_recommended_send_interval))
		{
			counter = 0.0;
			sendPlayerPos();
		}
	}

	/*
		Replace updated meshes
	*/
	{
		int num_processed_meshes = 0;
		while (!m_mesh_update_thread.m_queue_out.empty())
		{
			num_processed_meshes++;

			MinimapMapblock *minimap_mapblock = NULL;
			bool do_mapper_update = true;

			MeshUpdateResult r = m_mesh_update_thread.m_queue_out.pop_frontNoEx();
			MapBlock *block = m_env.getMap().getBlockNoCreateNoEx(r.p);
			if (block) {
				// Delete the old mesh
				if (block->mesh != NULL) {
					delete block->mesh;
					block->mesh = NULL;
				}

				if (r.mesh) {
					minimap_mapblock = r.mesh->moveMinimapMapblock();
					if (minimap_mapblock == NULL)
						do_mapper_update = false;
				}

				if (r.mesh && r.mesh->getMesh()->getMeshBufferCount() == 0) {
					delete r.mesh;
				} else {
					// Replace with the new mesh
					block->mesh = r.mesh;
				}
			} else {
				delete r.mesh;
			}

			if (do_mapper_update)
				m_mapper->addBlock(r.p, minimap_mapblock);

			if (r.ack_block_to_server) {
				/*
					Acknowledge block
					[0] u8 count
					[1] v3s16 pos_0
				*/
				sendGotBlocks(r.p);
			}
		}

		if (num_processed_meshes > 0)
			g_profiler->graphAdd("num_processed_meshes", num_processed_meshes);
	}

	/*
		Load fetched media
	*/
	if (m_media_downloader && m_media_downloader->isStarted()) {
		m_media_downloader->step(this);
		if (m_media_downloader->isDone()) {
			received_media();
			delete m_media_downloader;
			m_media_downloader = NULL;
		}
	}

	/*
		If the server didn't update the inventory in a while, revert
		the local inventory (so the player notices the lag problem
		and knows something is wrong).
	*/
	if(m_inventory_from_server)
	{
		float interval = 10.0;
		float count_before = floor(m_inventory_from_server_age / interval);

		m_inventory_from_server_age += dtime;

		float count_after = floor(m_inventory_from_server_age / interval);

		if(count_after != count_before)
		{
			// Do this every <interval> seconds after TOCLIENT_INVENTORY
			// Reset the locally changed inventory to the authoritative inventory
			Player *player = m_env.getLocalPlayer();
			player->inventory = *m_inventory_from_server;
			m_inventory_updated = true;
		}
	}

	/*
		Update positions of sounds attached to objects
	*/
	{
		for(std::map<int, u16>::iterator
				i = m_sounds_to_objects.begin();
				i != m_sounds_to_objects.end(); i++)
		{
			int client_id = i->first;
			u16 object_id = i->second;
			ClientActiveObject *cao = m_env.getActiveObject(object_id);
			if(!cao)
				continue;
			v3f pos = cao->getPosition();
			m_sound->updateSoundPosition(client_id, pos);
		}
	}

	/*
		Handle removed remotely initiated sounds
	*/
	m_removed_sounds_check_timer += dtime;
	if(m_removed_sounds_check_timer >= 2.32) {
		m_removed_sounds_check_timer = 0;
		// Find removed sounds and clear references to them
		std::vector<s32> removed_server_ids;
		for(std::map<s32, int>::iterator
				i = m_sounds_server_to_client.begin();
				i != m_sounds_server_to_client.end();) {
			s32 server_id = i->first;
			int client_id = i->second;
			i++;
			if(!m_sound->soundExists(client_id)) {
				m_sounds_server_to_client.erase(server_id);
				m_sounds_client_to_server.erase(client_id);
				m_sounds_to_objects.erase(client_id);
				removed_server_ids.push_back(server_id);
			}
		}

		// Sync to server
		if(!removed_server_ids.empty()) {
			sendRemovedSounds(removed_server_ids);
		}
	}

	// Write server map
	if (m_localdb && m_localdb_save_interval.step(dtime,
			m_cache_save_interval)) {
		m_localdb->endSave();
		m_localdb->beginSave();
	}
}

bool Client::loadMedia(const std::string &data, const std::string &filename)
{
	// Silly irrlicht's const-incorrectness
	Buffer<char> data_rw(data.c_str(), data.size());

	std::string name;

	const char *image_ext[] = {
		".png", ".jpg", ".bmp", ".tga",
		".pcx", ".ppm", ".psd", ".wal", ".rgb",
		NULL
	};
	name = removeStringEnd(filename, image_ext);
	if(name != "")
	{
		verbosestream<<"Client: Attempting to load image "
		<<"file \""<<filename<<"\""<<std::endl;

		io::IFileSystem *irrfs = m_device->getFileSystem();
		video::IVideoDriver *vdrv = m_device->getVideoDriver();

		// Create an irrlicht memory file
		io::IReadFile *rfile = irrfs->createMemoryReadFile(
				*data_rw, data_rw.getSize(), "_tempreadfile");

		FATAL_ERROR_IF(!rfile, "Could not create irrlicht memory file.");

		// Read image
		video::IImage *img = vdrv->createImageFromFile(rfile);
		if(!img){
			errorstream<<"Client: Cannot create image from data of "
					<<"file \""<<filename<<"\""<<std::endl;
			rfile->drop();
			return false;
		}
		else {
			m_tsrc->insertSourceImage(filename, img);
			img->drop();
			rfile->drop();
			return true;
		}
	}

	const char *sound_ext[] = {
		".0.ogg", ".1.ogg", ".2.ogg", ".3.ogg", ".4.ogg",
		".5.ogg", ".6.ogg", ".7.ogg", ".8.ogg", ".9.ogg",
		".ogg", NULL
	};
	name = removeStringEnd(filename, sound_ext);
	if(name != "")
	{
		verbosestream<<"Client: Attempting to load sound "
		<<"file \""<<filename<<"\""<<std::endl;
		m_sound->loadSoundData(name, data);
		return true;
	}

	const char *model_ext[] = {
		".x", ".b3d", ".md2", ".obj",
		NULL
	};
	name = removeStringEnd(filename, model_ext);
	if(name != "")
	{
		verbosestream<<"Client: Storing model into memory: "
				<<"\""<<filename<<"\""<<std::endl;
		if(m_mesh_data.count(filename))
			errorstream<<"Multiple models with name \""<<filename.c_str()
					<<"\" found; replacing previous model"<<std::endl;
		m_mesh_data[filename] = data;
		return true;
	}

	errorstream<<"Client: Don't know how to load file \""
			<<filename<<"\""<<std::endl;
	return false;
}

// Virtual methods from con::PeerHandler
void Client::peerAdded(con::Peer *peer)
{
	infostream << "Client::peerAdded(): peer->id="
			<< peer->id << std::endl;
}
void Client::deletingPeer(con::Peer *peer, bool timeout)
{
	infostream << "Client::deletingPeer(): "
			"Server Peer is getting deleted "
			<< "(timeout=" << timeout << ")" << std::endl;

	if (timeout) {
		m_access_denied = true;
		m_access_denied_reason = gettext("Connection timed out.");
	}
}

/*
	u16 command
	u16 number of files requested
	for each file {
		u16 length of name
		string name
	}
*/
void Client::request_media(const std::vector<std::string> &file_requests)
{
	std::ostringstream os(std::ios_base::binary);
	writeU16(os, TOSERVER_REQUEST_MEDIA);
	size_t file_requests_size = file_requests.size();

	FATAL_ERROR_IF(file_requests_size > 0xFFFF, "Unsupported number of file requests");

	// Packet dynamicly resized
	NetworkPacket pkt(TOSERVER_REQUEST_MEDIA, 2 + 0);

	pkt << (u16) (file_requests_size & 0xFFFF);

	for(std::vector<std::string>::const_iterator i = file_requests.begin();
			i != file_requests.end(); ++i) {
		pkt << (*i);
	}

	Send(&pkt);

	infostream << "Client: Sending media request list to server ("
			<< file_requests.size() << " files. packet size)" << std::endl;
}

void Client::received_media()
{
	NetworkPacket pkt(TOSERVER_RECEIVED_MEDIA, 0);
	Send(&pkt);
	infostream << "Client: Notifying server that we received all media"
			<< std::endl;
}

void Client::initLocalMapSaving(const Address &address,
		const std::string &hostname,
		bool is_local_server)
{
	if (!g_settings->getBool("enable_local_map_saving") || is_local_server) {
		return;
	}

	const std::string world_path = porting::path_user
		+ DIR_DELIM + "worlds"
		+ DIR_DELIM + "server_"
		+ hostname + "_" + to_string(address.getPort());

	fs::CreateAllDirs(world_path);

	m_localdb = new Database_SQLite3(world_path);
	m_localdb->beginSave();
	actionstream << "Local map saving started, map will be saved at '" << world_path << "'" << std::endl;
}

void Client::ReceiveAll()
{
	DSTACK(__FUNCTION_NAME);
	u32 start_ms = porting::getTimeMs();
	for(;;)
	{
		// Limit time even if there would be huge amounts of data to
		// process
		if(porting::getTimeMs() > start_ms + 100)
			break;

		try {
			Receive();
			g_profiler->graphAdd("client_received_packets", 1);
		}
		catch(con::NoIncomingDataException &e) {
			break;
		}
		catch(con::InvalidIncomingDataException &e) {
			infostream<<"Client::ReceiveAll(): "
					"InvalidIncomingDataException: what()="
					<<e.what()<<std::endl;
		}
	}
}

void Client::Receive()
{
	DSTACK(__FUNCTION_NAME);
	NetworkPacket pkt;
	m_con.Receive(&pkt);
	ProcessData(&pkt);
}

inline void Client::handleCommand(NetworkPacket* pkt)
{
	const ToClientCommandHandler& opHandle = toClientCommandTable[pkt->getCommand()];
	(this->*opHandle.handler)(pkt);
}

/*
	sender_peer_id given to this shall be quaranteed to be a valid peer
*/
void Client::ProcessData(NetworkPacket *pkt)
{
	DSTACK(__FUNCTION_NAME);

	ToClientCommand command = (ToClientCommand) pkt->getCommand();
	u32 sender_peer_id = pkt->getPeerId();

	//infostream<<"Client: received command="<<command<<std::endl;
	m_packetcounter.add((u16)command);

	/*
		If this check is removed, be sure to change the queue
		system to know the ids
	*/
	if(sender_peer_id != PEER_ID_SERVER) {
		infostream << "Client::ProcessData(): Discarding data not "
			"coming from server: peer_id=" << sender_peer_id
			<< std::endl;
		return;
	}

	// Command must be handled into ToClientCommandHandler
	if (command >= TOCLIENT_NUM_MSG_TYPES) {
		infostream << "Client: Ignoring unknown command "
			<< command << std::endl;
		return;
	}

	/*
	 * Those packets are handled before m_server_ser_ver is set, it's normal
	 * But we must use the new ToClientConnectionState in the future,
	 * as a byte mask
	 */
	if(toClientCommandTable[command].state == TOCLIENT_STATE_NOT_CONNECTED) {
		handleCommand(pkt);
		return;
	}

	if(m_server_ser_ver == SER_FMT_VER_INVALID) {
		infostream << "Client: Server serialization"
				" format invalid or not initialized."
				" Skipping incoming command=" << command << std::endl;
		return;
	}

	/*
	  Handle runtime commands
	*/

	handleCommand(pkt);
}

void Client::Send(NetworkPacket* pkt)
{
	m_con.Send(PEER_ID_SERVER,
		serverCommandFactoryTable[pkt->getCommand()].channel,
		pkt,
		serverCommandFactoryTable[pkt->getCommand()].reliable);
}

void Client::interact(u8 action, const PointedThing& pointed)
{
	if(m_state != LC_Ready) {
		errorstream << "Client::interact() "
				"Canceled (not connected)"
				<< std::endl;
		return;
	}

	/*
		[0] u16 command
		[2] u8 action
		[3] u16 item
		[5] u32 length of the next item
		[9] serialized PointedThing
		actions:
		0: start digging (from undersurface) or use
		1: stop digging (all parameters ignored)
		2: digging completed
		3: place block or item (to abovesurface)
		4: use item
	*/

	NetworkPacket pkt(TOSERVER_INTERACT, 1 + 2 + 0);

	pkt << action;
	pkt << (u16)getPlayerItem();

	std::ostringstream tmp_os(std::ios::binary);
	pointed.serialize(tmp_os);

	pkt.putLongString(tmp_os.str());

	Send(&pkt);
}

void Client::deleteAuthData()
{
	if (!m_auth_data)
		return;

	switch (m_chosen_auth_mech) {
		case AUTH_MECHANISM_FIRST_SRP:
			break;
		case AUTH_MECHANISM_SRP:
		case AUTH_MECHANISM_LEGACY_PASSWORD:
			srp_user_delete((SRPUser *) m_auth_data);
			m_auth_data = NULL;
			break;
		case AUTH_MECHANISM_NONE:
			break;
	}
	m_chosen_auth_mech = AUTH_MECHANISM_NONE;
}


AuthMechanism Client::choseAuthMech(const u32 mechs)
{
	if (mechs & AUTH_MECHANISM_SRP)
		return AUTH_MECHANISM_SRP;

	if (mechs & AUTH_MECHANISM_FIRST_SRP)
		return AUTH_MECHANISM_FIRST_SRP;

	if (mechs & AUTH_MECHANISM_LEGACY_PASSWORD)
		return AUTH_MECHANISM_LEGACY_PASSWORD;

	return AUTH_MECHANISM_NONE;
}

void Client::sendLegacyInit(const char* playerName, const char* playerPassword)
{
	NetworkPacket pkt(TOSERVER_INIT_LEGACY,
			1 + PLAYERNAME_SIZE + PASSWORD_SIZE + 2 + 2);

	pkt << (u8) SER_FMT_VER_HIGHEST_READ;
	pkt.putRawString(playerName,PLAYERNAME_SIZE);
	pkt.putRawString(playerPassword, PASSWORD_SIZE);
	pkt << (u16) CLIENT_PROTOCOL_VERSION_MIN << (u16) CLIENT_PROTOCOL_VERSION_MAX;

	Send(&pkt);
}

void Client::sendInit(const std::string &playerName)
{
	NetworkPacket pkt(TOSERVER_INIT, 1 + 2 + 2 + (1 + playerName.size()));

	// we don't support network compression yet
	u16 supp_comp_modes = NETPROTO_COMPRESSION_NONE;
	pkt << (u8) SER_FMT_VER_HIGHEST_READ << (u16) supp_comp_modes;
	pkt << (u16) CLIENT_PROTOCOL_VERSION_MIN << (u16) CLIENT_PROTOCOL_VERSION_MAX;
	pkt << playerName;

	Send(&pkt);
}

void Client::startAuth(AuthMechanism chosen_auth_mechanism)
{
	m_chosen_auth_mech = chosen_auth_mechanism;

	switch (chosen_auth_mechanism) {
		case AUTH_MECHANISM_FIRST_SRP: {
			// send srp verifier to server
			NetworkPacket resp_pkt(TOSERVER_FIRST_SRP, 0);
			char *salt, *bytes_v;
			std::size_t len_salt, len_v;
			salt = NULL;
			getSRPVerifier(getPlayerName(), m_password,
				&salt, &len_salt, &bytes_v, &len_v);
			resp_pkt
				<< std::string((char*)salt, len_salt)
				<< std::string((char*)bytes_v, len_v)
				<< (u8)((m_password == "") ? 1 : 0);
			free(salt);
			free(bytes_v);
			Send(&resp_pkt);
			break;
		}
		case AUTH_MECHANISM_SRP:
		case AUTH_MECHANISM_LEGACY_PASSWORD: {
			u8 based_on = 1;

			if (chosen_auth_mechanism == AUTH_MECHANISM_LEGACY_PASSWORD) {
				m_password = translatePassword(getPlayerName(), m_password);
				based_on = 0;
			}

			std::string playername_u = lowercase(getPlayerName());
			m_auth_data = srp_user_new(SRP_SHA256, SRP_NG_2048,
				getPlayerName().c_str(), playername_u.c_str(),
				(const unsigned char *) m_password.c_str(),
				m_password.length(), NULL, NULL);
			char *bytes_A = 0;
			size_t len_A = 0;
			srp_user_start_authentication((struct SRPUser *) m_auth_data,
				NULL, NULL, 0, (unsigned char **) &bytes_A, &len_A);

			NetworkPacket resp_pkt(TOSERVER_SRP_BYTES_A, 0);
			resp_pkt << std::string(bytes_A, len_A) << based_on;
			Send(&resp_pkt);
			break;
		}
		case AUTH_MECHANISM_NONE:
			break; // not handled in this method
	}
}

void Client::sendDeletedBlocks(std::vector<v3s16> &blocks)
{
	NetworkPacket pkt(TOSERVER_DELETEDBLOCKS, 1 + sizeof(v3s16) * blocks.size());

	pkt << (u8) blocks.size();

	u32 k = 0;
	for(std::vector<v3s16>::iterator
			j = blocks.begin();
			j != blocks.end(); ++j) {
		pkt << *j;
		k++;
	}

	Send(&pkt);
}

void Client::sendGotBlocks(v3s16 block)
{
	NetworkPacket pkt(TOSERVER_GOTBLOCKS, 1 + 6);
	pkt << (u8) 1 << block;
	Send(&pkt);
}

void Client::sendRemovedSounds(std::vector<s32> &soundList)
{
	size_t server_ids = soundList.size();
	assert(server_ids <= 0xFFFF);

	NetworkPacket pkt(TOSERVER_REMOVED_SOUNDS, 2 + server_ids * 4);

	pkt << (u16) (server_ids & 0xFFFF);

	for(std::vector<s32>::iterator i = soundList.begin();
			i != soundList.end(); i++)
		pkt << *i;

	Send(&pkt);
}

void Client::sendNodemetaFields(v3s16 p, const std::string &formname,
		const StringMap &fields)
{
	size_t fields_size = fields.size();

	FATAL_ERROR_IF(fields_size > 0xFFFF, "Unsupported number of nodemeta fields");

	NetworkPacket pkt(TOSERVER_NODEMETA_FIELDS, 0);

	pkt << p << formname << (u16) (fields_size & 0xFFFF);

	StringMap::const_iterator it;
	for (it = fields.begin(); it != fields.end(); ++it) {
		const std::string &name = it->first;
		const std::string &value = it->second;
		pkt << name;
		pkt.putLongString(value);
	}

	Send(&pkt);
}

void Client::sendInventoryFields(const std::string &formname,
		const StringMap &fields)
{
	size_t fields_size = fields.size();
	FATAL_ERROR_IF(fields_size > 0xFFFF, "Unsupported number of inventory fields");

	NetworkPacket pkt(TOSERVER_INVENTORY_FIELDS, 0);
	pkt << formname << (u16) (fields_size & 0xFFFF);

	StringMap::const_iterator it;
	for (it = fields.begin(); it != fields.end(); ++it) {
		const std::string &name  = it->first;
		const std::string &value = it->second;
		pkt << name;
		pkt.putLongString(value);
	}

	Send(&pkt);
}

void Client::sendInventoryAction(InventoryAction *a)
{
	std::ostringstream os(std::ios_base::binary);

	a->serialize(os);

	// Make data buffer
	std::string s = os.str();

	NetworkPacket pkt(TOSERVER_INVENTORY_ACTION, s.size());
	pkt.putRawString(s.c_str(),s.size());

	Send(&pkt);
}

void Client::sendChatMessage(const std::wstring &message)
{
	NetworkPacket pkt(TOSERVER_CHAT_MESSAGE, 2 + message.size() * sizeof(u16));

	pkt << message;

	Send(&pkt);
}

void Client::sendChangePassword(const std::string &oldpassword,
        const std::string &newpassword)
{
	Player *player = m_env.getLocalPlayer();
	if (player == NULL)
		return;

	std::string playername = player->getName();
	if (m_proto_ver >= 25) {
		// get into sudo mode and then send new password to server
		m_password = oldpassword;
		m_new_password = newpassword;
		startAuth(choseAuthMech(m_sudo_auth_methods));
	} else {
		std::string oldpwd = translatePassword(playername, oldpassword);
		std::string newpwd = translatePassword(playername, newpassword);

		NetworkPacket pkt(TOSERVER_PASSWORD_LEGACY, 2 * PASSWORD_SIZE);

		for (u8 i = 0; i < PASSWORD_SIZE; i++) {
			pkt << (u8) (i < oldpwd.length() ? oldpwd[i] : 0);
		}

		for (u8 i = 0; i < PASSWORD_SIZE; i++) {
			pkt << (u8) (i < newpwd.length() ? newpwd[i] : 0);
		}
		Send(&pkt);
	}
}


void Client::sendDamage(u8 damage)
{
	DSTACK(__FUNCTION_NAME);

	NetworkPacket pkt(TOSERVER_DAMAGE, sizeof(u8));
	pkt << damage;
	Send(&pkt);
}

void Client::sendBreath(u16 breath)
{
	DSTACK(__FUNCTION_NAME);

	NetworkPacket pkt(TOSERVER_BREATH, sizeof(u16));
	pkt << breath;
	Send(&pkt);
}

void Client::sendRespawn()
{
	DSTACK(__FUNCTION_NAME);

	NetworkPacket pkt(TOSERVER_RESPAWN, 0);
	Send(&pkt);
}

void Client::sendReady()
{
	DSTACK(__FUNCTION_NAME);

	NetworkPacket pkt(TOSERVER_CLIENT_READY,
			1 + 1 + 1 + 1 + 2 + sizeof(char) * strlen(g_version_hash));

	pkt << (u8) VERSION_MAJOR << (u8) VERSION_MINOR << (u8) VERSION_PATCH
		<< (u8) 0 << (u16) strlen(g_version_hash);

	pkt.putRawString(g_version_hash, (u16) strlen(g_version_hash));
	Send(&pkt);
}

void Client::sendPlayerPos()
{
	LocalPlayer *myplayer = m_env.getLocalPlayer();
	if(myplayer == NULL)
		return;

	// Save bandwidth by only updating position when something changed
	if(myplayer->last_position        == myplayer->getPosition() &&
			myplayer->last_speed      == myplayer->getSpeed()    &&
			myplayer->last_pitch      == myplayer->getPitch()    &&
			myplayer->last_yaw        == myplayer->getYaw()      &&
			myplayer->last_keyPressed == myplayer->keyPressed)
		return;

	myplayer->last_position   = myplayer->getPosition();
	myplayer->last_speed      = myplayer->getSpeed();
	myplayer->last_pitch      = myplayer->getPitch();
	myplayer->last_yaw        = myplayer->getYaw();
	myplayer->last_keyPressed = myplayer->keyPressed;

	u16 our_peer_id;
	{
		//JMutexAutoLock lock(m_con_mutex); //bulk comment-out
		our_peer_id = m_con.GetPeerID();
	}

	// Set peer id if not set already
	if(myplayer->peer_id == PEER_ID_INEXISTENT)
		myplayer->peer_id = our_peer_id;

	assert(myplayer->peer_id == our_peer_id);

	v3f pf         = myplayer->getPosition();
	v3f sf         = myplayer->getSpeed();
	s32 pitch      = myplayer->getPitch() * 100;
	s32 yaw        = myplayer->getYaw() * 100;
	u32 keyPressed = myplayer->keyPressed;

	v3s32 position(pf.X*100, pf.Y*100, pf.Z*100);
	v3s32 speed(sf.X*100, sf.Y*100, sf.Z*100);
	/*
		Format:
		[0] v3s32 position*100
		[12] v3s32 speed*100
		[12+12] s32 pitch*100
		[12+12+4] s32 yaw*100
		[12+12+4+4] u32 keyPressed
	*/

	NetworkPacket pkt(TOSERVER_PLAYERPOS, 12 + 12 + 4 + 4 + 4);

	pkt << position << speed << pitch << yaw << keyPressed;

	Send(&pkt);
}

void Client::sendPlayerItem(u16 item)
{
	Player *myplayer = m_env.getLocalPlayer();
	if(myplayer == NULL)
		return;

	u16 our_peer_id = m_con.GetPeerID();

	// Set peer id if not set already
	if(myplayer->peer_id == PEER_ID_INEXISTENT)
		myplayer->peer_id = our_peer_id;
	assert(myplayer->peer_id == our_peer_id);

	NetworkPacket pkt(TOSERVER_PLAYERITEM, 2);

	pkt << item;

	Send(&pkt);
}

void Client::removeNode(v3s16 p)
{
	std::map<v3s16, MapBlock*> modified_blocks;

	try {
		m_env.getMap().removeNodeAndUpdate(p, modified_blocks);
	}
	catch(InvalidPositionException &e) {
	}

	for(std::map<v3s16, MapBlock *>::iterator
			i = modified_blocks.begin();
			i != modified_blocks.end(); ++i) {
		addUpdateMeshTaskWithEdge(i->first, false, true);
	}
}

void Client::addNode(v3s16 p, MapNode n, bool remove_metadata)
{
	//TimeTaker timer1("Client::addNode()");

	std::map<v3s16, MapBlock*> modified_blocks;

	try {
		//TimeTaker timer3("Client::addNode(): addNodeAndUpdate");
		m_env.getMap().addNodeAndUpdate(p, n, modified_blocks, remove_metadata);
	}
	catch(InvalidPositionException &e) {
	}

	for(std::map<v3s16, MapBlock *>::iterator
			i = modified_blocks.begin();
			i != modified_blocks.end(); ++i) {
		addUpdateMeshTaskWithEdge(i->first, false, true);
	}
}

void Client::setPlayerControl(PlayerControl &control)
{
	LocalPlayer *player = m_env.getLocalPlayer();
	assert(player != NULL);
	player->control = control;
}

void Client::selectPlayerItem(u16 item)
{
	m_playeritem = item;
	m_inventory_updated = true;
	sendPlayerItem(item);
}

// Returns true if the inventory of the local player has been
// updated from the server. If it is true, it is set to false.
bool Client::getLocalInventoryUpdated()
{
	bool updated = m_inventory_updated;
	m_inventory_updated = false;
	return updated;
}

// Copies the inventory of the local player to parameter
void Client::getLocalInventory(Inventory &dst)
{
	Player *player = m_env.getLocalPlayer();
	assert(player != NULL);
	dst = player->inventory;
}

Inventory* Client::getInventory(const InventoryLocation &loc)
{
	switch(loc.type){
	case InventoryLocation::UNDEFINED:
	{}
	break;
	case InventoryLocation::CURRENT_PLAYER:
	{
		Player *player = m_env.getLocalPlayer();
		assert(player != NULL);
		return &player->inventory;
	}
	break;
	case InventoryLocation::PLAYER:
	{
		Player *player = m_env.getPlayer(loc.name.c_str());
		if(!player)
			return NULL;
		return &player->inventory;
	}
	break;
	case InventoryLocation::NODEMETA:
	{
		NodeMetadata *meta = m_env.getMap().getNodeMetadata(loc.p);
		if(!meta)
			return NULL;
		return meta->getInventory();
	}
	break;
	case InventoryLocation::DETACHED:
	{
		if(m_detached_inventories.count(loc.name) == 0)
			return NULL;
		return m_detached_inventories[loc.name];
	}
	break;
	default:
		FATAL_ERROR("Invalid inventory location type.");
		break;
	}
	return NULL;
}

void Client::inventoryAction(InventoryAction *a)
{
	/*
		Send it to the server
	*/
	sendInventoryAction(a);

	/*
		Predict some local inventory changes
	*/
	a->clientApply(this, this);

	// Remove it
	delete a;
}

ClientActiveObject * Client::getSelectedActiveObject(
		f32 max_d,
		v3f from_pos_f_on_map,
		core::line3d<f32> shootline_on_map
	)
{
	std::vector<DistanceSortedActiveObject> objects;

	m_env.getActiveObjects(from_pos_f_on_map, max_d, objects);

	// Sort them.
	// After this, the closest object is the first in the array.
	std::sort(objects.begin(), objects.end());

	for(unsigned int i=0; i<objects.size(); i++)
	{
		ClientActiveObject *obj = objects[i].obj;

		core::aabbox3d<f32> *selection_box = obj->getSelectionBox();
		if(selection_box == NULL)
			continue;

		v3f pos = obj->getPosition();

		core::aabbox3d<f32> offsetted_box(
				selection_box->MinEdge + pos,
				selection_box->MaxEdge + pos
		);

		if(offsetted_box.intersectsWithLine(shootline_on_map))
		{
			return obj;
		}
	}

	return NULL;
}

std::list<std::string> Client::getConnectedPlayerNames()
{
	return m_env.getPlayerNames();
}

float Client::getAnimationTime()
{
	return m_animation_time;
}

int Client::getCrackLevel()
{
	return m_crack_level;
}

void Client::setHighlighted(v3s16 pos, bool show_highlighted)
{
	m_show_highlighted = show_highlighted;
	v3s16 old_highlighted_pos = m_highlighted_pos;
	m_highlighted_pos = pos;
	addUpdateMeshTaskForNode(old_highlighted_pos, false, true);
	addUpdateMeshTaskForNode(m_highlighted_pos, false, true);
}

void Client::setCrack(int level, v3s16 pos)
{
	int old_crack_level = m_crack_level;
	v3s16 old_crack_pos = m_crack_pos;

	m_crack_level = level;
	m_crack_pos = pos;

	if(old_crack_level >= 0 && (level < 0 || pos != old_crack_pos))
	{
		// remove old crack
		addUpdateMeshTaskForNode(old_crack_pos, false, true);
	}
	if(level >= 0 && (old_crack_level < 0 || pos != old_crack_pos))
	{
		// add new crack
		addUpdateMeshTaskForNode(pos, false, true);
	}
}

u16 Client::getHP()
{
	Player *player = m_env.getLocalPlayer();
	assert(player != NULL);
	return player->hp;
}

u16 Client::getBreath()
{
	Player *player = m_env.getLocalPlayer();
	assert(player != NULL);
	return player->getBreath();
}

bool Client::getChatMessage(std::wstring &message)
{
	if(m_chat_queue.size() == 0)
		return false;
	message = m_chat_queue.front();
	m_chat_queue.pop();
	return true;
}

void Client::typeChatMessage(const std::wstring &message)
{
	// Discard empty line
	if(message == L"")
		return;

	// Send to others
	sendChatMessage(message);

	// Show locally
	if (message[0] == L'/')
	{
		m_chat_queue.push((std::wstring)L"issued command: " + message);
	}
	else
	{
		LocalPlayer *player = m_env.getLocalPlayer();
		assert(player != NULL);
		std::wstring name = narrow_to_wide(player->getName());
		m_chat_queue.push((std::wstring)L"<" + name + L"> " + message);
	}
}

void Client::addUpdateMeshTask(v3s16 p, bool ack_to_server, bool urgent)
{
	MapBlock *b = m_env.getMap().getBlockNoCreateNoEx(p);
	if(b == NULL)
		return;

	/*
		Create a task to update the mesh of the block
	*/

	MeshMakeData *data = new MeshMakeData(this, m_cache_enable_shaders);

	{
		//TimeTaker timer("data fill");
		// Release: ~0ms
		// Debug: 1-6ms, avg=2ms
		data->fill(b);
		data->setCrack(m_crack_level, m_crack_pos);
		data->setHighlighted(m_highlighted_pos, m_show_highlighted);
		data->setSmoothLighting(m_cache_smooth_lighting);
	}

	// Add task to queue
	m_mesh_update_thread.enqueueUpdate(p, data, ack_to_server, urgent);
}

void Client::addUpdateMeshTaskWithEdge(v3s16 blockpos, bool ack_to_server, bool urgent)
{
	try{
		addUpdateMeshTask(blockpos, ack_to_server, urgent);
	}
	catch(InvalidPositionException &e){}

	// Leading edge
	for (int i=0;i<6;i++)
	{
		try{
			v3s16 p = blockpos + g_6dirs[i];
			addUpdateMeshTask(p, false, urgent);
		}
		catch(InvalidPositionException &e){}
	}
}

void Client::addUpdateMeshTaskForNode(v3s16 nodepos, bool ack_to_server, bool urgent)
{
	{
		v3s16 p = nodepos;
		infostream<<"Client::addUpdateMeshTaskForNode(): "
				<<"("<<p.X<<","<<p.Y<<","<<p.Z<<")"
				<<std::endl;
	}

	v3s16 blockpos          = getNodeBlockPos(nodepos);
	v3s16 blockpos_relative = blockpos * MAP_BLOCKSIZE;

	try{
		addUpdateMeshTask(blockpos, ack_to_server, urgent);
	}
	catch(InvalidPositionException &e) {}

	// Leading edge
	if(nodepos.X == blockpos_relative.X){
		try{
			v3s16 p = blockpos + v3s16(-1,0,0);
			addUpdateMeshTask(p, false, urgent);
		}
		catch(InvalidPositionException &e){}
	}

	if(nodepos.Y == blockpos_relative.Y){
		try{
			v3s16 p = blockpos + v3s16(0,-1,0);
			addUpdateMeshTask(p, false, urgent);
		}
		catch(InvalidPositionException &e){}
	}

	if(nodepos.Z == blockpos_relative.Z){
		try{
			v3s16 p = blockpos + v3s16(0,0,-1);
			addUpdateMeshTask(p, false, urgent);
		}
		catch(InvalidPositionException &e){}
	}
}

ClientEvent Client::getClientEvent()
{
	ClientEvent event;
	if(m_client_event_queue.size() == 0) {
		event.type = CE_NONE;
	}
	else {
		event = m_client_event_queue.front();
		m_client_event_queue.pop();
	}
	return event;
}

float Client::mediaReceiveProgress()
{
	if (m_media_downloader)
		return m_media_downloader->getProgress();
	else
		return 1.0; // downloader only exists when not yet done
}

typedef struct TextureUpdateArgs {
	IrrlichtDevice *device;
	gui::IGUIEnvironment *guienv;
	u32 last_time_ms;
	u16 last_percent;
	const wchar_t* text_base;
} TextureUpdateArgs;

void texture_update_progress(void *args, u32 progress, u32 max_progress)
{
		TextureUpdateArgs* targs = (TextureUpdateArgs*) args;
		u16 cur_percent = ceil(progress / (double) max_progress * 100.);

		// update the loading menu -- if neccessary
		bool do_draw = false;
		u32 time_ms = targs->last_time_ms;
		if (cur_percent != targs->last_percent) {
			targs->last_percent = cur_percent;
			time_ms = getTimeMs();
			// only draw when the user will notice something:
			do_draw = (time_ms - targs->last_time_ms > 100);
		}

		if (do_draw) {
			targs->last_time_ms = time_ms;
			std::basic_stringstream<wchar_t> strm;
			strm << targs->text_base << " " << targs->last_percent << "%...";
			draw_load_screen(strm.str(), targs->device, targs->guienv, 0,
				72 + (u16) ((18. / 100.) * (double) targs->last_percent));
		}
}

void Client::afterContentReceived(IrrlichtDevice *device)
{
	infostream<<"Client::afterContentReceived() started"<<std::endl;
	assert(m_itemdef_received); // pre-condition
	assert(m_nodedef_received); // pre-condition
	assert(mediaReceived()); // pre-condition

	const wchar_t* text = wgettext("Loading textures...");

	// Clear cached pre-scaled 2D GUI images, as this cache
	// might have images with the same name but different
	// content from previous sessions.
	guiScalingCacheClear(device->getVideoDriver());

	// Rebuild inherited images and recreate textures
	infostream<<"- Rebuilding images and textures"<<std::endl;
	draw_load_screen(text,device, guienv, 0, 70);
	m_tsrc->rebuildImagesAndTextures();
	delete[] text;

	// Rebuild shaders
	infostream<<"- Rebuilding shaders"<<std::endl;
	text = wgettext("Rebuilding shaders...");
	draw_load_screen(text, device, guienv, 0, 71);
	m_shsrc->rebuildShaders();
	delete[] text;

	// Update node aliases
	infostream<<"- Updating node aliases"<<std::endl;
	text = wgettext("Initializing nodes...");
	draw_load_screen(text, device, guienv, 0, 72);
	m_nodedef->updateAliases(m_itemdef);
	std::string texture_path = g_settings->get("texture_path");
	if (texture_path != "" && fs::IsDir(texture_path))
		m_nodedef->applyTextureOverrides(texture_path + DIR_DELIM + "override.txt");
	m_nodedef->setNodeRegistrationStatus(true);
	m_nodedef->runNodeResolveCallbacks();
	delete[] text;

	// Update node textures and assign shaders to each tile
	infostream<<"- Updating node textures"<<std::endl;
	TextureUpdateArgs tu_args;
	tu_args.device = device;
	tu_args.guienv = guienv;
	tu_args.last_time_ms = getTimeMs();
	tu_args.last_percent = 0;
	tu_args.text_base =  wgettext("Initializing nodes");
	m_nodedef->updateTextures(this, texture_update_progress, &tu_args);
	delete[] tu_args.text_base;

	// Preload item textures and meshes if configured to
	if(g_settings->getBool("preload_item_visuals"))
	{
		verbosestream<<"Updating item textures and meshes"<<std::endl;
		text = wgettext("Item textures...");
		draw_load_screen(text, device, guienv, 0, 0);
		std::set<std::string> names = m_itemdef->getAll();
		size_t size = names.size();
		size_t count = 0;
		int percent = 0;
		for(std::set<std::string>::const_iterator
				i = names.begin(); i != names.end(); ++i)
		{
			// Asking for these caches the result
			m_itemdef->getInventoryTexture(*i, this);
			m_itemdef->getWieldMesh(*i, this);
			count++;
			percent = (count * 100 / size * 0.2) + 80;
			draw_load_screen(text, device, guienv, 0, percent);
		}
		delete[] text;
	}

	// Start mesh update thread after setting up content definitions
	infostream<<"- Starting mesh update thread"<<std::endl;
	m_mesh_update_thread.Start();

	m_state = LC_Ready;
	sendReady();
	text = wgettext("Done!");
	draw_load_screen(text, device, guienv, 0, 100);
	infostream<<"Client::afterContentReceived() done"<<std::endl;
	delete[] text;
}

float Client::getRTT(void)
{
	return m_con.getPeerStat(PEER_ID_SERVER,con::AVG_RTT);
}

float Client::getCurRate(void)
{
	return ( m_con.getLocalStat(con::CUR_INC_RATE) +
			m_con.getLocalStat(con::CUR_DL_RATE));
}

float Client::getAvgRate(void)
{
	return ( m_con.getLocalStat(con::AVG_INC_RATE) +
			m_con.getLocalStat(con::AVG_DL_RATE));
}

void Client::makeScreenshot(IrrlichtDevice *device)
{
	irr::video::IVideoDriver *driver = device->getVideoDriver();
	irr::video::IImage* const raw_image = driver->createScreenShot();

	if (!raw_image)
		return;

	time_t t = time(NULL);
	struct tm *tm = localtime(&t);

	char timetstamp_c[64];
	strftime(timetstamp_c, sizeof(timetstamp_c), "%Y%m%d_%H%M%S", tm);

	std::string filename_base = g_settings->get("screenshot_path")
			+ DIR_DELIM
			+ std::string("magichet_screenie_")
			+ std::string(timetstamp_c);
	std::string filename_ext = ".png";
	std::string filename;

	// Try to find a unique filename
	unsigned serial = 0;

	while (serial < SCREENSHOT_MAX_SERIAL_TRIES) {
		filename = filename_base + (serial > 0 ? ("_" + itos(serial)) : "") + filename_ext;
		std::ifstream tmp(filename.c_str());
		if (!tmp.good())
			break;	// File did not apparently exist, we'll go with it
		serial++;
	}

	if (serial == SCREENSHOT_MAX_SERIAL_TRIES) {
		infostream << "Could not find suitable filename for screenshot" << std::endl;
	} else {
		irr::video::IImage* const image =
				driver->createImage(video::ECF_R8G8B8, raw_image->getDimension());

		if (image) {
			raw_image->copyTo(image);

			std::ostringstream sstr;
			if (driver->writeImageToFile(image, filename.c_str())) {
				sstr << "Saved screenshot to '" << filename << "'";
			} else {
				sstr << "Failed to save screenshot '" << filename << "'";
			}
			m_chat_queue.push(narrow_to_wide(sstr.str()));
			infostream << sstr.str() << std::endl;
			image->drop();
		}
	}

	raw_image->drop();
}

// IGameDef interface
// Under envlock
IItemDefManager* Client::getItemDefManager()
{
	return m_itemdef;
}
INodeDefManager* Client::getNodeDefManager()
{
	return m_nodedef;
}
ICraftDefManager* Client::getCraftDefManager()
{
	return NULL;
	//return m_craftdef;
}
ITextureSource* Client::getTextureSource()
{
	return m_tsrc;
}
IShaderSource* Client::getShaderSource()
{
	return m_shsrc;
}
scene::ISceneManager* Client::getSceneManager()
{
	return m_device->getSceneManager();
}
u16 Client::allocateUnknownNodeId(const std::string &name)
{
	errorstream << "Client::allocateUnknownNodeId(): "
			<< "Client cannot allocate node IDs" << std::endl;
	FATAL_ERROR("Client allocated unknown node");

	return CONTENT_IGNORE;
}
ISoundManager* Client::getSoundManager()
{
	return m_sound;
}
MtEventManager* Client::getEventManager()
{
	return m_event;
}

ParticleManager* Client::getParticleManager()
{
	return &m_particle_manager;
}

scene::IAnimatedMesh* Client::getMesh(const std::string &filename)
{
	StringMap::const_iterator it = m_mesh_data.find(filename);
	if (it == m_mesh_data.end()) {
		errorstream << "Client::getMesh(): Mesh not found: \"" << filename
			<< "\"" << std::endl;
		return NULL;
	}
	const std::string &data    = it->second;
	scene::ISceneManager *smgr = m_device->getSceneManager();

	// Create the mesh, remove it from cache and return it
	// This allows unique vertex colors and other properties for each instance
	Buffer<char> data_rw(data.c_str(), data.size()); // Const-incorrect Irrlicht
	io::IFileSystem *irrfs = m_device->getFileSystem();
	io::IReadFile *rfile   = irrfs->createMemoryReadFile(
			*data_rw, data_rw.getSize(), filename.c_str());
	FATAL_ERROR_IF(!rfile, "Could not create/open RAM file");

	scene::IAnimatedMesh *mesh = smgr->getMesh(rfile);
	rfile->drop();
	// NOTE: By playing with Irrlicht refcounts, maybe we could cache a bunch
	// of uniquely named instances and re-use them
	mesh->grab();
	smgr->getMeshCache()->removeMesh(mesh);
	return mesh;
}
