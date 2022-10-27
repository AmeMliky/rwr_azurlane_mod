// internal
#include "tracker.as"
#include "log.as"
#include "helpers.as"

// helper tracker used to spawn enemies at specific location when the map starts
// --------------------------------------------
class Spawner : Tracker {
	protected Metagame@ m_metagame;
	protected bool m_started;
	protected int m_factionId;
	protected Vector3 m_position;
	protected int m_spawnCount;
	protected string m_soldierGroup;

	// --------------------------------------------
	Spawner(Metagame@ metagame, int factionId, const Vector3@ position, int count = 5, string soldierGroup = "default") {
		@m_metagame = @metagame;
		m_factionId = factionId;
		m_position = position;
		m_spawnCount = count;
		m_soldierGroup = soldierGroup;

		m_started = false;
	}

	// --------------------------------------------
	void gameContinuePreStart() {
		// on_game_continue_pre_start happens before start
		
		// it basically allows us to have trackers that are run only once in the beginning of a match, not at all when it is loaded into by continuing a savegame

		// the spawner tracker is certainly set up so that it fits, it only spawns extra troops at the start of a match

		// to skip processing start function which contains all the logic, we set the tracker started at this point already,
		// the metagame won't then call start at all
		m_started = true;
	}
	
	// --------------------------------------------
	void start() {
		_log("starting Spawner tracker", 1);

		// do the spawning
		for (int i = 0; i < m_spawnCount; ++i) {
			string command = "<command class='create_instance' faction_id='" + m_factionId + "' position='" + m_position.toString() + "' instance_class='character' instance_key='" + m_soldierGroup + "' />";
			m_metagame.getComms().send(command);
		}

		m_started = true;
	}

	// --------------------------------------------
	void onRemove() {
		// make start() called again if the tracker is added again, like for restart
		m_started = false;
	}

	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return m_started;
	}
}
