#include "map_rotator_invasion.as"

// ----------------------------------------------------------------------------
string getTransportName(string mapFrom, string mapTo) {
	string transportName = mapFrom + "_to_" + mapTo;
	return transportName;
}

// --------------------------------------------
// --------------------------------------------
// --------------------------------------------
// --------------------------------------------
// --------------------------------------------

class MapRotatorCampaign : MapRotatorInvasion {
	protected int m_playerCharacterId;
	protected array<string> m_trackedHitboxes;
	protected array<const XmlElement@> m_extractionHitboxes;
	protected dictionary m_worldTransportMap;
	protected float m_localPlayerCheckTimer;
	protected array<int> m_finalBattleEnemyFactions;
	protected array<string> m_startingMapIds;
	
	protected float LOCAL_PLAYER_CHECK_TIME = 5.0;

	// --------------------------------------------
	MapRotatorCampaign(GameModeInvasion@ metagame) {
		super(metagame);

		m_playerCharacterId = -1;
		m_localPlayerCheckTimer = 0.0f;
	}

	// --------------------------------------------
	void init() {
		MapRotatorInvasion::init();

		setLoop(false);
	}

	// -------------------------------------------------------
	void addTransport(string sourceMapId, string hitboxId, string targetMapId) {
		int sourceStageIndex = getStageIndex(sourceMapId);
		int targetStageIndex = getStageIndex(targetMapId);

		string sourceKey = formatInt(sourceStageIndex);
		if (!m_worldTransportMap.exists(sourceKey)) {
			// add new container
			dictionary d;
			m_worldTransportMap.set(sourceKey, @d);
		}

		dictionary@ hitboxIdToTarget;
		m_worldTransportMap.get(sourceKey, @hitboxIdToTarget);
		hitboxIdToTarget.set(hitboxId, targetStageIndex);
	}

	// --------------------------------------------
	void addStartingMap(string mapId) {
		m_startingMapIds.insertLast(mapId);
	}

	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	void startRotation(bool beginOnly = false) {

		if (!beginOnly) {
			// being_only is false only when the adventure starts from the very beginning, the first time			
			m_nextStageIndex = pickStartingMap();

		} else {
			// begin_only is true when map change and match start are not done; i.e. continue
			// - in such case, use next stage index, it is same as current stage index
		}

		int index = getNextStageIndex();

		// normal
		startMap(index, beginOnly);
	}

