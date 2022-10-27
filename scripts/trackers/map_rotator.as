// internal
#include "tracker.as"
#include "log.as"

// --------------------------------------------
abstract class MapRotator : Tracker {
	// --------------------------------------------
	MapRotator() {
	}

	// --------------------------------------------
	void init() {
	}

	// --------------------------------------------
	void startRotation(bool beginOnly = false) {
		// pick first map, and change to it
		int index = getNextStageIndex();

		startMap(index, beginOnly);
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
	void save(XmlElement@ root) {
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
	}

	// --------------------------------------------
	void startMap(int index, bool beginOnly = false) {}
	void restartMap() {}

	// --------------------------------------------
	protected int getStageCount() const { return 0; }
	protected string getMapName(int index) const  { return "not set"; }
	protected const XmlElement@ getChangeMapCommand(int index) const { return XmlElement("not set"); }
	protected const XmlElement@ getStartGameCommand(int index) const { return XmlElement("not set"); }
	protected int getNextStageIndex() const { return 0; }
	protected void handleMatchEndEvent(const XmlElement@ element) {}

}
