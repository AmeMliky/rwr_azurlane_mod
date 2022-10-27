
/*
// mapping between id and name:
	<region id='0' name='map1' position='507.167 424.251' size='317.45 288.05' texture_rect='0.00255368 0.56884 0.149521 0.702197'>
	<region id='1' name='map2' position='265.867 415.101' size='266.566 248.404' texture_rect='0.00255368 0.452172 0.125964 0.567173'>
	<region id='2' name='map3' position='738.034 386.636' size='240.018 249.571' texture_rect='0.21322 0.653129 0.32434 0.768671'>
	<region id='3' name='map4' position='475.616 241.287' size='348.876 243.276' texture_rect='0.457748 0.452172 0.619265 0.564799'>
	<region id='4' name='map5' position='295.878 588.127' size='262.178 195.27' texture_rect='0.457748 0.703863 0.579127 0.794266'>
	<region id='5' name='map6' position='509.833 663.708' size='328.132 312.572' texture_rect='0.00255367 0.795933 0.154467 0.940642'>
	<region id='6' name='map7' position='699.226 545.454' size='212.553 132.547' texture_rect='0.741748 0.475796 0.840152 0.53716'>
	<region id='7' name='map8' position='269.343 746.663' size='238.823 191.059' texture_rect='0.747081 0.675671 0.857648 0.764124'>
	<region id='8' name='map9' position='717.845 641.206' size='305.814 338.823' texture_rect='0.457748 0.795933 0.599329 0.952796'>
*/

/*
int getMapIndexFromMapId(string mapPath) {
	$matches = array();
	if (preg_match('#(\d+)$#', $map_path, $matches)) {
		return $matches[0];
	}

	_log("ERROR: getMapIndexFromMapId, mapPath=" + mapPath + ", no index found", -1);
}
*/

// ----------------------------------------------------------------------------
class Marker {
	string m_size;
	string m_rect;
};

// ----------------------------------------------------------------------------
abstract class World {
	protected Metagame@ m_metagame;
	protected array<int> m_transportVisualIds;
	protected array<int> m_lockedVisualIds;

	protected dictionary m_mapIdToRegionIndex;
	protected string m_worldInitCommand;
	
	// --------------------------------------------
	World(Metagame@ metagame) {
		@m_metagame = @metagame;
	}

	// ----------------------------------------------------------------------------
	protected string getOffenderVisualCommand(string transportName, int colorFactionId, int id) const {
		// provide implementation in derived class
		return "";
	}

	/*
	// ----------------------------------------------------------------------------
	protected string getCursorCommand(string mapName, int id) const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	protected string getLockedCommand(string mapName, int id) const {
		// provide implementation in derived class
		return "";
	}
	*/

	// ----------------------------------------------------------------------------
	protected Marker getMarker(string key) const {
		// provide implementation in derived class
		return Marker();
	}

	// ----------------------------------------------------------------------------
	protected string getPosition(string key) const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	protected string getInitCommand() const {
		// provide implementation in derived class
		return "";
	}

	// ----------------------------------------------------------------------------
	void init(dictionary mapIdToRegionIndex) {
		m_mapIdToRegionIndex = mapIdToRegionIndex;
	}

	// ----------------------------------------------------------------------------
	void setup(const array<FactionConfig@>@ factionConfigs, const array<Stage@>@ stages, const array<int>@ stagesCompleted, int currentStageIndex) {
		m_metagame.getComms().send(getInitCommand());

		// TODO
		// we could make this stuff work so that the command coming from init_worldview
		// would be correctly setup regarding faction_configs initially, but we'll just 
		// overwrite the situation here immediately after the regions have been sent,
		// no one cares
		{
			string command = "<command class='set_world_situation'>";
			for (uint i = 0; i < factionConfigs.size(); ++i) {
			FactionConfig@ faction = factionConfigs[i];
				command += "<faction id='" + i + "' name='" + faction.m_name + "' color='" + faction.m_color + "' />";
			}
			command += "</command>";
			m_metagame.getComms().send(command);
		}

		// send world view setup
		refresh(stages, stagesCompleted, currentStageIndex);

		// set current location in world view
		setCurrentLocation(stages[currentStageIndex]);
	}

	// ----------------------------------------------------------------------------
	// advance phase shares markers with offenders currently
	void setAdvance(string currentMapId, string nextMapId) {
		string transportName = currentMapId + "_to_" + nextMapId;

		string command = getOffenderVisualCommand(transportName, 0, 300);

		if (command != "") {
			m_metagame.getComms().send(command);
		}
	}

	// ----------------------------------------------------------------------------
	protected int convertMapIdToRegionIndex(string mapId) const {
		if (m_mapIdToRegionIndex.exists(mapId)) {
			int value = 0;
			m_mapIdToRegionIndex.get(mapId, value);
			return value;
		}
		return -1;
	}

