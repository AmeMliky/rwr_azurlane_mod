// internal
#include "objective.as"
#include "log.as"
#include "helpers.as"
#include "query_helpers.as"

// --------------------------------------------
class PrisonBreakObjective : Objective {
	protected array<string> m_vehicleKeys;
	protected string m_vehicleName;
	protected string m_enemyName;
	protected int m_factionId;

	// multiple escapes can happen simultaneously
	protected array<Escape@> m_escapes;

	// ----------------------------------------------------
	PrisonBreakObjective(Metagame@ metagame, int factionId) {
		super(metagame);

		m_factionId = factionId;

		m_vehicleKeys = array<string> = {"prison_bus.vehicle", "prison_door.vehicle", "prison_hatch.vehicle"};
		m_vehicleName = "Prison";
		m_enemyName = "Enemy";
	}

	// ----------------------------------------------------
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		// don't process if not properly started
		if (!hasStarted()) return;

		string vehicleKey = event.getStringAttribute("vehicle_key");
		int index = m_vehicleKeys.find(vehicleKey);
		if (index >= 0) {
			_log("prison break completed", 1);
			sendFactionMessageKey(m_metagame, m_factionId, "prison break completed");
			
			// in invasion, we don't need to know who owns the prison, it always spawns friendlies
			// - in PvP we would need to know that, just keep prison out of there, at least for now

			// start spawning
			const XmlElement@ vehicle = getVehicleInfo(m_metagame, event.getIntAttribute("vehicle_id"));
			if (vehicle !is null && vehicle.getIntAttribute("id") >= 0) {
				_log("vehicle ok, start spawning", 1);
				Vector3 position = stringToVector3(vehicle.getStringAttribute("position"));
				Vector3 forward = stringToVector3(vehicle.getStringAttribute("forward"));
				Vector3 right = stringToVector3(vehicle.getStringAttribute("right"));
				Vector3 offset();
				if (vehicleKey == "prison_bus.vehicle") {
					offset = Vector3(0.0, 0.0, 8.0);
				} else if (vehicleKey == "prison_door.vehicle") {
					offset = Vector3(0.0, 0.0, -2.0);
				}
				m_escapes.insertLast(Escape(m_metagame, m_factionId, position, forward, right, offset));
			}
		}
	}

	// ----------------------------------------------------
	protected void handleBaseOwnerChangeEvent(const XmlElement@ event) {
		// don't process if not properly started
		if (!hasStarted()) return;

		// we could make prisons in this base area destroyed when base is captured by friendlies
	}

	// ----------------------------------------------------
	void update(float time) {
		for (uint i = 0; i < m_escapes.size(); ++i) {
			Escape@ escape = m_escapes[i];

			escape.update(time);

			if (escape.hasEnded()) {
				m_escapes.erase(i);
				--i;
			}
		}
	}
}

// --------------------------------------------
class Escape {
	protected Metagame@ m_metagame;
	protected Vector3 m_position;
	protected Vector3 m_forward;
	protected Vector3 m_right;
	protected float m_spawnTimer;
	protected int m_soldiersToSpawn;
	protected int m_factionId;

	protected Vector3 m_offset;

	protected float MIN_SPAWN_TIME = 2.0;
	protected float MAX_SPAWN_TIME = 4.0;
	protected int TOTAL_SOLDIERS_TO_SPAWN = 20;

	// --------------------------------------------
	Escape(Metagame@ metagame, int factionId, const Vector3@ position, const Vector3@ forward, const Vector3@ right, const Vector3@ offset) {
		@m_metagame = @metagame;
		m_position = position;
		m_forward = forward;
		m_right = right;
		m_offset = offset;

		m_spawnTimer = getSpawnTime();
		m_soldiersToSpawn = TOTAL_SOLDIERS_TO_SPAWN;
		m_factionId = 0;
	}

	// --------------------------------------------
	void update(float time) {
		if (m_soldiersToSpawn <= 0) return;

		_log("spawn timer " + m_spawnTimer, 1);
		m_spawnTimer -= time;
		if (m_spawnTimer < 0.0) {
			// time to spawn
			spawn();

			m_soldiersToSpawn -= 1;
			m_spawnTimer = getSpawnTime();
		}
	}

	// --------------------------------------------
	float getSpawnTime() const {
		// TODO: randomize between min and max
		return MIN_SPAWN_TIME;
	}

	// --------------------------------------------
	void spawn() {
		// variate position a bit, or use specific points, take orientation into account

		// offset some in +z in vehicle space to get to the imaginary spawn point
		Vector3 offsetX = m_right.scale(m_offset[0]);
		Vector3 offsetZ = m_forward.scale(m_offset[2]);
		Vector3 offset = offsetX.add(offsetZ);
		Vector3 position = m_position;
		position = position.add(offset);

		string command = "<command "+
			"class='create_instance' "+
			"faction_id='" + m_factionId + "' "+
			"position='" + position.toString() + "' "+
			"instance_class='character' "+
			"instance_key='prisoner' "+
			"/>";
		m_metagame.getComms().send(command);
	}

	// --------------------------------------------
	bool hasEnded() const {
		return m_soldiersToSpawn <= 0;
	}
}

