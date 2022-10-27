// internal
#include "tracker.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"

// gamemode specific
#include "vehicle_delivery_config.as"
#include "escort_reward_handler.as"

// --------------------------------------------
namespace VehicleDeliveries {
	const float REWARD_TRACKING_TIME = 10.0;
};

// --------------------------------------------
abstract class VehicleDelivery : Tracker {
	// TODO: Generalize GameModeInvasion to another class here
	// - VehicleHint needs it, so it's here too
	protected GameModeInvasion@ m_metagame;
	protected const VehicleDeliveryConfig@ m_config;
	protected int m_trackedVehicleId;
	protected string m_vehicleKey;
	protected bool m_deliveryDone;
	protected array<string> m_trackedHitboxes;
	protected bool m_doRemoveVehicle;
	protected EscortRewardHandler@ m_escortHandler;

	// ----------------------------------------------------
	VehicleDelivery(GameModeInvasion@ metagame, string vehicleKey, int vehicleId, const VehicleDeliveryConfig@ config, bool doRemoveVehicle = false) {
		_log("creating VehicleDelivery, " + vehicleKey + ", id=" + vehicleId, 1);
		@m_metagame = @metagame;
		@m_config = @config;
		m_trackedVehicleId = vehicleId;
		m_vehicleKey = vehicleKey;
		m_deliveryDone = false;
		m_doRemoveVehicle = doRemoveVehicle;

		if (m_config.m_escortTotalReward > 0.0) {
			@m_escortHandler = EscortRewardHandler(m_metagame, m_trackedVehicleId, m_config.m_factionId, m_config.m_escortTotalReward);
		}
	}

	// ----------------------------------------------------
	void setupHitboxes() {}

	// ----------------------------------------------------
	void clearHitboxes() {}

    // ----------------------------------------------------
	void update(float time) {
		if (m_escortHandler !is null) {
			m_escortHandler.update(time);
		}
	}

	// ----------------------------------------------------
	bool hasStarted() const {
		return true;
	}

	// ----------------------------------------------------
	bool hasEnded() const {
		return m_trackedVehicleId == -1;
	}

	// ----------------------------------------------------
	protected void handleVehicleDestroyEvent(const XmlElement@ event) {
		if (event.getIntAttribute("vehicle_id") == m_trackedVehicleId) {
			// vehicle was destroyed, stop this tracker
			end();
		}
	}

	// ----------------------------------------------------
	void end() {
		clearHitboxes();

		m_trackedVehicleId = -1;
		m_deliveryDone = false;
	}

	// receive hitbox event, make the unlock happen, stop the tracker
	// ----------------------------------------------------
	protected void handleHitboxEvent(const XmlElement@ event) {
		// if already delivered, skip
		if (m_deliveryDone) {
			//_log("WARNING, delivery done already, still receiving hitbox events?", 1);
			return;
		}

		if (event.getStringAttribute("instance_type") == "vehicle" &&
			event.getIntAttribute("instance_id") == m_trackedVehicleId) {

			// this event concerns our vehicle

			// done, clear hitbox tracking
			clearHitboxes();

			// who to reward?
			// everyone in the car?
			// just the driver?
			const XmlElement@ vehicleInfo = getVehicleInfo(m_metagame, m_trackedVehicleId);
			if (vehicleInfo !is null) {
				array<const XmlElement@> characterList = vehicleInfo.getElementsByTagName("character");
				int driverId = -1;
				for (uint i = 0; i < characterList.size(); ++i) {
					const XmlElement@ character = characterList[i];
					int slotType = character.getIntAttribute("slot_type");
					// driver, 0
					if (slotType == 0) {
						int id = character.getIntAttribute("id");
						if (id >= 0) {
							driverId = id;
							if (m_config.m_rewardPerSeat > 0.0) {
								string c = "<command class='rp_reward' character_id='" + id + "' reward='" + m_config.m_rewardPerSeat + "' />";
								m_metagame.getComms().send(c);
							}

							// this can also involve completing a tracked stat in achievements
							if (m_config.m_customStatTag != "") {
								string c = "<command class='add_custom_stat' character_id='" + id + "' tag='" + m_config.m_customStatTag + "' />";
								m_metagame.getComms().send(c);
							}
						}
					}
				}

				if (m_escortHandler !is null) {
					m_escortHandler.doReward();
				}

				dictionary a = {
					{"%vehicle_name", vehicleInfo.getStringAttribute("name")}
				}; 
				sendFactionMessageKey(m_metagame, 0, "vehicle delivered", a);

				playObjectiveCompleteSound(m_metagame, 0);

				// lock vehicle, pushes everyone out from it denying access
				lockVehicle(m_metagame, m_trackedVehicleId);

				// remove vehicle -- would be nicer if this would happen after a while only
				if (m_doRemoveVehicle) {
					removeVehicle(m_metagame, m_trackedVehicleId);
				} else {
					destroyVehicle(m_metagame, m_trackedVehicleId);
				}

				// reward with an unlock, if possible
				if (m_config.m_unlocker !is null) {
					Resource resource(m_vehicleKey, "vehicle");
					if (!m_config.m_unlocker.handleItemDeliveryCompleted(resource) &&
						m_config.m_fallbackRewardIfNothingToUnlock > 0.0) {
						// nothing to unlock anymore
						if (driverId >= 0) {
							string c = "<command class='rp_reward' character_id='" + driverId + "' reward='" + m_config.m_fallbackRewardIfNothingToUnlock + "' />";
							m_metagame.getComms().send(c);
						}
					}
				}
				setDeliveryCompleted();
			}
		}
	}

	// ----------------------------------------------------
	protected void setDeliveryCompleted() {
		m_deliveryDone = true;
	}

	/*
    // ----------------------------------------------------
	// debugging tools
    protected function handle_chat_event($doc) {
		// player_id
		// player_name
		// message
		// global
		$event = $doc->firstChild;

		$message = $event->getAttribute("message");
		// for the most part, chat events aren't commands, so check that first
		if (!starts_with($message, "/")) {
				return;
		}

		$sender = $event->getAttribute("player_name");
		$sender_id = $event->getAttribute("player_id");
		if (check_command($message, "help")) {
			// don't process if not properly started
			if ($this->is_tracking()) {
				$this->instruct_objective($sender_id);
			}
		}

		if (!is_admin($sender, $sender_id)) {
			return;
		}

        if (check_command($message, "reset")) {
            $this->metagame->comms->send("say reseting objective");

			$this->end();
			$this->reset();

			$this->wait_for_try_again_timer = 0;
		}
	}
*/
}