	// ----------------------------------------------------------------------------
	protected string getRegionSituation(Stage@ stage) const {
		int regionIndex = convertMapIdToRegionIndex(stage.m_mapInfo.m_id);
		if (regionIndex < 0) return "";

		//_log("get_region_situation: stage_index=" . $stage_index . " map_index=" . $map_index . " region_index=" . $region_index); 

		string situation = "<region id='" + regionIndex + "'>\n";
		float ratio = 1.0;
		if (stage.m_factions.size() > 1) {
			ratio = 1.0 / stage.m_factions.size();
		}
		for (uint i = 0; i < stage.m_factions.size(); ++i) {
			Faction@ f = stage.m_factions[i];
			// the stages have friendlies present in each and every stage,
			// but in world view we only show the enemy occupation
			// (completed maps will override this in later phase of execution)
			if (f.m_config.m_index != 0) {
				situation += "<occupant id='" + f.m_config.m_index + "' value='" + ratio + "'/>\n";
			}
		}
		situation += "</region>\n";

		return situation;
	}

	// ----------------------------------------------------------------------------
	void refresh(const array<Stage@>@ stages, const array<int>@ stagesCompleted, int currentStageIndex) {
		array<string> regionSituations;
		for (uint i = 0; i < stages.size(); ++i) {
			Stage@ stage = stages[i];
			// the regions are added in the list with stage keys in stage order!
			string value = getRegionSituation(stage);
			if (value != "") {
				regionSituations.insertLast(value);
			}
		}

		// regions
		{
			int locationVisualIndex = 100;
			string command = "<command class='set_world_situation'>";
			for (uint stageIndex = 0; stageIndex < regionSituations.size(); ++stageIndex) {
				_log("* stageIndex=" + stageIndex);
				string value = regionSituations[stageIndex];
				Stage@ stage = stages[stageIndex];
				int regionIndex = convertMapIdToRegionIndex(stage.m_mapInfo.m_id);

				//_log("refresh: regionIndex=" + regionIndex + ", mapIndex=" + mapIndex + ", stageIndex=" + stageIndex, 1); 
				// if greens have completed the region, mark it
				if (stagesCompleted.find(stageIndex) >= 0) {
					string region =
						"<region id='" + regionIndex + "'>" + 
						"	<occupant id='0' value='1.0'/>" +
						"</region>";
					command += region;

				} else if (stage.isHidden()) {
					
				} else {
					// else show the region normally
					command += value;
				}

				if (!stage.isHidden()) {
					command += getVisualTag(locationVisualIndex, 1, getPosition(stage.m_mapInfo.m_id), getMarker("map_point"), -1);
					locationVisualIndex++;
				}
			}
			command += "</command>";
			m_metagame.getComms().send(command);
		}

		// update world view locked stages state
		setLockedStages(stages);
	}

	// ----------------------------------------------------------------------------
	protected void clearVisuals(const array<int>@ visualIds) {
		string command = "<command class='set_world_situation'>";
		for (uint i = 0; i < visualIds.size(); ++i) {
			int value = visualIds[i];
			string p = "<visual id='" + value + "' layer='1' enabled='false' />";
			command += p;
		}
		command +="</command>";

		m_metagame.getComms().send(command);
	}

	// ----------------------------------------------------------------------------
	void clearTransportVisuals() {
		clearVisuals(m_transportVisualIds);
	}

	// ----------------------------------------------------------------------------
	void setAvailableTransports(array<string>@ transports) {
		// clear ids first
		m_transportVisualIds = array<int>();

		int id = 400;

		for (uint i = 0; i < transports.size(); ++i) {
			string transport = transports[i];
			// using the "offender" visual here, it's the advance arrow
			string command = getOffenderVisualCommand(transport, 0, id);
			if (command != "") {
				m_transportVisualIds.insertLast(id); id++;

				m_metagame.getComms().send(command);
			}
		}
	}

	// ----------------------------------------------------------------------------
	protected string getVisualTag(int id, int layer, string position, const Marker@ marker, int factionColorId) {
		return "<visual id='" + id + "' layer='" + layer + "' position='" + position + "' size='" + marker.m_size + "' texture_rect='" + marker.m_rect + "' color_faction='" + factionColorId + "' />";
	}

	// ----------------------------------------------------------------------------
	protected string getVisualCommand(string visualTag) {
		return "<command class='set_world_situation'>" + visualTag + "</command>";
	}

	// ----------------------------------------------------------------------------
	void setCurrentLocation(Stage@ stage) {
		string mapId = stage.m_mapInfo.m_id;

		//string command = getCursorCommand(mapId, 200);
		string command = getVisualCommand(getVisualTag(200, 1, getPosition(mapId), getMarker("cursor"), 0));

		m_metagame.getComms().send(command);
	}

	// ----------------------------------------------------------------------------
	protected void setLockedStages(const array<Stage@>@ stages) {
		clearVisuals(m_lockedVisualIds);
		m_lockedVisualIds = array<int>();

		int id = 500;
		for (uint i = 0; i < stages.size(); ++i) {
			Stage@ stage = stages[i];
			if (stage.isHidden()) {
				// show locked
				string mapId = stage.m_mapInfo.m_id;

				//string command = getLockedCommand(mapId, id);
				string command = getVisualCommand(getVisualTag(id, 1, getPosition(mapId), getMarker("boss"), -1));

				m_lockedVisualIds.insertLast(id); id++;
				m_metagame.getComms().send(command);
			}
		}
	}
}
