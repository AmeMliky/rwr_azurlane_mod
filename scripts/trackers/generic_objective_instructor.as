// internal
#include "tracker.as"
#include "log.as"
#include "query_helpers.as"

// --------------------------------------------
class GenericObjectiveInstructor : Tracker {
	protected Metagame@ m_metagame;
	protected array<string> m_vehicles;

	// ----------------------------------------------------
	GenericObjectiveInstructor(Metagame@ metagame, const array<string>@ vehicles) {
		@m_metagame = @metagame;
		m_vehicles = vehicles;
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
	protected void handleVehicleSpotEvent(const XmlElement@ event) {
		if (event.getIntAttribute("faction_id") != 0) return;
		if (event.getIntAttribute("owner_id") == 0) return;
		string key = event.getStringAttribute("vehicle_key");
		if (m_vehicles.find(key) < 0) return;
		
		sendFactionMessageKey(m_metagame, 0, key + " spotted, instructions");
	}
}

// --------------------------------------------
class GenericDestroyObjectiveInstructor : GenericObjectiveInstructor {
	// ----------------------------------------------------
	GenericDestroyObjectiveInstructor(Metagame@ metagame, const array<string>@ vehicles) {
		super(metagame, vehicles);
	}

	// ----------------------------------------------------
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		if (event.getIntAttribute("faction_id") != 0) return;
		if (event.getIntAttribute("owner_id") == 0) return;
		string key = event.getStringAttribute("vehicle_key");
		if (m_vehicles.find(key) < 0) return;
		
		sendFactionMessageKey(m_metagame, 0, key + " destroyed");
		playObjectiveCompleteSound(m_metagame, 0);
	}


}
