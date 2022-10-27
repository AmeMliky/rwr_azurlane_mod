#include "tracker.as"
#include "helpers.as"

// --------------------------------------------
class PhaseController : Tracker {
	void phaseEnded() {}
	void gameContinuePreStart() {}
	void load(const XmlElement@ root) {}
	void save(XmlElement@ root) {}
}
