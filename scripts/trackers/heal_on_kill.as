#include "tracker.as"
#include "gamemode.as"
#include "query_helpers.as"

// --------------------------------------------
class HealOnKill : Tracker {
	protected Metagame@ m_metagame;
	protected int m_factionId;

	// --------------------------------------------
	HealOnKill(Metagame@ metagame, int factionId) {
		@m_metagame = @metagame;
		m_factionId = factionId;

		m_metagame.getComms().send("<command class='set_metagame_event' name='character_kill' enabled='1' />");
	}
	
	// --------------------------------------------
	protected void handleCharacterKillEvent(const XmlElement@ event) {
		const XmlElement@ killer = event.getFirstElementByTagName("killer");
		const XmlElement@ target = event.getFirstElementByTagName("target");
		if (killer !is null && target !is null &&
			// only do heal for the defined faction
			killer.getIntAttribute("faction_id") == m_factionId &&
			// don't heal on teamkill
			target.getIntAttribute("faction_id") != m_factionId) {

			int id = killer.getIntAttribute("id");
			if (id >= 0) {
				XmlElement c("command");
				c.setStringAttribute("class", "update_inventory");
				c.setIntAttribute("character_id", id); 
				c.setIntAttribute("untransform_count", 2);
				m_metagame.getComms().send(c);
			}

		}
	}
}
