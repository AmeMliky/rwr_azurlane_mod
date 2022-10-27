#include "stage_configurator_campaign.as"

// ------------------------------------------------------------------------------------------------
class MyStageConfigurator : StageConfiguratorCampaign {
	// ------------------------------------------------------------------------------------------------
	MyStageConfigurator(GameModeInvasion@ metagame, MapRotatorCampaign@ mapRotator) {
		super(metagame, mapRotator);
	}

	// ------------------------------------------------------------------------------------------------
	const array<FactionConfig@>@ getAvailableFactionConfigs() const {
		array<FactionConfig@> availableFactionConfigs;

		// --------------------------------
		// TODO: define 3 faction configs here
		// - "green.xml" faction specification filename
		// - "Greenbelts" faction name, usually same as the one in the file
		// - "0.1 0.5 0" color used for faction in the world view
		// - "green_boss.xml" faction specification filename used in the final missions; 
		//   can be same as the regular faction filename
		// --------------------------------

		availableFactionConfigs.push_back(FactionConfig(-1, "Azur_Lane.xml", "Azur Lane", "0.0 0.59 1.0", "Azur_Lane.xml"));
		availableFactionConfigs.push_back(FactionConfig(-1, "META.xml", "META", "0.86 0.0 0.0", "META.xml"));
		availableFactionConfigs.push_back(FactionConfig(-1, "Siren.xml", "Brownpants", "0.62 0.33 0.75", "Siren.xml"));
		

		return availableFactionConfigs;
	}

	// NOTE
	// if you need to add certain resources for enemies or friendlies generally in all stages, have a look at
	// vanilla\scripts\gamemodes\invasion\stage_configurator_invasion.as and consider overriding
	// getCommonFactionResourceChanges
	// getFriendlyFactionResourceChanges
	// getCompletionVarianceCommands
}
