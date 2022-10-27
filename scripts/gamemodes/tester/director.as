#include "tracker.as"
#include "metagame.as"

// --------------------------------------------
class Director : Tracker {
	protected Metagame@ m_metagame;
	protected float m_timer;
	protected bool m_enabled;

	// --------------------------------------------
	Director(Metagame@ metagame) {
		@m_metagame = @metagame;
		m_timer = 0.0f;
		m_enabled = false;
	}

	// --------------------------------------------
	bool hasStarted() const { return true; }

	// --------------------------------------------
	void resetCamera() {
		m_metagame.getComms().send("<command class='update_camera' reset='1' max_speed='4.0' slowing_distance='10.0' />");
	}

	// --------------------------------------------
	void updateCamera(string position, string lookAt) {
		m_metagame.getComms().send("<command class='update_camera' position='" + position + "' look_at='" + lookAt + "' />");
	}

	// --------------------------------------------
	bool justPassed(float updateTime, float targetTime) {
		return m_timer < targetTime && (m_timer + updateTime) >= targetTime;
	}

	// --------------------------------------------
	void update(float time) {
		if (!m_enabled) return;

		if (justPassed(time, 1.0f)) {
			updateCamera("512 10 512", "509 10 516");
			// snap to first position
			resetCamera();
		} else if (justPassed(time, 5.0f)) {
			updateCamera("505 10 512", "509 10 516");
		} else if (justPassed(time, 7.0f)) {
			updateCamera("500 10 512", "409 10 516");
		} else if (justPassed(time, 10.0f)) {
			updateCamera("490 10 512", "459 10 516");
			m_timer = 0.0f;
		}

		m_timer += time;
		//_log("time=" + m_timer);
	}

	// ----------------------------------------------------
	void setEnabled(bool state) {
		m_enabled = state;
		if (state) {
			m_timer = 0.0f;
		} 
		resetCamera();
	}

	// ----------------------------------------------------
	protected void handleChatEvent(const XmlElement@ event) {
		// player_id
		// player_name
		// message
		// global

		string message = event.getStringAttribute("message");
		// for the most part, chat events aren't commands, so check that first 
		if (!startsWith(message, "/")) {
			return;
		}

		string sender = event.getStringAttribute("player_name");
		int senderId = event.getIntAttribute("player_id");

		// admin only from here on
		if (!m_metagame.getAdminManager().isAdmin(sender, senderId)) {
			return;
		}

		// it's a silent server command, check which one
		if (checkCommand(message, "start")) {
			setEnabled(true);
		} else if (checkCommand(message, "stop")) {
			setEnabled(false);
		}
	}
}
