// internal
#include "gamemode.as"
#include "tracker.as"
#include "log.as"

// --------------------------------------------
class AutoSaver : Tracker {
	protected GameMode@ m_metagame;

	protected float AUTOSAVE_TIME = 300.0;
	protected float m_timer;

	// --------------------------------------------
	AutoSaver(GameMode@ metagame) {
		@m_metagame = @metagame;

		m_timer = AUTOSAVE_TIME;
	}
	
	// --------------------------------------------
	void update(float time) {
		m_timer -= time;
		if (m_timer < 0.0) {
			_log("autosaving", 1);
			m_metagame.save();
			m_timer = AUTOSAVE_TIME;
		}
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

}

