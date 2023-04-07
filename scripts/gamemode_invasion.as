// internal
#include "gamemode.as"
#include "map_info.as"
#include "log.as"

// gamemode specific
#include "map_rotator_invasion.as"
#include "stage_configurator_invasion.as"
#include "user_settings.as"
#include "item_delivery_configurator_invasion.as"
#include "vehicle_delivery.as"
#include "vehicle_delivery_manager.as"
#include "vehicle_hint_manager.as"
#include "vehicle_delivery_configurator_invasion.as"
#include "match_over_radio_disabler.as"
#include "spawn_time_handler.as"
#include "side_base_attack_handler.as"

// generic trackers
#include "basic_command_handler.as"
#include "autosaver.as"
#include "prison_break_objective.as"
#include "unlock_manager.as"
#include "special_vehicle_manager.as"
#include "penalty_manager.as"
#include "generic_objective_instructor.as"
#include "local_ban_manager.as"
#include "testing_tools_tracker.as"
#include "call_marker_tracker.as"
#include "idler_kicker.as"
#include "supporter_command_handler.as"

// community trackers
#include "gps_laptop.as"
#include "emp_grenade.as"
#include "repair_crane.as"
#include "a10_gun_run.as"
#include "gunship_run.as"
#include "squad_equipment_kit.as"
#include "rangefinder.as"
//#include "halloween.as"  // Halloween event only

// --------------------------------------------
class GameModeInvasion : GameMode, UnlockRemoveListener, UnlockListener {
	protected MapRotatorInvasion@ m_mapRotator;
	protected UnlockManager@ m_unlockManager;
	protected SpecialVehicleManager@ m_specialCrateManager;
	protected SpecialVehicleManager@ m_specialCargoVehicleManager;
	protected ItemDeliveryOrganizer@ m_itemDeliveryOrganizer;
	protected PenaltyManager@ m_penaltyManager;
	protected LocalBanManager@ m_localBanManager;
	
	protected TestingToolsTracker@ m_testingToolsTracker;
	
	protected array<Faction@> m_factions;

	// TODO: can we avoid this?
	string m_gameMapPath = "";

	protected UserSettings@ m_userSettings;

	// --------------------------------------------
	GameModeInvasion(UserSettings@ settings) {
		super(settings.m_startServerCommand);

		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		GameMode::init();

		setupMapRotator();
		setupUnlockManager();
		setupSpecialCrateManager();
		setupSpecialCargoVehicleManager();
		setupItemDeliveryOrganizer();
		setupPenaltyManager();
		setupLocalBanManager();
		setupTestingToolsTracker();
		setupLocalBanManager();

		if (m_userSettings.m_continue) {
			_log("* restoring old game");

			// if loading, load metagame first
			updateGeneralInfo();
			load();
			// note, load handles initing map rotator / unlock_manager / etc at appropriate time

			m_mapRotator.startRotation(true);
		} else {
			// starting the invasion for the first time now, 
			// pick user settings from command line

			m_unlockManager.init(0);

			// - init sets up map rotator according to settings
			// - settings are stored in metagame savegame data
			m_mapRotator.init();

			// changes map, start the match, calls pre/post_begin_match
			m_mapRotator.startRotation();

			// NOTE: the beginning is a bit messed up here;
			// - we start from lobby, so we can't really query faction stuff
			//   or do much anything until the first map changes
			// - also, post_begin_match is set to add most of "metagame level"
			//   things as trackers for the game
			// - problem is, those components haven't been initialized at that point
			// - we only get to initialize them here
			// - right now, it's only item_delivery_organizer that needs to setup something
			//   before executing what normally would be done in post_begin_match, i.e.
			//   set up objectives, then add objectives as trackers in post_begin_match
			// - in case of the very first start, that goes wrong: post_begin_match
			//   informs item_delivery_organizer to add objectives, which haven't been created
			//	 at that point
			// - we'll just workaround that by re-doing that start here, 
			//   after proper initialization
			if (m_itemDeliveryOrganizer !is null) {
				m_itemDeliveryOrganizer.init();
				m_itemDeliveryOrganizer.matchStarted();
			}

			if (m_specialCrateManager !is null) {
				m_specialCrateManager.init();
			}

			if (m_specialCargoVehicleManager !is null) {
				m_specialCargoVehicleManager.init();
			}
		}

	}

