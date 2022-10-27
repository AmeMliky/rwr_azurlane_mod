#include "gamemode.as"
#include "user_settings_simple.as"
#include "log.as"
#include "basic_command_handler.as"
#include "looper.as"

// --------------------------------------------
class GameModeSimple : GameMode {
	protected UserSettings@ m_userSettings;

	// --------------------------------------------
	GameModeSimple(UserSettings@ settings) {
		super(settings.m_startServerCommand);
		@m_userSettings = @settings;
	}

	// --------------------------------------------
	void init() {
		GameMode::init();

		if (m_userSettings.m_continue) {
			// the game has now loaded its own state; the map, the match, the situation,
			// load the metagame level state
			load();

			preBeginMatch();
			postBeginMatch();

		} else {
			// start without loading a previous game, or loop back to beginning

			// change the map 
			changeMap();

			// wait for map to change
			sync();

			preBeginMatch();

			startMatch();

			postBeginMatch();
		}

		// add local player as admin for easy testing, hacks, etc
		if (!getAdminManager().isAdmin(getUserSettings().m_username)) {
			getAdminManager().addAdmin(getUserSettings().m_username);
		}
	}

	// --------------------------------------------
	void uninit() {
		save();
		GameMode::uninit();
	}

	// --------------------------------------------
	protected void changeMap() {
		// TODO: derive and implement
	}

	// --------------------------------------------
	protected void startMatch() {
		// TODO: derive and implement
	}

	// --------------------------------------------
	void postBeginMatch() {
		GameMode::postBeginMatch();

		addTracker(BasicCommandHandler(this));
		addTracker(Looper(this));
	}

	// --------------------------------------------
	const UserSettings@ getUserSettings() const {
		return m_userSettings;
	}

	// --------------------------------------------
	void save() {
		_log("saving metagame", 1);

		XmlElement commandRoot("command");
		commandRoot.setStringAttribute("class", "save_data");

		XmlElement root("saved_metagame");
		XmlElement@ settings = m_userSettings.toXmlElement("settings");
		root.appendChild(settings);

		commandRoot.appendChild(root);
		getComms().send(commandRoot);
	}

	// --------------------------------------------
	void load() {
		_log("loading metagame", 1);

		XmlElement@ query = XmlElement(
			makeQuery(this, array<dictionary> = {
				dictionary = { {"TagName", "data"}, {"class", "saved_data"} } }));
		const XmlElement@ doc = getComms().query(query);

		if (doc !is null) {
			const XmlElement@ root = doc.getFirstChild();
			const XmlElement@ settings = root.getFirstElementByTagName("settings");
			if (settings !is null) {
				m_userSettings.fromXmlElement(settings);
				// set continue false now, so that complete restart (::init)
				// will properly execute start rather than load
				m_userSettings.m_continue = false;
			}

			m_userSettings.print();

			_log("loaded", 1);
		} else {
			_log("load failed");
		}
	}

	// --------------------------------------------
	protected void sync() {
		XmlElement@ query = XmlElement(makeQuery(this, array<dictionary> = {}));
		const XmlElement@ doc = getComms().query(query);
		getComms().clearQueue();
		resetTimer();
	}
}
