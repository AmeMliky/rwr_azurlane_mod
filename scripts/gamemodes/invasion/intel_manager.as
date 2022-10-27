// internal
#include "tracker.as"
#include "log.as"
#include "query_helpers.as"

const float INVESTIGATION_COMPLETE_CHECK_INTERVAL_TIME = 5.0;

// --------------------------------------------
class IntelManager : Tracker {
	protected GameModeInvasion@ m_metagame;
	protected bool m_started;
	protected array<int> m_basesToInvestigate;
	protected float m_timer;
	
	protected float m_reward;
	protected string m_requiredCallForHint;
	protected float m_requiredXPForHint;

	// ----------------------------------------------------
	IntelManager(GameModeInvasion@ metagame, float reward = 100.0, string requiredCallForHint = "paratroopers1.call", float requiredXPForHint = 0.150) {
		@m_metagame = @metagame;
		m_started = false;
		m_reward = reward;
		m_timer = -1.0f;

		m_requiredCallForHint = requiredCallForHint;
		m_requiredXPForHint = requiredXPForHint;
	}

	// ----------------------------------------------------
	void start() {
		m_started = true;
		m_timer = INVESTIGATION_COMPLETE_CHECK_INTERVAL_TIME;

		// happens at match begin
		m_basesToInvestigate.clear();
		
		// go through all capturable enemy bases, setup markers for them, "to investigate"
		array<const XmlElement@>@ bases = getBases(m_metagame);
		for (uint i = 0; i < bases.size(); ++i) {
			const XmlElement@ base = bases[i];
			if (base.getIntAttribute("owner_id") != 0 && base.getBoolAttribute("capturable")) {
				setBaseToInvestigate(base);
			}
		}
	}
	
	// ----------------------------------------------------
	protected int getMarkerId(int baseId) const {
		return 5000 + baseId;
	}
	
	// ----------------------------------------------------
	protected void setBaseMarker(const XmlElement@ base, string style, string text = "") {
		int baseId = base.getIntAttribute("id");
		string position = base.getStringAttribute("position");
	
		int markerId = getMarkerId(baseId);
		
		int atlasIndex = 
			style == "investigate" ? 5 :
			style == "capture" ? 15 :
			0;
			
		XmlElement command("command");
		command.setStringAttribute("class", "set_marker");
		command.setIntAttribute("id", markerId);
		command.setIntAttribute("faction_id", 0);
		command.setIntAttribute("atlas_index", atlasIndex);
		command.setFloatAttribute("size", 2.0f);
		command.setBoolAttribute("enabled", style != "");
		command.setStringAttribute("position", position);
		command.setStringAttribute("text", text);
		command.setBoolAttribute("show_in_map_view", true);
		command.setBoolAttribute("show_in_game_view", false);
		command.setBoolAttribute("show_at_screen_edge", false);
		// text, color, size
		
		m_metagame.getComms().send(command);
	}

	// ----------------------------------------------------
	protected void clearBaseMarker(int baseId) {
		_log("clearBaseMarker, baseId=" + baseId, 1);
		int markerId = getMarkerId(baseId);
		
		XmlElement command("command");
		command.setStringAttribute("class", "set_marker");
		command.setIntAttribute("id", markerId);
		command.setIntAttribute("enabled", 0);
		command.setIntAttribute("faction_id", 0);
		
		m_metagame.getComms().send(command);
	}
	
	// ----------------------------------------------------
	protected bool isBaseToInvestigate(int baseId) const {
		return m_basesToInvestigate.find(baseId) >= 0;
	}
	
	// ----------------------------------------------------
	protected void setBaseToInvestigate(const XmlElement@ base) {
		int baseId = base.getIntAttribute("id");
		if (isBaseToInvestigate(baseId)) return;

		setBaseMarker(base, "investigate");

		m_basesToInvestigate.push_back(baseId);
	}

	// ----------------------------------------------------
	protected void clearBaseToInvestigate(int baseId) {
		_log("clearBaseToInvestigate, baseId=" + baseId, 1);
		if (!isBaseToInvestigate(baseId)) return;

		clearBaseMarker(baseId);

		m_basesToInvestigate.removeAt(m_basesToInvestigate.find(baseId));
	}
	
	// ----------------------------------------------------
	void gameContinuePreStart() {
		m_started = true;
	}
	
	// ----------------------------------------------------
	void end() {
	}	

