#include "tracker.as"
#include "gamemode.as"
#include "helpers.as"
#include "time_announcer_task.as"

// --------------------------------------------
class Looper : Tracker {
	protected GameMode@ m_metagame;

	// --------------------------------------------
	Looper(GameMode@ metagame) {
		@m_metagame = @metagame;
	}
	
	// --------------------------------------------
	protected void handleMatchEndEvent(const XmlElement@ event) {
		// restart 
		m_metagame.getTaskSequencer().add(TimeAnnouncerTask(m_metagame, 20.0, true));
		m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.save)));
		m_metagame.getTaskSequencer().add(Call(CALL(m_metagame.requestRestart)));
	}
}
