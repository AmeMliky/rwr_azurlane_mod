// gamemode specific
#include "vehicle_delivery.as"

// --------------------------------------------
class VehicleDeliveryToSpecificTarget : VehicleDelivery {
	protected string m_targetHitbox = "";

	// ----------------------------------------------------
	VehicleDeliveryToSpecificTarget(GameModeInvasion@ metagame, string vehicleKey, int vehicleId, string targetHitbox, const VehicleDeliveryConfig@ config, bool doRemoveVehicle = false) {
		super(m_metagame, vehicleKey, vehicleId, config, doRemoveVehicle);

		m_targetHitbox = targetHitbox;
	}

	// ----------------------------------------------------
	void setupHitboxes() {
		// setup hitbox tracking
		string instanceType = "vehicle";

		string command = "<command class='add_hitbox_check' id='" + m_targetHitbox + "' instance_type='" + instanceType + "' instance_id='" + m_trackedVehicleId + "' />";
		m_metagame.getComms().send(command);
	}

	// ----------------------------------------------------
	void clearHitboxes() {
		string instanceType = "vehicle";

		string command = "<command class='remove_hitbox_check' id='" + m_targetHitbox + "' instance_type='" + instanceType + "' instance_id='" + m_trackedVehicleId + "' />";
		m_metagame.getComms().send(command);
	}
}
