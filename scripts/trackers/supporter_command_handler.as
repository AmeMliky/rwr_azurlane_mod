// internal
#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"

// --------------------------------------------
class SupporterCommandHandler : Tracker {
	protected Metagame@ m_metagame;

	// --------------------------------------------
	SupporterCommandHandler(Metagame@ metagame) {
		@m_metagame = @metagame;
	}
	
	// ----------------------------------------------------
	protected bool ownsDlc(const XmlElement@ playerInfo, string name) const {
		array<const XmlElement@> list = playerInfo.getElementsByTagName("access_tag");
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ accessTag = list[i];
			if (accessTag.getStringAttribute("name") == name) {
				return true;
			}
		}
		return false;
	}

	// ----------------------------------------------------
	protected void handleChatEvent(const XmlElement@ event) {
		// player_id
		// player_name
		// message
		// global

		string message = event.getStringAttribute("message");
		// for the most part, chat events aren't commands, so check that first 
		if (!startsWith(message, "/")) {
			return;
		}

		string sender = event.getStringAttribute("player_name");
		int senderId = event.getIntAttribute("player_id");

		int characterId = -1;
		const XmlElement@ playerInfo = getPlayerInfo(m_metagame, senderId);
		if (playerInfo !is null) {
			characterId = playerInfo.getIntAttribute("character_id");
			if (characterId >= 0) {
				if (ownsDlc(playerInfo, "supporter")) {
					if (checkCommand(message, "sit")) {
						animate(characterId, "sit down", true, true);
					}
					else if (checkCommand(message, "hi")) {
						animate(characterId, "hello", true, true);
					}
					else if (checkCommand(message, "salute")) {
						animate(characterId, "salute", true, true);
					}
					else if (checkCommand(message, "handstand")) {
						animate(characterId, "handstand", true, true);
					}
					else if (checkCommand(message, "push")) {
						animate(characterId, "push up", true, true);
					}
					else if (checkCommand(message, "yay1")) {
						animate(characterId, "celebrating", true, false);
					}	
					else if (checkCommand(message, "yay2")) {
						animate(characterId, "celebrating2", true, false);						
					}
					else if (checkCommand(message, "dance1")) {
						animate(characterId, "dancing, flossing", true, true);
					}
					else if (checkCommand(message, "dance2")) {
						animate(characterId, "dancing, phut hon", true, true);
					}
					else if (checkCommand(message, "dance3")) {
						animate(characterId, "dancing, helltaker", true, true);
					}
				}
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
		// always on
		return true;
	}
	
	// --------------------------------------------
	void animate(int characterId, string animationKey, bool interruptable = false, bool hideWeapon = false) {
		XmlElement command("command");
		command.setStringAttribute("class", "update_character");
		command.setIntAttribute("id", characterId);
		command.setStringAttribute("animate", animationKey);
		command.setBoolAttribute("interruptable", interruptable);
		command.setBoolAttribute("hide_weapon", hideWeapon);
		m_metagame.getComms().send(command);
	}
}
