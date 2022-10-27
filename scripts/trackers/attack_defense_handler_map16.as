#include "peaceful_last_base.as"

// --------------------------------------------
class AttackDefenseHandlerMap16 : PeacefulLastBase {
	// --------------------------------------------
	AttackDefenseHandlerMap16(GameModeInvasion@ metagame, int factionId) {
		super(metagame, factionId);
	}
	
    // ----------------------------------------------------
    protected void handleBaseOwnerChangeEvent(const XmlElement@ event) {
		// let PeacefulLastBase::refresh run;
		// will call setEnemiesDefend (applyDefensiveMode) or setEnemiesDefault (applyDefaultMode) 
		// or none if thinks nothing needs to change
		bool changed = refresh();
		if (!changed && 
			(event.getIntAttribute("owner_id") == 2 ||
			event.getIntAttribute("previous_owner_id") == 2)) {
			// not set by PeacefulLastBase::refresh, 
			// refresh mode in faction 2 anyway if base count changed
			applyDefaultMode(2);
		}
	}
	
	// --------------------------------------------
	void applyDefaultMode(int enemyId) {
		if (enemyId == 2) {
			// faction 2 will only actively attack if they have less than x bases
			if (getBasesForFaction(enemyId) < 5) {
				PeacefulLastBase::applyDefaultMode(enemyId);
			} else {
				string command =
					"<command class='commander_ai'" +
					"       faction='" + enemyId + "'" +
					"       base_defense='0.8'" +
					"       border_defense='0.19'>" +
							"</command>";
				m_metagame.getComms().send(command);
			}
		} else {
			PeacefulLastBase::applyDefaultMode(enemyId);
		}
	}
}
