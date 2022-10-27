// internal
#include "tracker.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"

// gamemode specific
#include "vehicle_delivery_to_armory.as"
#include "vehicle_delivery_to_target.as"

// --------------------------------------------
abstract class VehicleDeliveryManager : Tracker {
	protected GameModeInvasion@ m_metagame;
	protected const VehicleDeliveryConfig@ m_config;
	protected int m_requireFactionId;

	// ----------------------------------------------------
	VehicleDeliveryManager(GameModeInvasion@ metagame, const VehicleDeliveryConfig@ config, int requireFactionId = -1) {
		_log("creating VehicleDeliveryManager", 1);
		@m_metagame = @metagame;
		@m_config = @config;
		m_requireFactionId = requireFactionId;
	}

	// ----------------------------------------------------
	bool hasStarted() const {
		return true;
	}

	// ----------------------------------------------------
	bool hasEnded() const {
		return false;
	}

	// ----------------------------------------------------
	protected void handleVehicleSpawnEvent(const XmlElement@ event) {
		string key = event.getStringAttribute("vehicle_key");
		int ownerId = event.getIntAttribute("owner_id");
		if (m_config.m_vehicleKeys.find(key) >= 0 &&
			(m_requireFactionId == -1 || m_requireFactionId == ownerId)) {
			setupVehicleDelivery(event);
		}
	}

	// ----------------------------------------------------
	protected void setupVehicleDelivery(const XmlElement@ event) {}
}

// --------------------------------------------
class VehicleDeliveryToArmoryManager : VehicleDeliveryManager {
	// --------------------------------------------
	VehicleDeliveryToArmoryManager(GameModeInvasion@ metagame, const VehicleDeliveryConfig@ config, int requireFactionId = -1) {
		super(metagame, config, requireFactionId);
	}

	// --------------------------------------------
	protected void setupVehicleDelivery(const XmlElement@ event) {
		string key = event.getStringAttribute("vehicle_key");
		int vehicleId = event.getIntAttribute("vehicle_id");

		VehicleDeliveryToArmory tracker(m_metagame, key, vehicleId, m_config);
		tracker.setupHitboxes();
		// register it
		m_metagame.addTracker(tracker);
	}
}

// --------------------------------------------
class VehicleDeliveryToSpecificTargetManager : VehicleDeliveryManager {
	protected string m_targetHitbox = "";

	// --------------------------------------------
	VehicleDeliveryToSpecificTargetManager(GameModeInvasion@ metagame, string targetHitbox, const VehicleDeliveryConfig@ config) {
		super(metagame, config);

		m_targetHitbox = targetHitbox;
	}

	// --------------------------------------------
	protected void setupVehicleDelivery(const XmlElement@ event) {
		string key = event.getStringAttribute("vehicle_key");
		int vehicleId = event.getIntAttribute("vehicle_id");

		VehicleDeliveryToSpecificTarget tracker(m_metagame, key, vehicleId, m_targetHitbox, m_config);
		tracker.setupHitboxes();
		// register it
		m_metagame.addTracker(tracker);
	}
}