	// ----------------------------------------------------
	bool hasStarted() const {
		return m_started;
	}

	// ----------------------------------------------------
	bool hasEnded() const {
		return false;
	}

	// ----------------------------------------------------
	protected void handleBaseOwnerChangeEvent(const XmlElement@ event) {
		array<const XmlElement@>@ bases = getBases(m_metagame);

		// when a base owner changes, refresh markers
		// - basically, if the base is now owned by enemy, add marker, if no longer owned by enemy, remove marker
		int baseId = event.getIntAttribute("base_id");
		int newOwner = event.getIntAttribute("owner_id");
		_log("handleBaseOwnerChangeEvent, base_id=" + baseId + ", owner_id=" + newOwner, 1);
		bool wasToInvestigate = isBaseToInvestigate(baseId);
		_log("* was to investigate=" + wasToInvestigate, 1);
		const XmlElement@ base = getBase(bases, baseId);

		if (!wasToInvestigate && newOwner > 0 /* owned by enemy */) {
			// this base was lost by friendly faction

			array<const XmlElement@>@ players = getPlayers(m_metagame);

			// if we have troops close still, don't fall back to investigation do direct capture state instead
			int characterId = -1;
			int playerId = -1;
			if (checkProximity(base, players, characterId, playerId)) {
				clearBaseToInvestigate(baseId);
				setBaseMarker(base, "capture");
			} else {
				setBaseToInvestigate(base);
			}
		} else if (!wasToInvestigate && newOwner == 0 /* owned by friendly */) {
			// not to investigate, now owned by friendly, clear marker
			clearBaseMarker(baseId);

		} else if (wasToInvestigate && newOwner == 0) {
			clearBaseToInvestigate(baseId);
		}
	}

	// ----------------------------------------------------
	protected void handleAttackChangeEvent(const XmlElement@ event) {
		_log("handleAttackChangeEvent", 1);
		if (event.getIntAttribute("faction_id") != 0) return;
		
		int baseId = event.getIntAttribute("base_id");
		if (baseId >= 0 && isBaseToInvestigate(baseId)) {
			clearBaseToInvestigate(baseId);
			
			const XmlElement@ base = getBase(m_metagame, baseId);
			setBaseMarker(base, "capture");
		}
	}
	
    // ----------------------------------------------------
	void update(float time) {
		// investigation completion by getting to center block
		// - periodically check all center blocks in bases still considered "to investigate" that if they have faction 0 members
		// - if so, mark completed
		m_timer -= time;
		if (m_timer < 0.0) {
			checkProximityCompletion();
			m_timer = INVESTIGATION_COMPLETE_CHECK_INTERVAL_TIME;
		}
	}
	
    // ----------------------------------------------------
	protected bool checkProximity(const XmlElement@ base, const array<const XmlElement@>@ players, int &out characterId, int &out playerId) const {
		characterId = -1;
		playerId = -1;
		//base.getStringAttribute("position");
		string block = base.getStringAttribute("center_block");
		array<const XmlElement@>@ list = getCharactersInBlocks(m_metagame, 0, array<string> = { block });
		if (list.size() > 0) {
			// proceed
			_log("* about to complete investigation at " + base.getStringAttribute("name"), 1);
			
			// prefer one of the players as the character who completed it, if any
			for (uint k = 0; k < players.size() && characterId < 0; ++k) {
				const XmlElement@ player = players[k];
				int playerCid = player.getIntAttribute("character_id");
				for (uint j = 0; j < list.size() && characterId < 0; ++j) {
					const XmlElement@ character = list[j];
					int cid = character.getIntAttribute("id");
					if (playerCid == cid) {
						//_log("* player character id matches cid", 1);
						characterId = cid;
						playerId = player.getIntAttribute("player_id");
					}
				}
			}
			if (characterId < 0) {
				// pick first as last resort
				characterId = list[0].getIntAttribute("id");
				// playerId will be -1, which is fine
			}
		} else {
			_log("* no friendlies in base " + base.getStringAttribute("name"), 1);
			Vector3 centerBlockPosition = stringToVector3(base.getStringAttribute("position"));
			// no one in center block
			// check if any player has crosshair close enough to center of center block, if so accept as investigated
			// prefer one of the players as the character who completed it, if any
			for (uint k = 0; k < players.size(); ++k) {
				const XmlElement@ player = players[k];
				if (player.hasAttribute("aim_target")) {
					Vector3 target = stringToVector3(player.getStringAttribute("aim_target"));
					_log("checking range, " + target.toString() + " -> " + centerBlockPosition.toString(), 1);
					if (checkRange(target, centerBlockPosition, 25.0f)) {
						_log("close enough", 1);
						characterId = player.getIntAttribute("character_id");
						playerId = player.getIntAttribute("player_id");
						break;
					}
				}
			}
		}
		return characterId >= 0;
	}
	
