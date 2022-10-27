#include "gamemode_invasion.as"
#include "vehicle_delivery_configurator.as"

// ------------------------------------------------------------------------------------------------
class VehicleDeliveryConfiguratorInvasion : VehicleDeliveryConfigurator {
	protected GameModeInvasion@ m_metagame;

	// ------------------------------------------------------------------------------------------------
	VehicleDeliveryConfiguratorInvasion(GameModeInvasion@ metagame) {
		@m_metagame = @metagame;
	}

	// ------------------------------------------------------------------------------------------------
	void setup() {
		// add a vehicle theft objective in the list of trackers
		// the objective works so that it'll try to start itself
		// (it might not be able to, as there might not be a suitable vehicle for theft)
		for (uint i = 0; i < m_metagame.getFactions().size(); ++i) {
			// player faction is always first in factions list
			if (i == 0) continue;

			_log("adding vehicle escort objective", 2);

			string target = "cargo_truck.vehicle";
			dictionary unlockList;
			array<Resource@>@ list = getUnlockItemList();
			unlockList.set(target, @list);
			ResourceUnlocker unlocker(m_metagame, 0, unlockList, m_metagame);

			VehicleHintConfig hintConfig(target, "vehicle objective instruction", "vehicle objective cancelled, vehicle destroyed", 0);

			array<string> targets = {target};
			// 400=fallback reward if nothing to unlock
			VehicleDeliveryConfig config(targets, 0, 0.0, 800.0, "", unlocker, hintConfig, 400.0);

			m_metagame.addTracker(VehicleDeliveryToArmoryManager(m_metagame, config, i));
		}
	}

	// --------------------------------------------
	protected array<Resource@>@ getUnlockItemList() const {
		array<Resource@> list;

		list.push_back(Resource("l85a2.weapon", "weapon"));
		list.push_back(Resource("famasg1.weapon", "weapon"));
		list.push_back(Resource("sg552.weapon", "weapon"));
		list.push_back(Resource("m79.weapon", "weapon"));
		list.push_back(Resource("minig_resource.weapon", "weapon"));
		list.push_back(Resource("desert_eagle.weapon", "weapon"));
		list.push_back(Resource("tow_resource.weapon", "weapon"));
		list.push_back(Resource("apr.weapon", "weapon"));    
   		list.push_back(Resource("eodvest.carry_item", "carry_item"));
		list.push_back(Resource("hornet_resource.weapon", "weapon"));              
         
		return list;
	}
}