	// --------------------------------------------
	void uninit() {
		// save before parent uninit, parent uninitializes comms
		save();

		GameMode::uninit();
	}

	// --------------------------------------------
	protected void setupMapRotator() {
		@m_mapRotator = MapRotatorInvasion(this);
		StageConfiguratorInvasion configurator(this, m_mapRotator);
	}

	// --------------------------------------------
	protected void setupUnlockManager() {
		@m_unlockManager = UnlockManager(this, this);
	}

	// --------------------------------------------
	protected void setupSpecialCrateManager() {
		array<string> trackedCrates;
		trackedCrates.push_back("special_crate_wood1.vehicle");
		trackedCrates.push_back("special_crate_wood2.vehicle");
		trackedCrates.push_back("special_crate_wood3.vehicle");
		trackedCrates.push_back("special_crate_wood4.vehicle");
		trackedCrates.push_back("special_crate_wood5.vehicle");
		trackedCrates.push_back("special_crate_wood6.vehicle");
		trackedCrates.push_back("special_crate_wood7.vehicle");
		trackedCrates.push_back("special_crate_wood8.vehicle");
		trackedCrates.push_back("special_crate_wood9.vehicle");
		trackedCrates.push_back("special_crate_wood10.vehicle");

		@m_specialCrateManager = SpecialVehicleManager(this, "special_crate_manager", trackedCrates);
	}

	// --------------------------------------------
	protected void setupSpecialCargoVehicleManager() {
		array<string> trackedVehicles;
		trackedVehicles.push_back("special_cargo_vehicle1.vehicle");
		trackedVehicles.push_back("special_cargo_vehicle2.vehicle");
		trackedVehicles.push_back("special_cargo_vehicle3.vehicle");
		trackedVehicles.push_back("special_cargo_vehicle4.vehicle");
		trackedVehicles.push_back("special_cargo_vehicle5.vehicle");    

		@m_specialCargoVehicleManager = SpecialVehicleManager(this, "special_cargo_vehicle_manager", trackedVehicles);
	}

	// --------------------------------------------
	protected void setupItemDeliveryOrganizer() {
		// we have multiple simultaneous enemy weapon delivery objectives handled by an organizer
		ItemDeliveryConfiguratorInvasion configurator(this);
		@m_itemDeliveryOrganizer = ItemDeliveryOrganizer(this, configurator);
	}

	// --------------------------------------------
	protected void setupPenaltyManager() {
		if (getUserSettings().m_teamKillPenaltyEnabled) {
			@m_penaltyManager = PenaltyManager(this, 
				m_userSettings.m_teamKillsToStartPenalty, 
				m_userSettings.m_teamKillPenaltyTime, 
				m_userSettings.m_forgiveTeamKillTime);
		}
	}

	// --------------------------------------------
	protected void setupLocalBanManager() {
		@m_localBanManager = LocalBanManager(this);
	}
	
	// --------------------------------------------
	protected void setupTestingToolsTracker() {
		if (getUserSettings().m_testingToolsEnabled) {
			@m_testingToolsTracker = TestingToolsTracker(this);
		}
	}