	// ----------------------------------------------------
	protected void checkProximityCompletion() {
		array<const XmlElement@>@ players = getPlayers(m_metagame);
		array<const XmlElement@>@ bases = getBases(m_metagame);
		for (uint i = 0; i < bases.size(); ++i) {
			const XmlElement@ base = bases[i];
			if (isBaseToInvestigate(base.getIntAttribute("id"))) {
			
				int characterId = -1;
				int playerId = -1;
				if (checkProximity(base, players, characterId, playerId)) {
					setInvestigationComplete(base, characterId, playerId);
				}
			}
		}
	}

	// ----------------------------------------------------
	protected void setInvestigationComplete(const XmlElement@ base, int characterId, int playerId) {
		string baseName = base.getStringAttribute("name");
		_log("IntelManager::setInvestigationComplete, base=" + baseName + ", characterId=" + characterId + ", playerId=" + playerId, 1);
		int baseId = base.getIntAttribute("id");

		clearBaseToInvestigate(baseId);

		// change to "to capture" marker
		setBaseMarker(base, "capture");

		// reward
		string c = "<command class='rp_reward' character_id='" + characterId + "' reward='" + m_reward + "' />";
		m_metagame.getComms().send(c);
		
		// make a chat towards commander with intel by the character
		// - needs some variations like weak/heavy defense or an estimated figure, maybe priorization suggestions to commander
		
		// - player himself does this; needs to show the player character say it
		// - player sees a bot/other player do this: needs to show the character say it
		// - player doesn't see a bot/other player do this; ok to show as commander said it, commander echoes what he heard from the observer, just like spotting works
		
		// get number of enemies in the base 3x3 area
		// show the exact number, or add a random error to it, or split it between weak/heavy
		// vehicle intel?
		
		int enemy = base.getIntAttribute("owner_id");
		Vector3 position = stringToVector3(base.getStringAttribute("position"));
		array<const XmlElement@> enemies = getCharactersNearPosition(m_metagame, position, enemy, 60.0f);
		int enemyCount = enemies.size();

		// check two enemy factions only
		int otherEnemy = enemy == 1 ? 2 : enemy == 2 ? 1 : -1;
		if (otherEnemy >= 0 && otherEnemy < int(m_metagame.getFactions().size())) {
			const Faction@ faction = m_metagame.getFactions()[otherEnemy];
			if (faction.isNeutral()) {
				otherEnemy = -1;
			}
		}
		int otherEnemyCount = 0;
		if (otherEnemy >= 0) {
			array<const XmlElement@> otherEnemies = getCharactersNearPosition(m_metagame, position, otherEnemy, 60.0f);
			otherEnemyCount = otherEnemies.size();
		}

		_log("enemy count=" + enemyCount + ", other enemy count=" + otherEnemyCount, 1);

		// TODO:
		// - what to say when there are both enemies present?

		if (otherEnemyCount >= 2 || otherEnemyCount > enemyCount) {
			// at least a few other enemies present too

			// two enemy factions present, possibly fighting, possibly not
			// just skip messaging for now
		} else {
			// only one enemy faction present

			string range = "";
			int veryWeak = 1;
			int weak = 4;
			int medium = 9;
			string intelKey = "intel test1";
			string commanderKey = "intel test2";
			if (enemyCount <= veryWeak) {
				intelKey = "report very weak defense";
				commanderKey = "respond very weak defense";
				range = "0";
			} else if (enemyCount <= weak) {
				intelKey = "report weak defense";
				commanderKey = "respond weak defense";
				range = "2-4";
			} else if (enemyCount <= medium) {
				intelKey = "report medium defense";
				commanderKey = "respond medium defense";
				range = "5-10";
			} else {
				intelKey = "report heavy defense";
				commanderKey = "respond heavy defense";
				// if under 20, use step 5
				// if over 20, use step 10
				// if over 40, use step 20
				int step = 5;
				if (enemyCount < 20) {
					step = 5;
				} else if (enemyCount < 40) {
					step = 10;
				} else {
					step = 20;
				}
				int enemyCountLow = int(enemyCount / step) * step;
				int enemyCountHigh = enemyCountLow + step;
				range = formatInt(enemyCountLow) + "-" + formatInt(enemyCountHigh);
			}
			
			dictionary a = {
				{"%base_name", baseName},
				{"%enemy_count", formatInt(enemyCount)},
				{"%enemy_range", range}
			};
		
			// if it's a bot who made the intel job, this message appears coming from commander, as if echoed to others
			// .. we could work it out so that a bot says it, it needs some work with chat log and stuff
			// hmmm
			// - let's make it so that character will just say it, no radio, not to log
			// - commander echoes it to everyone
			// - then commander talks privately with the player, if it was player

			// - appear as character said it, field only
			sendFactionMessageKeySaidAsCharacter(m_metagame, 0, characterId, intelKey, a);
			// - echo same message from commander, also makes radio sound which is good
			sendFactionMessageKey(m_metagame, 0, intelKey, a);

			// for now, if it's not a player who makes the report, don't show the rest of the discussion
			if (playerId >= 0) {
				// it might also be that this should be a private discussion between commander and the player, but for now, show it to others too
				
				// do a delay
				m_metagame.getTaskSequencer().add(AnnouncePrivateTask(m_metagame, 2.0, playerId, ""));
				
				// make a chat from commander where capture can be proceeded with if considered possible, or maybe even not recommend it if too heavy
				// - variations, maybe priorization talk
				m_metagame.getTaskSequencer().add(AnnouncePrivateTask(m_metagame, 4.0, playerId, commanderKey));

				if (enemyCount > weak) {
					// could also suggest (or remind) about fire support and reinforcement drops, or stealth and C4 for example
					// - could happen aware of if character has RP for these things
					
					// require enough xp for mortar strikes.. or for reinforcements?
					// require that reinforcements are available in soldier group
					if (hasCallAvailable(m_requiredCallForHint) &&
						hasEnoughXP(characterId, m_requiredXPForHint)) {
						m_metagame.getTaskSequencer().add(AnnouncePrivateTask(m_metagame, 4.0, playerId, "intel radio reminder"));
					}			
				}
			}

			// radio tower base/truck investigation is problematic:
			// - comms is in fact regionally jammed
			// - it's true the spotting works anyway, and that basically is also radio stuff, which is wrong
			//.. don't care? or fake it with bad lines or something, distorted font and scrambled messages
		}
	}
	