	// --------------------------------------------
	protected int getStageIndex(string mapId) const {
		// helper to resolve stage index for given map index;
		// - warning, will return the first match, may not work as expected if same map is used as multiple stages
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (stage.m_mapInfo.m_id == mapId) {
				return i;
			}
		}
		_log("WARNING, getStageIndex, no stage found for map " + mapId, -1);
		return -1;
	
	}

	// --------------------------------------------
	protected int pickStartingMap() const {
		// pick first map, and change to it
		array<string> maps = m_startingMapIds;

		_log("starting maps count " + maps.size(), 1);
		int i = rand(0, maps.size() - 1);

		int index = getStageIndex(maps[i]);
		_log("index = " + index, 1);

		return index;
	}

	// --------------------------------------------
	protected void readyToAdvance() {
		// in adventure mode, allow player to choose next map using hitboxes and choose when to get extraction there

		// - receive hitbox event
		// - determine next map from hitbox data, store as a variable
		// - call wait_and_start
		// - in wait_and_start get_next_map_index will return the correct map index

		// redetermine now that the map was completed, opens up the closed exit points
		determineExtractionHitboxList();

		// hitboxes may have changed
		refreshHitboxes();

		// also at this point, when the map is getting completed, change the stage settings already
		// so that next time if we come back here, it's changed
		// - don't do it here, it's too early
		// - if game is saved and quit, and then loaded, the stage settings have faction size 1 which isn't correct
		//setupStageComplete(m_currentStageIndex);

		if (checkForFinalBattleUnlock()) {
			// we just unlocked a final battle, re-determine extraction points, might be in this map
			determineExtractionHitboxList();
			refreshHitboxes();
		}

		refreshCompletionStatus(true);

		// achievement trigger for completing the map
		if (m_playerCharacterId >= 0) {
			addCustomStatToAllPlayers(m_metagame, "stage_completed");
		}

	}

	// --------------------------------------------
	protected bool checkForCampaignCompletion() const {
		bool allStagesComplete = true;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (!isStageCompleted(i)) {
				allStagesComplete = false;
				break;
			}
		}
		return allStagesComplete;
	}

	// --------------------------------------------
	protected bool checkForFinalBattleUnlock() {
		_log("checkForFinalBattleUnlock");
		// check factions for final battle unlocking
		// - it would be enough to just check the current factions loaded in-game,
		//   but we need to support 0.97 savegames where you may have completed all
		//   maps so each map would only feature friendly anymore
		// - check all of them then, always

		bool changed = false;
		_log("size=" + m_factionConfigs.size());
		for (uint i = 0; i < m_factionConfigs.size(); ++i) {
			FactionConfig@ factionConfig = m_factionConfigs[i];
			if (i == 0) continue; // skip friendly
			if (factionConfig.m_file == "neutral.xml") continue; // skip neutral

			int factionConfigIndex = factionConfig.m_index;
			
			bool allocated = hasBeenAllocatedForFinalBattle(factionConfigIndex);
			_log("hasBeenAllocatedForFinalBattle " + factionConfigIndex + "=" + allocated);
			bool defeated = isFactionCompletelyDefeated(factionConfigIndex);
			_log("isFactionCompletelyDefeated " + factionConfigIndex + "=" + defeated);
			if (!allocated && defeated) {
				// faction has been defeated, unlock final battle
				unlockFinalBattle(factionConfigIndex);

				changed = true;
			}
		}

		return changed;
	}

	// --------------------------------------------
	protected bool hasBeenAllocatedForFinalBattle(int factionConfigIndex) const {
		return m_finalBattleEnemyFactions.find(factionConfigIndex) >= 0;
	}

	// --------------------------------------------
	protected bool isFactionCompletelyDefeated(int factionConfigIndex) const {
		// if regular stages don't include the given faction, it has lost completely
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (!stage.isFinalBattle()) {
				if (isStageCompleted(i)) {
					// enemies are known to be defeated if stage is marked complete
				} else {
					// otherwise go through the list of factions in the stage
					for (uint j = 0; j < stage.m_factions.size(); ++j) {
						Faction@ faction = stage.m_factions[j];
						if (faction.m_config.m_index == factionConfigIndex) {
							return false;
						}
					}
				}
			}
		}
		return true;
	}

	// --------------------------------------------
	protected int getFinalBattleIndex(int stageIndex) const {
		int counter = 0;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (stage.isFinalBattle()) {
				if (stageIndex == int(i)) {
					return counter;
				}
				counter += 1;
			}
		}
		_log("WARNING, can't find final battle stage index for stage " + stageIndex, -1);
		return -1;
	}

	// --------------------------------------------
	// returns a reference
	protected Stage@ getNthFinalBattleStage(int n) const {
		// if regular stages don't include the given faction, it has lost completely
		int counter = 0;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (stage.isFinalBattle()) {
				if (counter == n) {
					return stage;
				}
				counter += 1;
			}
		}
		_log("WARNING, can't find nth final battle stage, n=" + n, -1);
		return null;
	}

	// --------------------------------------------
	protected void unlockFinalBattle(int factionConfigIndex) {
		_log("unlockFinalBattle " + factionConfigIndex);
		if (!hasBeenAllocatedForFinalBattle(factionConfigIndex)) {
			_log("  unlocking final battle #" + m_finalBattleEnemyFactions.size() + " for " + factionConfigIndex);

			int finalBattleIndex = m_finalBattleEnemyFactions.size();

			// allocate final battle stage now
			m_finalBattleEnemyFactions.insertLast(factionConfigIndex);

			// generate stage data:
			// - find corresponding final battle stage, returns a reference
			Stage@ stage = getNthFinalBattleStage(finalBattleIndex);

			if (stage !is null) {
				// - set correct faction as opponent in stage
				// - assuming single enemy in final battle here!
				@stage.m_factions[1].m_config = m_factionConfigs[factionConfigIndex];
				stage.m_hidden = false;
				m_world.refresh(m_stages, m_stagesCompleted, m_currentStageIndex);
			} 
		} else {
			_log("  already allocated");
		}
	}

	// --------------------------------------------------------
	protected bool isFinalBattleUnlocked(int finalBattleIndex) const {
		return finalBattleIndex < int(m_finalBattleEnemyFactions.size());
	}

	// --------------------------------------------------------
	protected void refreshHitboxes() {
		_log("refreshHitboxes", 1);
		clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);

		const array<const XmlElement@> list = getExtractionHitboxList();
		if (list is null) return;

		array<string> addIds;
		associateHitboxesEx(m_metagame, list, "character", m_playerCharacterId, m_trackedHitboxes, addIds);

		// check add_ids, report them, but report only one instances
		array<int> reported;
		array<string> newMapNames;
		for (uint i = 0; i < addIds.size(); ++i) {
			string id = addIds[i];
			int index = getStageIndexFromExtractionHitboxId(id);
			if (reported.find(index) < 0) {
				if (index >= 0 && index < int(m_stages.size())) {
					string text = m_stages[index].m_mapInfo.m_name;
					reported.insertLast(index);
					if (text != "") {
						newMapNames.insertLast(text);
					}
				}
			}
		}

		if (newMapNames.size() > 1) {
			// many, use generic notification
			notify(m_metagame, "several extraction points available");
		} else if (newMapNames.size() == 1) {
			dictionary a = {
				{"%map_name", newMapNames[0]}
			};
			notify(m_metagame, "extraction point available", a);
		}
	}

	// --------------------------------------------
	void refreshCompletionStatus(bool first) {
		// if all maps have been completed, declare campaign complete and inform game in order to show the campaign end view
		if (checkForCampaignCompletion()) {
			bool showStats = first;
			m_metagame.getComms().send("<command class='set_campaign_status' show_stats='" + (showStats ? 1 : 0) + "'/>");

			if (first) {
				if (m_playerCharacterId >= 0) {
					string tag = "campaign_completed_faction_" + formatInt(m_metagame.getUserSettings().m_factionChoice);
					addCustomStatToAllPlayers(m_metagame, tag);
				}
			}
		}
	}

	// --------------------------------------------
	protected string toWorldTransportMapKey(int index) const {
		return formatInt(index);
	}

	// --------------------------------------------
	protected int getStageIndexFromExtractionHitboxId(string id) const {
		// bind maps together here rather than directly in maps themselves
		int targetStage = -1;

		string currentStageIndexKey = toWorldTransportMapKey(m_currentStageIndex);
		if (m_worldTransportMap.exists(currentStageIndexKey)) {
			dictionary@ transportMap;
			m_worldTransportMap.get(currentStageIndexKey, @transportMap);
			if (transportMap.exists(id)) {
				transportMap.get(id, targetStage);
			} else {
				_log("ERROR, transport map for stage " + m_currentStageIndex + " doesn't have extraction id " + id, -1);
			}
		} else {
			_log("ERROR, stage " + m_currentStageIndex + " doesn't have transport map", -1);
		}

		return targetStage;
	}

	// --------------------------------------------------------
	protected void markExtractionPoints() {
		const array<const XmlElement@> list = getExtractionHitboxList();
		if (list is null) return;

		// only show extraction markers at screen edge if current map is complete
		bool showAtScreenEdge = isStageCompleted(m_currentStageIndex);

		int offset = 2000;
		for (uint i = 0; i < list.size(); ++i) {
			const XmlElement@ hitboxNode = list[i];
			string id = hitboxNode.getStringAttribute("id");
			int index = getStageIndexFromExtractionHitboxId(id);
			string text = "?";
			int atlasIndex = 1;
			float size = 1.0;
			string color = "#FFFFFF";
			if (index >= 0 && index < int(m_stages.size())) {
				Stage@ stage = m_stages[index];
				text = stage.m_mapInfo.m_name;
				if (stage.isFinalBattle()) {
					// use different extraction marker for final battles
					atlasIndex = 2;
					size = 2.0;
				}

				if (isStageCompleted(index)) {
					color = "#E0E0E0";
					size = 1.0;
				}
			}
			string position = hitboxNode.getStringAttribute("position");

			XmlElement command("command");
			command.setStringAttribute("class", "set_marker");
			command.setIntAttribute("id", offset);
			command.setIntAttribute("faction_id", 0);
			command.setIntAttribute("atlas_index", atlasIndex);
			command.setStringAttribute("text", text);
			command.setStringAttribute("position", position);
			command.setStringAttribute("color", color);
			command.setFloatAttribute("size", size);
			command.setIntAttribute("show_at_screen_edge", showAtScreenEdge?1:0);
			m_metagame.getComms().send(command);

			offset++;
		}
	}

	// --------------------------------------------------------
	protected void unmarkExtractionPoints() {
		const array<const XmlElement@> list = getExtractionHitboxList();
		if (list !is null) return;

		int offset = 2000;
		for (uint i = 0; i < list.size(); ++i) {
			string command = "<command class='set_marker' id='" + offset + "' enabled='0' />";
			m_metagame.getComms().send(command);
			offset++;
		}
	}

	// ----------------------------------------------------
	protected void setupCharacterForTracking(int id) {
		// it's the local player, do stuff now
		clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);
		m_playerCharacterId = id;

		_log("setting up tracking for character " + id, 1);

		const array<const XmlElement@> list = getExtractionHitboxList();
		if (list !is null) {
			associateHitboxes(m_metagame, list, "character", m_playerCharacterId, m_trackedHitboxes);
		}
	}

	// ----------------------------------------------------
	protected void handlePlayerSpawnEvent(const XmlElement@ event) {
		_log("MapRotatorCampaign::handlePlayerSpawnEvent", 1);
		// don't care if already about to change map
		if (isAboutToChangeMap()) {
			_log("skipping", 1);
			return;
		}

		const XmlElement@ element = event.getFirstElementByTagName("player");
		string name = element.getStringAttribute("name");
		_log("player spawned: " + name + ", target username is " + m_metagame.getUserSettings().m_username, 1);
		if (name == m_metagame.getUserSettings().m_username) {
			_log("is local", 1);
			setupCharacterForTracking(element.getIntAttribute("character_id"));
		}
	}

	// ----------------------------------------------------
	void update(float time) {
		// TODO: likely we could do this at gameContinuePreStart, but won't change now to avoid re-testing
		ensureValidLocalPlayer(time);
	}

	// ----------------------------------------------------
	protected void ensureValidLocalPlayer(float time) {
		// workaround:
		// - apparently it happens that player spawn events aren't always carried through
		// - could be related to loading a campaign; maybe player spawns before the script starts?
		// - to workaround those cases, ensure that we are tracking a character here, and if we are not, query if the local player exists
		if (m_playerCharacterId < 0) {
			m_localPlayerCheckTimer -= time;
			if (m_localPlayerCheckTimer < 0.0) {
				_log("tracked player character id " + m_playerCharacterId, 1);
				const XmlElement@ player = m_metagame.queryLocalPlayer();
				if (player !is null) {
					setupCharacterForTracking(player.getIntAttribute("character_id"));
				} else {
					_log("WARNING, local player query failed", -1);
				}
				m_localPlayerCheckTimer = LOCAL_PLAYER_CHECK_TIME;
			}
		}
	}

	// ----------------------------------------------------
	protected bool isAboutToChangeMap() const {
		return m_nextStageIndex != m_currentStageIndex;

	}
	// ----------------------------------------------------
	protected void handleHitboxEvent(const XmlElement@ event) {
		// don't care if already about to change map
		if (isAboutToChangeMap()) return;

		// hitbox_id
		// instance_type (vehicle/character)
		// instance_id

		_log("handle_hitbox_event, type=" + event.getStringAttribute("instance_type") + 
			", id=" + event.getIntAttribute("instance_id") + ", hitbox=" + event.getStringAttribute("hitbox_id"), 1);

		if (event.getStringAttribute("instance_type") == "character" &&
			event.getIntAttribute("instance_id") == m_playerCharacterId) {

			// this event concerns our master player
			//$this->metagame->comms->send("say hello there, you reached " . $event->getAttribute("hitbox_id"));

			string id = event.getStringAttribute("hitbox_id");
			int index = getStageIndexFromExtractionHitboxId(id);

			_log("next stage is " + index, 1);

			// clear hitbox checking now
			clearHitboxAssociations(m_metagame, "character", m_playerCharacterId, m_trackedHitboxes);

			commitToMapChange(index);
		}
	}

    // ----------------------------------------------------
	// debugging tools
    protected void handleChatEvent(const XmlElement@ event) {
		MapRotatorInvasion::handleChatEvent(event);

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
		if (!m_metagame.getAdminManager().isAdmin(sender, senderId)) {
			return;
		}

		if (checkCommand(message, "unlock_final")) {
			unlockFinalBattle(m_finalBattleEnemyFactions.size() + 1);
			determineExtractionHitboxList();
			refreshHitboxes();
		}
	}

	// -------------------------------------------------------
	protected void commitToMapChange(int index) {
		_log("commit_to_map_change, index=" + index, 1);

		// commit to this map change
		m_nextStageIndex = index;

		// query current status about bases, and store it, we may want to continue from where we left
		{
			Stage@ stage = m_stages[m_currentStageIndex];
			// clear owned base information in factions now
			for (uint i = 0; i < stage.m_factions.size(); ++i) {
				Faction@ f = stage.m_factions[i];
				f.m_ownedBases = array<int>();
			}

			array<const XmlElement@> bases = getBases(m_metagame);
			for (uint i = 0; i < bases.size(); ++i) {
				const XmlElement@ node = bases[i];
				int id = node.getIntAttribute("id");
				int ownerId = node.getIntAttribute("owner_id");
				string name = node.getStringAttribute("name");

				if (ownerId >= 0 && ownerId < int(stage.m_factions.size())) {
					Faction@ f = stage.m_factions[ownerId];
					f.m_ownedBases.insertLast(id);
				}
			}
		}

		{
			string command = "<command class='set_soundtrack' enabled='1' />";
			m_metagame.getComms().send(command);
		}

		sendFactionMessageKey(m_metagame, 0, "standby for extraction", dictionary = {}, 1.0); // high priority

		waitAndStartAtMapChangeCommit();
	}

	// -------------------------------------------------------
	protected void waitAndStartAtMapChangeCommit() {
		waitAndStart(1.0f, false);
	}

	// -------------------------------------------------------
	protected const array<const XmlElement@>@ getExtractionHitboxList() const {
		// return cached stuff
		return m_extractionHitboxes;
	}

	// -------------------------------------------------------
	protected void determineExtractionHitboxList() {
		array<const XmlElement@> list;

		_log("determineExtractionHitboxList", 1);
		_log("current stage: " + m_currentStageIndex + ", completed=" + isStageCompleted(m_currentStageIndex), 1);

		bool finalBattleExtractionAvailable = false;
		// if current stage is a final stage, don't allow extraction until it's completed
		Stage@ currentStage = m_stages[m_currentStageIndex];
		if (!currentStage.isFinalBattle() || /* is final && */ isStageCompleted(m_currentStageIndex)) {
			list = getHitboxes(m_metagame);

			// go through the list and only leave the ones in we're interested of, extraction_*
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ hitboxNode = list[i];
				string id = hitboxNode.getStringAttribute("id");
				bool ruleOut = false;
				if (id.findFirst("extraction") < 0) {
					ruleOut = true;

				// - if the current map is completed, all exit points are ok
				// ----- EXCEPT exit points to final battle stages, which are ok additionally only once the final battle stage has been unlocked
				// - if the current map is not completed, only the exit points taking to a completed map are ok, check that
				} else if (!isStageCompleted(m_currentStageIndex)) {
					// current map not completed

					int stageIndex = getStageIndexFromExtractionHitboxId(id);
					if (!isStageCompleted(stageIndex)) {
						// the map this point takes to is not either
						ruleOut = true;
					} else {
						// this point takes to a completed map, it's ok
					}

				} else {
					// current stage completed, all exit points are fine

					// additionally check final battle stage unlock status
					int stageIndex = getStageIndexFromExtractionHitboxId(id);
					if (stageIndex < 0) {
						_log("WARNING, something wrong about " + id + ", not in transport map?", -1); 
						ruleOut = true;
					} else if (m_stages[stageIndex].isFinalBattle()) {
						// target stage is final battle, check if it's unlocked
						int finalBattleIndex = getFinalBattleIndex(stageIndex);
						_log("stage " + stageIndex + " is final battle #" + finalBattleIndex, 1); 
						if (!isFinalBattleUnlocked(finalBattleIndex)) {
							_log("  is not unlocked", 1);
							// it's not, rule out
							ruleOut = true;
						} else {
							finalBattleExtractionAvailable = true;
							_log("  is unlocked", 1);
						}
					}
				}

				if (ruleOut) {
					_log("ruling out " + id, 1);
					// remove this
					list.erase(i);
					// one step back
					i--;
				} else {
					_log("including " + id, 1);
				}
			}
			_log("* " + list.size() + " extraction points found");
		}

		m_extractionHitboxes = list;

		// update map markers
		markExtractionPoints();

		// update world markers
		if (m_world !is null) {
			array<string> transports;
			dictionary@ transportMap;
			m_worldTransportMap.get(toWorldTransportMapKey(m_currentStageIndex), @transportMap);
			if (transportMap !is null) {
				string sourceMap = m_stages[m_currentStageIndex].m_mapInfo.m_id;
				for (uint i = 0; i < transportMap.getKeys().size(); ++i) {
					string hitboxId = transportMap.getKeys()[i];
					int targetStageIndex = 0;
					transportMap.get(hitboxId, targetStageIndex);
					// only show the hitboxes available that are among our accepted extraction hitboxes
					for (uint j = 0; j < m_extractionHitboxes.size(); ++j) {
						const XmlElement@ node = m_extractionHitboxes[j];
						string id = node.getStringAttribute("id");
						if (id == hitboxId) {
							string targetMap = m_stages[targetStageIndex].m_mapInfo.m_id;
							transports.insertLast(getTransportName(sourceMap, targetMap));
						}
					}
				}
			}
			m_world.setAvailableTransports(transports);
		}

		// enable decorative vehicles
		// if final battle extraction is available, enable helicopter 
		if (finalBattleExtractionAvailable)	{
			string command =
				"<command class='faction_resources' faction_id='0'>" +
				"   <vehicle key='heli_extraction.vehicle' enabled='1' />" + 
				"</command>";
			m_metagame.getComms().send(command);
		}
	}

	// --------------------------------------------
    void startMap(int index, bool beginOnly = false) {

		// if current map is complete, change the stage to such now, so that if we get back, it'll be setup properly for 1 faction only
		if (!beginOnly && m_currentStageIndex != index && isStageCompleted(m_currentStageIndex)) {
			// assume 1-faction stages have been already setup in completed state
			if (m_stages[m_currentStageIndex].m_factions.size() > 1) {
				setupStageComplete(m_currentStageIndex);
			}
		}
		
		// if this is the very first map, remove intel manager to not overwhelm new player with it
		if (m_stagesCompleted.size() == 0 && !m_metagame.getUserSettings().m_continueAsNewCampaign) {
			m_stages[index].setIntelManager(null);
		}

		MapRotatorInvasion::startMap(index, beginOnly);

		if (beginOnly && m_currentStageIndex >= 0) {
			// here's 0.97 compatibility:
			// - if we notice a faction being completely beaten here, unlock a final battle
			checkForFinalBattleUnlock();
			// we will anyway update extraction below, no need to check if unlock happened or not here
		}

		determineExtractionHitboxList();
		refreshHitboxes();
		refreshCompletionStatus(false);
	}

	// --------------------------------------------
	void setupStageComplete(int index) {
		Stage@ stage = m_stages[index];
		@stage = m_configurator.setupCompletedStage(stage);
		@m_stages[index] = @stage;
	}

	// --------------------------------------------
	protected int getStageIndexFromMapPath(string path) const {
		int result = -1;
		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			if (stage.m_mapInfo.m_path == path) {
				result = int(i);
				break;
			}
		}
		return result;
	}

    // ----------------------------------------------------
	const Stage@ getCurrentStage() const {
		const Stage@ result = null;
		if (m_currentStageIndex >= 0 && m_currentStageIndex < int(m_stages.size())) {
			@result = @m_stages[m_currentStageIndex];
		}
		return result;
	} 
	
	// --------------------------------------------
	protected void saveImpl(XmlElement@ subroot) {
		MapRotatorInvasion::saveImpl(subroot);

		for (uint i = 0; i < m_stages.size(); ++i) {
			Stage@ stage = m_stages[i];
			XmlElement e("stage");
			for (uint j = 0; j < stage.m_factions.size(); ++j) {
				Faction@ f = stage.m_factions[j];
				XmlElement e2("faction");
				e2.setIntAttribute("index", f.m_config.m_index);
				for (uint k = 0; k < f.m_ownedBases.size(); ++k) {
					int baseId = f.m_ownedBases[k];
					XmlElement e3("base");
					e3.setIntAttribute("id", baseId);
					e2.appendChild(e3);
				}
				e.appendChild(e2);
			}
			subroot.appendChild(e);
		}

		// allocated final stages
		for (uint i = 0; i < m_finalBattleEnemyFactions.size(); ++i) {
			int factionConfigIndex = m_finalBattleEnemyFactions[i];
			XmlElement e("final_battle");
			e.setIntAttribute("enemy_faction_config_index", factionConfigIndex);
			subroot.appendChild(e);
		}

		// current stage might have something to save
		if (m_currentStageIndex >= 0) {
			Stage@ stage = m_stages[m_currentStageIndex];
			stage.save(subroot);
		}
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		MapRotatorInvasion::load(root);

		const XmlElement@ subroot = root.getFirstElementByTagName("map_rotator");
		if (subroot !is null) {
			{
				array<const XmlElement@> list = subroot.getElementsByTagName("stage");
				_log("stages: " + list.size(), 1);
				for (uint i = 0; i < list.size(); ++i) {
					const XmlElement@ e = list[i];
					array<const XmlElement@> list2 = e.getElementsByTagName("faction");
					_log("factions: " + list2.size(), 1);
					for (uint j = 0; j < list2.size(); ++j) {
						const XmlElement@ e2 = list2[j];

						if (m_stages[i].m_factions.size() < j) {
							// assuming here that the participants in a map do not change, yet
							Faction@ f = m_stages[i].m_factions[j];
							f.m_ownedBases = array<int>();

							int factionIndex = e2.getIntAttribute("index");
							array<const XmlElement@> list3 = e2.getElementsByTagName("base");
							for (uint k = 0; k < list3.size(); ++k) {
								const XmlElement@ e3 = list3[k];
								int baseId = e3.getIntAttribute("id");
								f.m_ownedBases.insertLast(baseId);
								_log("base " + baseId + " owned by " + f.m_config.m_index, 1);
							}
						}
					}
				}
			}

			{
				// final stages
				array<const XmlElement@> list = subroot.getElementsByTagName("final_battle");
				for (uint i = 0; i < list.size(); ++i) {
					const XmlElement@ e = list[i];
					int factionConfigIndex = e.getIntAttribute("enemy_faction_config_index");

					// do same procedure as unlocking the final battle would, here, 
					// it will set the stage settings accordingly
					// 
					// if the stage is completed, generic completed settings will be set after this

					unlockFinalBattle(factionConfigIndex);
				}
			}

			// in adventure mode, we can't determine current/next map from completed maps, 
			// so we need to obtain it somewhere else
			// general info has been retrieved from game by now, so determine it from there
			{
				string mapPath = m_metagame.m_gameMapPath;
				int index = getStageIndexFromMapPath(mapPath);
				if (index < 0) {
					_log("ERROR, couldn't resolve stage index from map path, mapPath=" + mapPath);
					index = 0;
				}
				m_nextStageIndex = index;
				m_currentStageIndex = m_nextStageIndex;
				_log("current/next stage at load: " + m_currentStageIndex);
			}

			// current stage might have something to load
			if (m_currentStageIndex >= 0) {
				Stage@ stage = m_stages[m_currentStageIndex];
				stage.load(subroot);
			}

		} else {
			_log("WARNING, map_rotator not found", -1);
		}

		// if maps have been completed, 
		// we should modify the stages 
		// to reflect that
		for (uint i = 0; i < m_stagesCompleted.size(); ++i) {
			int index = m_stagesCompleted[i];
			if (m_currentStageIndex == index) {
				// NOTE, take the factions from the game here, we don't know the actual amount of factions yet on the script side
				// - could be what is initially set in the stages, or in completed stage if already transformed
				if (getFactions(m_metagame).size() > 1) {
					// not yet in complete state, don't setup as such then
					continue;
				}
				// else we have just one faction, so setup the stage in complete state
			}
			setupStageComplete(index);
		}

		postProcessLoad();
	}

	// --------------------------------------------
	void postProcessLoad() {
		// if current map is completed, refresh extraction points
		if (isStageCompleted(m_currentStageIndex)) {
			_log("current map is completed, refresh extraction hitboxes", 1);
			determineExtractionHitboxList();
			refreshHitboxes();
			refreshCompletionStatus(false);
		}
	}
}
