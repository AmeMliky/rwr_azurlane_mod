// --------------------------------------------
class UserSettings {
	bool m_continue = false;

	string m_startServerCommand = "";

	string m_savegame = "";
	string m_username = "Single player";

	// --------------------------------------------
	void fromXmlElement(const XmlElement@ settings) {
		if (settings.hasAttribute("continue")) {
			m_continue = settings.getBoolAttribute("continue");
			// will load other settings from saved metagame data
		} else {
			m_savegame = settings.getStringAttribute("savegame");
			m_username = settings.getStringAttribute("username");
		}
	}

	// --------------------------------------------
	XmlElement@ toXmlElement(string name) const {
		// NOTE, won't serialize continue keyword, it only works as input

		XmlElement settings(name);

		settings.setStringAttribute("savegame", m_savegame);
		settings.setStringAttribute("username", m_username);

		return settings;
	}

	// --------------------------------------------
	void print() const {
		_log(" * using savegame name: " + m_savegame);
		_log(" * using username: " + m_username);
	}

};
