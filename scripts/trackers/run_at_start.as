// internal
#include "tracker.as"
#include "log.as"
#include "helpers.as"

// --------------------------------------------
class RunAtStart : Tracker {
	protected Metagame@ m_metagame;
	protected bool m_started;
	protected XmlElement@ m_command;

	// --------------------------------------------
	RunAtStart(Metagame@ metagame, const XmlElement@ command) {
		@m_metagame = @metagame;

		// copy
		@m_command = XmlElement(command.toDictionary());

		m_started = false;
	}

	// --------------------------------------------
	void gameContinuePreStart() {
		m_started = true;
	}
	
	// --------------------------------------------
	void start() {
		_log("starting RunAtStart tracker", 1);
		m_metagame.getComms().send(m_command);
		m_started = true;
	}

	// --------------------------------------------
	void onRemove() {
		// make start() called again if the tracker is added again, like for restart
		m_started = false;
	}

	// --------------------------------------------
	bool hasEnded() const {
		// ends instantly after having started
		return m_started;
	}

	// --------------------------------------------
	bool hasStarted() const {
		return m_started;
	}
}
