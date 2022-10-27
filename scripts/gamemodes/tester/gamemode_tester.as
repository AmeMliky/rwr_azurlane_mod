// internal
#include "metagame.as"
#include "log.as"

// generic trackers
#include "basic_command_handler.as"
#include "heal_on_kill.as"
#include "supporter_command_handler.as"

// --------------------------------------------
class GameModeTester : Metagame {
	// --------------------------------------------
	GameModeTester(const XmlElement@ settings) {
		super(settings.getStringAttribute("log_level"));
	}

	// --------------------------------------------
	void init() {
		Metagame::init();

		preBeginMatch();
		postBeginMatch();
	}

	// --------------------------------------------
	void postBeginMatch() {
		Metagame::postBeginMatch();

		addTracker(BasicCommandHandler(this));
		addTracker(HealOnKill(this, 0));
		addTracker(SupporterCommandHandler(this));

		XmlElement element(dictionary = {{"TagName", "command"},{"class", "chat"},{"text", "hello!"}});
		m_comms.send(element);

		const XmlElement@ player = getPlayerInfo(this, 0);
		if (player !is null) {
			string username = player.getStringAttribute("name");
			// add local player as admin for easy testing, hacks, etc
			if (!getAdminManager().isAdmin(username)) {
				getAdminManager().addAdmin(username);
			}
		}
	}
}