	// --------------------------------------------
	protected void updateGeneralInfo() {
		const XmlElement@ general = getGeneralInfo(this);
		if (general !is null) {
			m_gameMapPath = general.getStringAttribute("map");
		}
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	void refreshUserSettings(const XmlElement@ event)  {
		m_userSettings.fromXmlElement(event);
	}

	// --------------------------------------------
	// MapRotator calls here when a battle is about to be started
	void preBeginMatch() {
		_log("preBeginMatch", 1);

		// all trackers are cleared when match is about to begin
		GameMode::preBeginMatch();

		// map rotator needs to be added before match starts
		// - adventure mode needs to listen for player spawning which happens right when match starts
		// - usually it's good to add trackers only after match has started
		addTracker(m_mapRotator);

		if (m_specialCrateManager !is null) {
			addTracker(m_specialCrateManager);
			m_specialCrateManager.applyAvailability();
		}

		if (m_specialCargoVehicleManager !is null) {
			addTracker(m_specialCargoVehicleManager);
			m_specialCargoVehicleManager.applyAvailability();
		}

		setupMinibosses();
		setupDogs();
		setupRipper();
		setupGrinch();
	}

	// --------------------------------------------
	// MapRotator calls here when a battle has started
	void postBeginMatch() {
		GameMode::postBeginMatch();

		// query for basic match data -- we mostly need the savegame location
		updateGeneralInfo();
		save();

		// add tracker for time, unlock manager will drop unlocks some time after their activation
		if (m_unlockManager !is null) {
			addTracker(m_unlockManager);
			// re-feed unlocks into game now,
			// doesn't matter if we are loading a game and
			// the unlocks have been already stored and loaded
			// in the game, no harm done
			m_unlockManager.applyUnlocks();
		}

		setupVehicleDeliveryObjectives();
		setupGenericObjectiveInstructions();

		if (m_specialCargoVehicleManager !is null) {
			// add special cargo vehicle related delivery tracker
			array<string> targets = m_specialCargoVehicleManager.newTrackedVehicles();
			VehicleDeliveryConfig config(targets, 0, 1000.0, 0.0, "special_vehicle_delivery_complete");
			addTracker(VehicleDeliveryToArmoryManager(this, config));
		}

		if (m_itemDeliveryOrganizer !is null) {
			// adds trackers
			// NOTE: this works wrong with the very first time a map and match is started
			// in campaign, as item delivery organizer gets to become initialized only
			// after the map has changed and match has started, as it needs to 
			// query own faction resources
			m_itemDeliveryOrganizer.matchStarted();
		}

		if (m_penaltyManager !is null) {
			addTracker(m_penaltyManager);
		}

		if (m_localBanManager !is null) {
			addTracker(m_localBanManager);
		}
		
		if (m_testingToolsTracker !is null) {
			addTracker(m_testingToolsTracker);
		}

		addTracker(PrisonBreakObjective(this, 0));
		setupDisableRadioAtMatchOver();
		addTracker(AutoSaver(this));
		addTracker(BasicCommandHandler(this));
		
		setupExperimentalFeatures();
		setupIcecreamReport();
		
		setupCallMarkers();
		
		setupSpawnTimeHandler();
		setupSideBaseAttackHandler();
		setupIdlerKicker();

		addTracker(SupporterCommandHandler(this));
	}

	// --------------------------------------------
	protected void setupExperimentalFeatures() {
		addTracker(GpsLaptop(this));
		addTracker(EmpGrenade(this));
		addTracker(RepairCrane(this));
		addTracker(A10GunRun(this));
		addTracker(AC130GunRun(this));        
		addTracker(SquadEquipmentKit(this)); 
		addTracker(RangeFinder(this)); 
//		addTracker(Halloween(this));    // Halloween event only
	}

	// --------------------------------------------
	protected void setupMinibosses() {
		{
			// disable minibosses in friendly faction 
			// to prevent harvesting rares from minibosses
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", 0);
			command.setStringAttribute("soldier_group_name", "miniboss");
			command.setFloatAttribute("spawn_score", 0.0f);
			getComms().send(command);

			command.setStringAttribute("soldier_group_name", "miniboss_female");
			getComms().send(command);
		}

		for (uint i = 1; i < m_factions.size(); ++i) {
			const FactionConfig@ config = m_factions[i].m_config;
			// increase minibosses in enemy factions slightly
			// 0.005 -> 0.007 (0.004 male, 0.003 female)
      // 0.007 -> 0.009 (0.006 male, 0.003 female)   (1.65)
			bool femaleExists = true;
			if (config.m_file == "brown.xml") {
				femaleExists = false;
			}

			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", i);
			command.setStringAttribute("soldier_group_name", "miniboss");
			command.setFloatAttribute("spawn_score", femaleExists ? 0.006f : 0.009f);
			getComms().send(command);

			if (femaleExists) {
				command.setStringAttribute("soldier_group_name", "miniboss_female");
				command.setFloatAttribute("spawn_score", 0.003f);
				getComms().send(command);
			}
		}
	}

	// --------------------------------------------
	protected void setupDogs() {
		{
			// enable dogs in friendly faction only
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", 0);
			command.setStringAttribute("soldier_group_name", "dog");
			command.setFloatAttribute("spawn_score", 0.008f);
			getComms().send(command);
        }

		for (uint i = 1; i < m_factions.size(); ++i) {
			const FactionConfig@ config = m_factions[i].m_config;
		{
			// disable dogs in enemy factions 
			// to prevent players to have to kill dogs
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", i);
			command.setStringAttribute("soldier_group_name", "dog");
			command.setFloatAttribute("spawn_score", 0.0f);
			getComms().send(command);
		}

      }
	}

	protected void setupRipper() {
		{
			// disable rippers in friendly faction
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", 0);
			command.setStringAttribute("soldier_group_name", "elite ripper");
			command.setFloatAttribute("spawn_score", 0.0f);
			getComms().send(command);
        }

		for (uint i = 1; i < m_factions.size(); ++i) {
			const FactionConfig@ config = m_factions[i].m_config;
		{
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", i);
			command.setStringAttribute("soldier_group_name", "elite ripper");
			command.setFloatAttribute("spawn_score", 0.0f);    // 0.008 during Halloween event
			getComms().send(command);
		}

      }
	}

	protected void setupGrinch() {
	    _log("Setting up grinch faction...");
		{
			// disable rippers in friendly faction
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", 0);
			command.setStringAttribute("soldier_group_name", "grinch");
			command.setFloatAttribute("spawn_score", 0.0f);
			getComms().send(command);
        }

		for (uint i = 1; i < m_factions.size(); ++i) {
			const FactionConfig@ config = m_factions[i].m_config;
		{
			XmlElement command("command");
			command.setStringAttribute("class", "faction");
			command.setIntAttribute("faction_id", i);
			command.setStringAttribute("soldier_group_name", "grinch");
			command.setFloatAttribute("spawn_score", 0.0f);    // 0.008 during xmas event
			getComms().send(command);
		}

      }
	}

	// --------------------------------------------
	protected void setupDisableRadioAtMatchOver() {
		addTracker(MatchOverRadioDisabler(this));
	}

	// --------------------------------------------
	protected void setupVehicleDeliveryObjectives() {
		VehicleDeliveryConfiguratorInvasion configurator(this);
		configurator.setup();
	}

	// --------------------------------------------
	protected void setupGenericObjectiveInstructions() {
		{
			array<string> vehicles = {
				"radar_tower.vehicle",
				"radar_truck.vehicle",
				"radio_jammer.vehicle",
				"radio_jammer2.vehicle",
				"prison_bus.vehicle",
				"prison_door.vehicle",
				"aa_emplacement.vehicle"
				};
			addTracker(GenericDestroyObjectiveInstructor(this, vehicles));
		}
		{
			array<string> vehicles = {
				"cargo_truck.vehicle"
				};
			addTracker(GenericObjectiveInstructor(this, vehicles));
		}
	}

	// --------------------------------------------
	protected void setupCallMarkers() {
		// if you're adding a call here, make sure it has notify_metagame="1" in it's <call> tag
		array<CallMarkerConfig@> configs = {
			CallMarkerConfig("bf109.call", "call_marker", 7, 1.0, 20.0),
			CallMarkerConfig("blhx_sb_1.call", "call_marker_drop", 11, 0.5),
			CallMarkerConfig("jianpao_daji_1.call", "call_marker", 8, 0.5,60),
			CallMarkerConfig("jianpao_daji_2.call", "call_marker", 9, 0.5,90),            
			CallMarkerConfig("qzyty_humvee.call", "call_marker_drop", 12, 0.5),
			CallMarkerConfig("qzyty_tank.call", "call_marker_drop", 12, 0.5),
			CallMarkerConfig("bujiche.call", "call_marker_drop", 13, 0.5),
			CallMarkerConfig("zhenhai.call", "call_marker", 7, 1.0, 10.0),
			CallMarkerConfig("xiaojiajia.call", "call_marker", 6, 0.5,25),
			CallMarkerConfig("yingxianzuo.call", "call_marker", 14, 0.5,8),
			CallMarkerConfig("zhihuijian_hj.call", "call_marker", 4, 0.5,60),
			CallMarkerConfig("meta_feilong.call", "call_marker", 7, 1.0, 28.0),
			CallMarkerConfig("meta_hd.call", "call_marker", 7, 1.0, 13.0),
			CallMarkerConfig("meta_jianpao2.call", "call_marker", 9, 0.5,80),         
			CallMarkerConfig("meta_zhihuijian.call", "call_marker", 4, 0.5,60),
			CallMarkerConfig("sr_goujianzhe.call", "call_marker", 7, 1.0, 25.0),
			CallMarkerConfig("sr_hd.call", "call_marker", 7, 1.0, 15.0),
			CallMarkerConfig("sr_jianpao2.call", "call_marker", 9, 0.5,85),         
			CallMarkerConfig("zhihuijian_0.call", "call_marker", 4, 0.5,75),
			CallMarkerConfig("sr_zhihuijian.call", "call_marker", 2, 0.5,40),
			CallMarkerConfig("sr_boss_vh_external_storage.call", "call_marker_drop", 2, 0.5,20),
			CallMarkerConfig("siren_wire_control_level.call", "call_marker_drop", 2, 0.5,20),
			CallMarkerConfig("meta_center_bear.call", "call_marker_drop", 2, 0.5,20),
			CallMarkerConfig("blhx_signal_tide.call", "call_marker_drop", 2, 0.5,20),
			};

		addTracker(CallMarkerTracker(this, configs));
	}

	// --------------------------------------------
	protected void setupSpawnTimeHandler() {
		// add for all enemies, skipping friendly at 0
		for (uint i = 1; i < getFactionCount(); ++i) {
			const Faction@ faction = getFactions()[i];
			if (faction.isNeutral()) continue;
			
			// interpolate players 1 -> 32, spawn time 3.0 -> 1.0
			addTracker(SpawnTimeHandler(this, i, 1, 32, 3.0, getUserSettings().m_spawnTimeAtMaxPlayers));
		}
	}
	
	// --------------------------------------------
	protected void setupSideBaseAttackHandler() {
		// add for all enemies, skipping friendly at 0
		for (uint i = 1; i < getFactionCount(); ++i) {
			const Faction@ faction = getFactions()[i];
			if (faction.isNeutral()) continue;
			
			// interpolate players 1 -> 32
			addTracker(SideBaseAttackHandler(this, i, 
				1, 32, 
				0.05, 0.0,    // side base attack probability
				0.005, 0.0)); // lonewolf spawn score
		}
	}

	// --------------------------------------------
	protected void setupIdlerKicker() {
		addTracker(IdlerKicker(this));
	}
	
	// --------------------------------------------
	protected void setupIcecreamReport() {
		VehicleHintConfig hintConfig("icecream.vehicle", "icecream truck exists", "", 0, "region", false, 300.0, 600.0);
		addTracker(VehicleHintManager(this, hintConfig));
	}
	
	// --------------------------------------------
	protected void trackerCompleted(Tracker@ tracker) {
	}

	// --------------------------------------------
	// map rotator is the one that actually defines which factions are in the game and which default values are used,
	// it will feed us the faction data
	void setFactions(const array<Faction@>@ factions) {
		m_factions = factions;
	}

	// --------------------------------------------
	// map rotator lets us know some specific map related information
	// we need for handling position mapping 
	void setMapInfo(const MapInfo@ info) {
		m_mapInfo = info;
	}

	// --------------------------------------------
	// trackers may need to alter things about faction settings and be able to reset them back to defaults,
	// we'll provide the data from here
	const array<Faction@>@ getFactions() const {
		return m_factions;
	}

	// --------------------------------------------
	uint getFactionCount() const {
		return m_factions.size();
	}

	// --------------------------------------------
	const array<FactionConfig@>@ getFactionConfigs() const {
		// in invasion, map rotator decides faction configs
		return m_mapRotator.getFactionConfigs();
	}

	// --------------------------------------------
	float determineFinalFactionCapacityMultiplier(const Faction@ f, uint key) const {
		float completionPercentage = m_mapRotator.getCompletionPercentage();

		float multiplier = 1.0f;
		if (key == 0) {
			// friendly faction
			multiplier = m_userSettings.m_fellowCapacityFactor * f.m_capacityMultiplier;

			if (m_userSettings.m_completionVarianceEnabled) {
				// drain friendly faction power the farther the game goes;
				// player will gain power and will become more effective, so this works as an attempt to counter that a bit
				_log("completion: " + completionPercentage);
				if (completionPercentage > 0.8f) {
					multiplier *= 0.9f;
				} else if (completionPercentage > 0.6f) {
					multiplier *= 0.93f;
				} else if (completionPercentage > 0.4f) {
					multiplier *= 0.97f;
				}
			}

		} else {
			// enemy
			multiplier = m_userSettings.m_enemyCapacityFactor * f.m_capacityMultiplier;

			if (m_userSettings.m_completionVarianceEnabled) {
				// first map: reduce enemies a bit, let it flow easier
				if (completionPercentage < 0.09f) {
					multiplier *= 0.97f;
				}
			}
		}			

		return multiplier;
	}

	// --------------------------------------------
	void itemUnlocked(const Resource@ resource) {
		_log("item unlocked, " + resource.m_key, 1);
		if (m_unlockManager !is null) {
			m_unlockManager.add(resource);
		}
	}

	// --------------------------------------------
	void itemUnlockRemoved(const Resource@ resource) {
		// enemy weapon deliverable objectives must be re-added for tracking whenever a related unlock is removed;

		// refresh the status here then, only the missing ones will be added
		if (m_itemDeliveryOrganizer !is null) {
			m_itemDeliveryOrganizer.refresh();
		}
	}

	// --------------------------------------------
	void save() {
		// don't bother saving when dedicated server, for now
	}

	// --------------------------------------------
	void load() {
	}

	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// --------------------------------------------
	// helpers and convenience functions
	// --------------------------------------------
	string getMapId() const {
		return m_mapInfo.m_path;
	}

	// --------------------------------------------------------
	const XmlElement@ queryLocalPlayer() const {
		array<const XmlElement@> players = getGenericObjectList(this, "players", "player");
		const XmlElement@ player = null;
		for (uint i = 0; i < players.size(); ++i) {
			const XmlElement@ info = players[i];

			string name = info.getStringAttribute("name");

			_log("player: " + name + ", target player is " + m_userSettings.m_username);
			if (name == m_userSettings.m_username) {
				_log("ok");
				@player = @info;
				break;
			} else {
				_log("no match");
			}			
		}
		return player;
	}
}

