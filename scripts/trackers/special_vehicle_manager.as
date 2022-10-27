// internal
#include "query_helpers.as"
#include "tracker.as"
#include "log.as"

// ----------------------------------------------------
class SpecialVehicleManager : Tracker {
	protected GameMode@ m_metagame;
	protected dictionary m_trackedMaps;
	protected string m_managerName;
	protected array<string> m_allTrackedVehicles;

	// ----------------------------------------------------
	SpecialVehicleManager(GameMode@ metagame, string managerName, array<string> allTrackedVehicles) {
		@m_metagame = @metagame;
		m_managerName = managerName;
		m_allTrackedVehicles = allTrackedVehicles;
	}

	// --------------------------------------------
	void init() {
	}

	// --------------------------------------------
	void start() {
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
	void update(float time) {
	}

	// ----------------------------------------------------
	array<string> newTrackedVehicles() {
		return m_allTrackedVehicles; // copies a mutable copy
	}

	// ----------------------------------------------------
	protected array<string>@ getTrackedVehicles() {
		string id = m_metagame.getMapId();

		_log("get_tracked_vehicles, id=" + id, 1);
		for (uint i = 0; i < m_trackedMaps.getKeys().size(); ++i) {
			string key = m_trackedMaps.getKeys()[i];
			_log("  " + key, 1);
		}
		if (!m_trackedMaps.exists(id)) {
			_log("not found in tracked maps, initializing", 1);
			m_trackedMaps.set(id, @(newTrackedVehicles()));
		}

		array<string>@ result;
		m_trackedMaps.get(id, @result);
		return result;
	}

	// ----------------------------------------------------
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		_log("handle_vehicle_destroyed_event", 1);

		array<string>@ trackedVehicles = getTrackedVehicles();
		string key = event.getStringAttribute("vehicle_key");
		int index = trackedVehicles.find(key);
		if (index >= 0) {
			// found it, remove it
			_log("one of the tracked vehicles, removing tracking now, " + index, 1);

			trackedVehicles.erase(index);
			// left:
			_log("left:", 1);
			for (uint i = 0; i < trackedVehicles.size(); ++i) {
				string k = trackedVehicles[i];
				_log(i + ". " + k, 1);
			}

			applyAvailability();

			// completely remove the vehicle when destroyed;
			// - fits with cargo vehicles brought in, they just vanish
			// - fits with cargo crates, they're already gone anyway
			removeVehicle(m_metagame, event.getIntAttribute("vehicle_id"));
		}
	}

	// --------------------------------------------
	void applyAvailability() {
		_log("apply_availability", 1);

		// disable missing ones in all factions
		{
			int factionCount = m_metagame.getFactionCount();
			array<string> allVehicles = newTrackedVehicles();
			array<string>@ mapVehicles = getTrackedVehicles();

			array<string> removedVehicles = arrayDiff(allVehicles, mapVehicles);
			if (removedVehicles.size() > 0) {
				for (uint i = 0; i < uint(factionCount); ++i) {
					int factionId = i;

					string command = "<command class='faction_resources' faction_id='" + factionId + "'>\n";
					for (uint j = 0; j < removedVehicles.size(); ++j) {
						string vehicleKey = removedVehicles[j];
						command += "  <vehicle key='" + vehicleKey + "' enabled='0' />\n";
					}
					command += "</command>\n";

					m_metagame.getComms().send(command);
				}
			}
		}
	}

	// --------------------------------------------
	void save(XmlElement@ root) {
		XmlElement@ parent = @root;
		XmlElement subroot(m_managerName);
		_log("saving " + m_managerName, 1);
		for (uint i = 0; i < m_trackedMaps.getKeys().size(); ++i) {
			string id = m_trackedMaps.getKeys()[i];
			array<string>@ vehicles;
			m_trackedMaps.get(id, @vehicles);

			XmlElement e("map");
			e.setStringAttribute("id", id);
			_log("map: " + id, 1);
			for (uint j = 0; j < vehicles.size(); ++j) {
				string key = vehicles[j];
				XmlElement e2("vehicle");
				e2.setStringAttribute("key", key);
				_log("  key: " + key, 1);
				e.appendChild(e2);
			}
			subroot.appendChild(e);
		}
		parent.appendChild(subroot);
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		_log("loading " + m_managerName, 1);
		m_trackedMaps.deleteAll();

		const XmlElement@ subroot = root.getFirstElementByTagName(m_managerName);
		if (subroot !is null) {
			_log(m_managerName + " found", 1);
			array<const XmlElement@> list = subroot.getElementsByTagName("map");
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ e = list[i];
				string id = e.getStringAttribute("id");

				_log("map: " + id, 1);

				m_trackedMaps.set(id, array<string>());

				array<const XmlElement@> list2 = e.getElementsByTagName("vehicle");
				for (uint j = 0; j < list2.size(); ++j) {
					const XmlElement@ e2 = list2[j];
					string key = e2.getStringAttribute("key");

					array<string>@ result;
					m_trackedMaps.get(id, @result);
					result.insertLast(key);
					
					_log("adding existing vehicle for tracking: " + key, 1);
				}
			}
		} else {
			_log(m_managerName + " not found", 1);
		}
	}
}
