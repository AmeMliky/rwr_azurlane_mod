#include "stage_configurator_invasion.as"

// ------------------------------------------------------------------------------------------------
class StageConfiguratorCampaign : StageConfiguratorInvasion {
	MapRotatorCampaign@ m_mapRotatorCampaign;

	// ------------------------------------------------------------------------------------------------
	StageConfiguratorCampaign(GameModeInvasion@ metagame, MapRotatorCampaign@ mapRotator) {
		super(metagame, mapRotator);
		// also need to store the adventure specific pointer, avoid casting
		@m_mapRotatorCampaign = @mapRotator;
	}

	// ------------------------------------------------------------------------------------------------
	void setup() {
		StageConfiguratorInvasion::setup();
		setupFinalStages();    

		setupTransports();
		setupStartingMaps();
	}

	// ------------------------------------------------------------------------------------------------
	Stage@ setupCompletedStage(Stage@ inputStage) {
		Stage@ stage = createStage();

		stage.m_mapInfo = inputStage.m_mapInfo;
		stage.m_finalBattle = inputStage.m_finalBattle;
		stage.m_includeLayers = inputStage.m_includeLayers;

		stage.m_maxSoldiers = 40;

		{
			Faction f(getFactionConfigs()[0], createCommanderAiCommand(0));
			stage.m_factions.insertLast(f);
		}
		
		addFixedSpecialCrates(stage);
		addRandomSpecialCrates(stage, stage.m_minRandomCrates, stage.m_maxRandomCrates);
	
		return stage;
	}

	// ------------------------------------------------------------------------------------------------
    protected void addStage(Stage@ stage) {
        stage.m_includeLayers.insertLast("layer1.campaign_only");

        // invasion has added a special layer for more resistance, remove it for single player
        int index = stage.m_includeLayers.find("layer1.invasion");
        if (index >= 0) {
            stage.m_includeLayers.removeAt(index);
        }
        StageConfiguratorInvasion::addStage(stage);
    }
 
	// ------------------------------------------------------------------------------------------------
	protected void setupNormalStages() {
		addStage(setupStage1());
		addStage(setupStage2());
		addStage(setupStage3());
		addStage(setupStage4());
		addStage(setupStage5());
		addStage(setupStage6());
		addStage(setupStage7());
		addStage(setupStage8());
		addStage(setupStage9());
		addStage(setupStage10());
	}

	// ------------------------------------------------------------------------------------------------
	protected void setupFinalStages() {
		addStage(setupFinalStage1());
		addStage(setupFinalStage2());
	}
	// --------------------------------------------
	protected void setupWorld() {
		// World disabled in Invasion for now, map10 elements are missing
		WorldCampaign world(m_metagame);

		dictionary mapIdToRegionIndex;
		mapIdToRegionIndex.set("map1", 0);
		mapIdToRegionIndex.set("map2", 1);
		mapIdToRegionIndex.set("map3", 2);
		mapIdToRegionIndex.set("map4", 3);
		mapIdToRegionIndex.set("map5", 4);
		mapIdToRegionIndex.set("map6", 5);
		mapIdToRegionIndex.set("map7", 6);
		mapIdToRegionIndex.set("map8", 7);
		mapIdToRegionIndex.set("map9", 8);
		mapIdToRegionIndex.set("map10", 9);
		mapIdToRegionIndex.set("map11", 10);
		mapIdToRegionIndex.set("map12", 11);

		world.init(mapIdToRegionIndex);

		m_mapRotatorCampaign.setWorld(world);
	}

