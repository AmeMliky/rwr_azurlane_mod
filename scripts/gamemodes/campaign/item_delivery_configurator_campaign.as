#include "item_delivery_configurator_invasion.as"

// ------------------------------------------------------------------------------------------------
class ItemDeliveryConfiguratorCampaign : ItemDeliveryConfiguratorInvasion {
	// ------------------------------------------------------------------------------------------------
	ItemDeliveryConfiguratorCampaign(GameModeInvasion@ metagame) {
		super(metagame);
	}

	// --------------------------------------------
	protected void processRewardPasses(array<array<ScoredResource@>>@ passes) {
		// campaign can use this to cleanup unavailable experimental resources in passes 
		array<string> experimental = {
			"emp_grenade.projectile", 
			"repair_crane_resource.weapon", 
			"gps_laptop.weapon"
		};
		for (uint i = 0; i < passes.size(); ++i) {
			for (uint j = 0; j < passes[i].size(); ++j) {
				ScoredResource@ r = passes[i][j];
				if (experimental.find(r.m_key) >= 0) {
					_log("removing experimental scored resource " + r.m_key);
					passes[i].removeAt(j);
					--j;
				}
			}
		}
	}
}
