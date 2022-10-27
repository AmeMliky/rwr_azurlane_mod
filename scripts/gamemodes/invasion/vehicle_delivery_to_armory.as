// gamemode specific
#include "vehicle_delivery.as"

// --------------------------------------------
class VehicleDeliveryToArmory : VehicleDelivery {
	protected Tracker@ m_hintTracker;

	// ----------------------------------------------------
	VehicleDeliveryToArmory(GameModeInvasion@ metagame, string vehicleKey, int vehicleId, const VehicleDeliveryConfig@ config, bool doRemoveVehicle = false) {
		super(metagame, vehicleKey, vehicleId, config, doRemoveVehicle);
	}

	// ----------------------------------------------------
	void setupHitboxes() {
		// setup hitbox tracking

		// check that we have armories available to deliver the vehicle 
		array<const XmlElement@> armoryList = getArmoryHitboxes(m_metagame, m_config.m_factionId);
		// associate with hitboxes to get notification from game when the vehicle touches the hitbox
		associateHitboxes(armoryList);

		if (armoryList.size() == 0) {
			// stop hints? we can't complete the delivery as armories do not exist
			endHint();
		} else {
			if (m_hintTracker is null && m_config.m_hintConfig !is null) {
				// start hints if not started yet
				@m_hintTracker = VehicleHint(m_metagame, m_trackedVehicleId, m_config.m_hintConfig);
				m_metagame.addTracker(m_hintTracker);
			}
		}
	}

	// ----------------------------------------------------
	void clearHitboxes() {
		clearHitboxAssociations(m_metagame, "vehicle", m_trackedVehicleId, m_trackedHitboxes);
	}

	// ----------------------------------------------------
	protected void handleBaseOwnerChangeEvent(const XmlElement@ event) {
		// if already delivered, don't care
		if (m_deliveryDone) return;

		// get the list of all armories, the latest one
		// re-associate, will only add/remove the appropriate ones
		setupHitboxes();
	}

	// -------------------------------------------------------
	protected void associateHitboxes(const array<const XmlElement@>& list) {
		array<string> addIds;
		associateHitboxesEx(m_metagame, list, "vehicle", m_trackedVehicleId, m_trackedHitboxes, addIds);
	}

	// ----------------------------------------------------
	protected void setDeliveryCompleted() {
		VehicleDelivery::setDeliveryCompleted();

		// end hint tracker now to avoid it processing vehicle destroyed as an objective cancel trigger	
		endHint();
	}

    // ----------------------------------------------------
	protected void endHint() {
		if (m_hintTracker !is null)
		{
			m_hintTracker.end();
			@m_hintTracker = null;
		}
	}

    // ----------------------------------------------------
	void update(float time) {
		VehicleDelivery::update(time);

		if (m_hintTracker !is null && m_hintTracker.hasEnded()) {
			// forget it if it has been ended
			@m_hintTracker = null;
		}
	}

	// ----------------------------------------------------
	void end() {
		VehicleDelivery::end();

		endHint();
	}
}