	// --------------------------------------------
	protected void setupTransports() {
		addTransport("map1", "hitbox_extraction8", "map8");
		addTransport("map1", "hitbox_extraction6", "map6");
		addTransport("map1", "hitbox_extraction3", "map3");    
	    addTransport("map1", "hitbox_extraction11", "map11");
	    addTransport("map1", "hitbox_extraction12", "map12");

		addTransport("map2", "hitbox_extraction8", "map8");
		addTransport("map2", "hitbox_extraction4", "map4");    
	    addTransport("map2", "hitbox_extraction11", "map11");
	    addTransport("map2", "hitbox_extraction12", "map12");

		addTransport("map3", "hitbox_extraction7", "map7");
		addTransport("map3", "hitbox_extraction9", "map9");
		addTransport("map3", "hitbox_extraction1", "map1");
		addTransport("map3", "hitbox_extraction4", "map4");
	    addTransport("map3", "hitbox_extraction11", "map11");
	    addTransport("map3", "hitbox_extraction12", "map12");

		addTransport("map4", "hitbox_extraction3", "map3");
		addTransport("map4", "hitbox_extraction3-1", "map3");
		addTransport("map4", "hitbox_extraction2", "map2");    
	    addTransport("map4", "hitbox_extraction11", "map11");
	    addTransport("map4", "hitbox_extraction12", "map12");

		addTransport("map5", "hitbox_extraction6", "map6");
		addTransport("map5", "hitbox_extraction6-2", "map6");
		addTransport("map5", "hitbox_extraction5-10", "map10");
	    addTransport("map5", "hitbox_extraction11", "map11");
	    addTransport("map5", "hitbox_extraction12", "map12");

		addTransport("map6", "hitbox_extraction5", "map5");
		addTransport("map6", "hitbox_extraction9", "map9");
		addTransport("map6", "hitbox_extraction1", "map1");
		addTransport("map6", "hitbox_extraction8", "map8");
	    addTransport("map6", "hitbox_extraction11", "map11");
	    addTransport("map6", "hitbox_extraction12", "map12");

		addTransport("map7", "hitbox_extraction3", "map3");
	    addTransport("map7", "hitbox_extraction11", "map11");
	    addTransport("map7", "hitbox_extraction12", "map12");

		addTransport("map8", "hitbox_extraction2", "map2");
		addTransport("map8", "hitbox_extraction6", "map6");
		addTransport("map8", "hitbox_extraction1", "map1");
	    addTransport("map8", "hitbox_extraction11", "map11");  
	    addTransport("map8", "hitbox_extraction12", "map12");  

		addTransport("map9", "hitbox_extraction9-3", "map3");
		addTransport("map9", "hitbox_extraction9-6", "map6");
		addTransport("map9", "hitbox_extraction9-10", "map10");
	    addTransport("map9", "hitbox_extraction11", "map11");  
	    addTransport("map9", "hitbox_extraction12", "map12");  

		addTransport("map10", "hitbox_extraction10-5", "map5");
	    addTransport("map10", "hitbox_extraction10-9", "map9"); 
	    addTransport("map10", "hitbox_extraction10-9-2", "map9");       
	    addTransport("map10", "hitbox_extraction11", "map11");  
	    addTransport("map10", "hitbox_extraction12", "map12");  

		// from 1st final map, map11
	    addTransport("map11", "hitbox_extraction1", "map1");
	    addTransport("map11", "hitbox_extraction2", "map2");
	    addTransport("map11", "hitbox_extraction3", "map3");
	    addTransport("map11", "hitbox_extraction4", "map4");
	    addTransport("map11", "hitbox_extraction5", "map5");
	    addTransport("map11", "hitbox_extraction6", "map6");
	    addTransport("map11", "hitbox_extraction7", "map7");
	    addTransport("map11", "hitbox_extraction8", "map8");  
	    addTransport("map11", "hitbox_extraction9", "map9");  
	    addTransport("map11", "hitbox_extraction10", "map10");  
	    addTransport("map11", "hitbox_extraction12", "map12");  

		// from 2nd final map, map12
	    addTransport("map12", "hitbox_extraction1", "map1");
	    addTransport("map12", "hitbox_extraction2", "map2");
	    addTransport("map12", "hitbox_extraction3", "map3");
	    addTransport("map12", "hitbox_extraction4", "map4");
	    addTransport("map12", "hitbox_extraction5", "map5");
	    addTransport("map12", "hitbox_extraction6", "map6");
	    addTransport("map12", "hitbox_extraction7", "map7");
	    addTransport("map12", "hitbox_extraction8", "map8");  
	    addTransport("map12", "hitbox_extraction9", "map9");  
	    addTransport("map12", "hitbox_extraction9", "map10");  
	    addTransport("map12", "hitbox_extraction11", "map11");  
	}

	// --------------------------------------------
	protected void addTransport(string sourceMapName, string hitboxId, string targetMapName) {
		m_mapRotatorCampaign.addTransport(sourceMapName, hitboxId, targetMapName);
	}

	// --------------------------------------------
	protected void setupStartingMaps() {
		m_mapRotatorCampaign.addStartingMap("map2");
		// map4 no longer an option as a starting map
		//m_mapRotatorCampaign.addStartingMap("map4");

		const UserSettings@ settings = m_metagame.getUserSettings();
		if (settings.m_continueAsNewCampaign) {
			// add more starting maps when continuing the campaign after finishing it
			m_mapRotatorCampaign.addStartingMap("map1");
			m_mapRotatorCampaign.addStartingMap("map3");
			m_mapRotatorCampaign.addStartingMap("map5");
			m_mapRotatorCampaign.addStartingMap("map6");
			m_mapRotatorCampaign.addStartingMap("map7");
			m_mapRotatorCampaign.addStartingMap("map8");
			m_mapRotatorCampaign.addStartingMap("map9");
			m_mapRotatorCampaign.addStartingMap("map10");
		}
	}
	
	// --------------------------------------------
	protected void addLotteryVehicle(Stage@ stage) {
		// not in campaign? comment this out
		StageConfiguratorInvasion::addLotteryVehicle(stage);
	}
	
	// --------------------------------------------
	protected void addDarkcatVehicle(Stage@ stage) {
		// not in campaign? comment this out
		// StageConfiguratorInvasion::addDarkcatVehicle(stage);
	}	
}

// generated by atlas.exe
#include "world_init.as"
#include "world_offender_visual.as"
#include "world_marker.as"

// ------------------------------------------------------------------------------------------------
class WorldCampaign : World {
	WorldCampaign(Metagame@ metagame) {
		super(metagame);
	}

	// ------------------------------------------------------------------------------------------------
	protected string getOffenderVisualCommand(string transportName, int colorFactionId, int id) const {
		return getWorldOffenderVisualCommand(transportName, colorFactionId, id);
	}

	// ----------------------------------------------------------------------------
	protected Marker getMarker(string key) const {
		return getWorldMarker(key);
	}

	// ----------------------------------------------------------------------------
	protected string getPosition(string key) const {
		return getWorldPosition(key);
	}

	// ------------------------------------------------------------------------------------------------
	protected string getInitCommand() const {
		return getWorldInitCommand();
	}
}