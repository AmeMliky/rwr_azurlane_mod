// internal
#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
class TestingToolsTracker : Tracker {
	protected Metagame@ m_metagame;

	// --------------------------------------------
	TestingToolsTracker(Metagame@ metagame) {
		@m_metagame = metagame;
	}
	
	protected void handleChatEvent(const XmlElement@ event) {
		string message = event.getStringAttribute("message");
		// for the most part, chat events aren't commands, so check that first 
		if (!startsWith(message, "/")) {
			return;
		}

		string sender = event.getStringAttribute("player_name");
		int senderId = event.getIntAttribute("player_id");

		// admin only from here on
		if (!m_metagame.getAdminManager().isAdmin(sender, senderId)) {
			return;
		}
		
		if (checkCommand(message, "leavemealone")) { // kills characters from factions 1 and 2 near sender
			const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
			if (playerInfo !is null) {
				const XmlElement@ characterInfo = getCharacterInfo(m_metagame, playerInfo.getIntAttribute("character_id"));
				if (characterInfo !is null) {
					Vector3 position = stringToVector3(characterInfo.getStringAttribute("position"));
					//killCharactersNearPosition(m_metagame, position, 0, 150.0f);
					killCharactersNearPosition(m_metagame, position, 1, 150.0f);
					killCharactersNearPosition(m_metagame, position, 2, 150.0f);
				}
			}
		} else if (checkCommand(message, "capnear")) { 
			// /capnear 0 captures base nearest to sender and attributes it to faction 0
			// also kills the previous owners in the base
			if (message.substr(string("capnear ").length() + 1) == "") { // this happens if a number was not supplied
				return;
			}
			// extract factionId
			int factionId = parseInt(message.substr(string("capnear ").length() + 1));
			if (factionId < 0 || factionId > 2) {
				return;
			}
			// get player's character's position
			const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
			Vector3 playerPosition;
			if (playerInfo !is null) {
				const XmlElement@ characterInfo = getCharacterInfo(m_metagame, playerInfo.getIntAttribute("character_id"));
				if (characterInfo !is null) {
					playerPosition = stringToVector3(characterInfo.getStringAttribute("position"));
				} else {
					return;
				}
			} else {
				return;
			}
			
			// iterate over bases to find nearest one
			array<const XmlElement@> bases = getBases(m_metagame);
			// set current lowestDistance to something impossibly big
			float lowestDistance = 10000000.0;
			int nearestBaseIndex = 0;
			
			for (uint i = 0; i < bases.size(); ++i) {
				const XmlElement@ base = bases[i];
				const Vector3 basePosition = stringToVector3(base.getStringAttribute("position"));
				float distance = getPositionDistance(playerPosition, basePosition);
					if (distance < lowestDistance) {
						lowestDistance = distance;
						nearestBaseIndex = i;
					}
			}
			const XmlElement@ nearestBase = bases[nearestBaseIndex];
			
			if (nearestBase.getIntAttribute("owner_id") != factionId &&
				    nearestBase.getBoolAttribute("capturable")) {
					int previousOwnerId = nearestBase.getIntAttribute("owner_id");
					
					XmlElement command("command");
					command.setStringAttribute("class", "update_base");
					command.setIntAttribute("base_id", nearestBase.getIntAttribute("id"));
					command.setIntAttribute("owner_id", factionId);
					m_metagame.getComms().send(command);
					
					killCharactersNearPosition(m_metagame, stringToVector3(nearestBase.getStringAttribute("position")), previousOwnerId, 150.0f);
				}
		} else if (checkCommand(message, "teleport")) { // sets a new flare at supplied coordinates and kills sender. Bind with %input_position suggested
			// extract teleport target position
			string position = message.substr(string("teleport ").length() + 1);
			
			const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
			m_metagame.getComms().send("<command class='create_instance' faction_id='" + playerInfo.getIntAttribute("faction_id") + 
									   "' position='" + position + "' instance_class='vehicle' instance_key='para_spawn.vehicle' />");
			
			killCharacter(m_metagame, playerInfo.getIntAttribute("character_id"));
		} else if (checkCommand(message, "godmode")) { // spawns a godmode vest
			spawnInstanceNearPlayer(senderId, "god_vest.carry_item", "carry_item");
		} else if (checkCommand(message, "detonate")) { // makes an explosion at supplied coordinates. Bind with %input_position  suggested
			// extract detonate target position
			string position = message.substr(string("detonate ").length() + 1);
			const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
			m_metagame.getComms().send("<command class='create_instance' faction_id='" + playerInfo.getIntAttribute("faction_id") + 
									   "' position='" + position + "' instance_class='projectile' instance_key='detonation.projectile' />");
		}
	}
	
	// --------------------------------------------
	protected void spawnInstanceNearPlayer(int senderId, string key, string type, int factionId = 0) {
		const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
		if (playerInfo !is null) {
			const XmlElement@ characterInfo = getCharacterInfo(m_metagame, playerInfo.getIntAttribute("character_id"));
			if (characterInfo !is null) {
				Vector3 pos = stringToVector3(characterInfo.getStringAttribute("position"));
				pos.m_values[0] += 5.0;
				string c = "<command class='create_instance' instance_class='" + type + "' instance_key='" + key + "' position='" + pos.toString() + "' faction_id='" + factionId + "' />";
				m_metagame.getComms().send(c);
			}
		}
	}
	
	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return true;
	}
};