	// ----------------------------------------------------
	protected bool hasCallAvailable(string key) {
		bool result = false;
		array<const XmlElement@> calls = getFactionResources(m_metagame, 0, "call", "calls");
		for (uint i = 0; i < calls.size(); ++i) {
			const XmlElement@ call = calls[i];
			if (call.getStringAttribute("key") == key) {
				result = true;
				break;
			}
		}
		return result;
	}
	
	// ----------------------------------------------------
	protected bool hasEnoughXP(int characterId, float xp) {
		bool result = false;
		const XmlElement@ characterInfo = getCharacterInfo(m_metagame, characterId);
		if (characterInfo !is null &&
		    characterInfo.getFloatAttribute("xp") >= xp) {
			result = true;
		}
		return result;
	}

	// ----------------------------------------------------
	void onRemove() {
		m_started = false;
	}

	// ----------------------------------------------------
	void load(const XmlElement@ root) {
		m_basesToInvestigate.clear();
		const XmlElement@ subroot = root.getFirstElementByTagName("intel_manager");
		if (subroot !is null) {
			array<const XmlElement@>@ bases = getBases(m_metagame);
			array<const XmlElement@> list = subroot.getElementsByTagName("base_to_investigate");
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ e = list[i];
				int id = e.getIntAttribute("id");
				for (uint j = 0; j < bases.size(); ++j) {
					const XmlElement@ base = bases[j];
					if (base.getIntAttribute("id") == id) {
						setBaseToInvestigate(base);
					}
				}
			}
		}
	}

	// ----------------------------------------------------
	void save(XmlElement@ root) {
		XmlElement subroot("intel_manager");

		// save bases which have intel done already, or which are still to be scouted
		for (uint i = 0; i < m_basesToInvestigate.size(); ++i) {
			XmlElement e("base_to_investigate");
			e.setIntAttribute("id", m_basesToInvestigate[i]);
			subroot.appendChild(e);
		}

		root.appendChild(subroot);
	}
}
