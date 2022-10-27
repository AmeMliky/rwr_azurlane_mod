// --------------------------------------------
class VehicleDeliveryConfig {
	array<string> m_vehicleKeys;
	int m_factionId;
	ResourceUnlocker@ m_unlocker;
	float m_rewardPerSeat;
	string m_customStatTag;
	const VehicleHintConfig@ m_hintConfig;
	float m_escortTotalReward;
	float m_fallbackRewardIfNothingToUnlock;

	// --------------------------------------------
	VehicleDeliveryConfig(const array<string>@ vehicleKeys, int factionId, float rewardPerSeat = 400.0, float escortTotalReward = -1.0, string customStatTag = "", ResourceUnlocker@ unlocker = null, const VehicleHintConfig@ hintConfig = null, float fallbackRewardIfNothingToUnlock = 0.0) {
		m_vehicleKeys = vehicleKeys; // copy
		m_factionId = factionId;
		m_rewardPerSeat = rewardPerSeat;
		@m_unlocker = @unlocker;
		m_customStatTag = customStatTag;
		@m_hintConfig = @hintConfig;
		m_escortTotalReward = escortTotalReward;
		m_fallbackRewardIfNothingToUnlock = fallbackRewardIfNothingToUnlock;
	}
}

