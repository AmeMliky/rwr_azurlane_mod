#include "item_delivery_objective.as"
#include "query_helpers.as"

// ------------------------------------------------------------------------------------------------
class GiftItemDeliveryRewarder : ItemDeliveryRewarder {
	protected Metagame@ m_metagame;
	protected array<Resource@> m_rewardItems;

	// ----------------------------------------------------
	GiftItemDeliveryRewarder(Metagame@ metagame, const array<Resource@>@ rewardItems) {
		@m_metagame = @metagame;
		m_rewardItems = rewardItems;
	}

	// ------------------------------------------------------------------------------------------------
	void rewardCompletion(int playerId, int characterId, const Resource@ targetItem) {
		for (uint i = 0; i < m_rewardItems.size(); ++i) {
			Resource@ r = m_rewardItems[i];
			addItemInBackpack(m_metagame, characterId, r);
		}
	}

	// ------------------------------------------------------------------------------------------------
	void rewardPiece(int playerId, int characterId, int acceptedAmount, const Resource@ targetItem) {
	}
}

// ------------------------------------------------------------------------------------------------
class ScoredResource : Resource {
	float m_score;
	int m_amount;

	// ------------------------------------------------------------------------------------------------
	ScoredResource(string key, string type, float score, int amount = 1) {
		super(key, type);
		m_score = score;
		m_amount = amount;
	}
};

// ------------------------------------------------------------------------------------------------
void normalizeScoredResources(array<ScoredResource@>@ resources) {
	float sum = 0.0f;
	for (uint j = 0; j < resources.size(); ++j) {
		ScoredResource@ r = resources[j];
		sum += r.m_score;
	}

	for (uint j = 0; j < resources.size(); ++j) {
		ScoredResource@ r = resources[j];
		r.m_score = r.m_score / sum;
	}
}

// ------------------------------------------------------------------------------------------------
ScoredResource@ getRandomScoredResource(array<ScoredResource@>@ resources) {
	float p = rand(0.0f, 1.0f);
	float current = 0.0f;
	for (uint j = 0; j < resources.size(); ++j) {
		ScoredResource@ r = resources[j];
		current += r.m_score;
		if (p < current) {
			return r;
		}
	}
	return resources[resources.size() - 1];
}


// ------------------------------------------------------------------------------------------------
class GiftItemDeliveryRandomRewarder : ItemDeliveryRewarder {
	protected Metagame@ m_metagame;
	protected array<array<ScoredResource@>> m_rewardItemPasses;

	// ----------------------------------------------------
	GiftItemDeliveryRandomRewarder(Metagame@ metagame, const array<array<ScoredResource@>>@ rewardItemPasses) {
		@m_metagame = @metagame;
		m_rewardItemPasses = rewardItemPasses;
		
		// normalize scores now
		for (uint i = 0; i < m_rewardItemPasses.size(); ++i) {
			array<ScoredResource@>@ rewardItems = @m_rewardItemPasses[i];
			normalizeScoredResources(rewardItems);
		}
	}

	// ------------------------------------------------------------------------------------------------
	void rewardCompletion(int playerId, int characterId, const Resource@ targetItem) {
		if (playerId >= 0) {
			string playerName = "";
			const XmlElement@ player = getPlayerInfo(m_metagame, playerId);
			if (player !is null) {
				playerName = player.getStringAttribute("name");

				dictionary a;
				a["%player_name"] = playerName;
				a["%delivered_item_name"] = getResourceName(m_metagame, targetItem.m_key, targetItem.m_type);

				//sendFactionMessageKey(m_metagame, 0, "gift box delivered", a);
				sendPrivateMessageKey(m_metagame, playerId, "gift box delivered", a);
			}
		}

		TaskSequencer@ tasker = m_metagame.getTaskManager().newTaskSequencer(); 
		tasker.add(DelayedCallTask(CallIntInt(CALL_INT_INT(this.doDelayedReward), playerId, characterId), 3.0));
	}

	// ------------------------------------------------------------------------------------------------
	void doDelayedReward(int playerId, int characterId) {

		if (playerId >= 0) {
			const XmlElement@ player = getPlayerInfo(m_metagame, playerId);
			if (player !is null) {
				dictionary a;
				a["%player_name"] = player.getStringAttribute("name");

				for (uint i = 0; i < m_rewardItemPasses.size(); ++i) {
					array<ScoredResource@>@ rewardItems = @m_rewardItemPasses[i];

					ScoredResource@ r = getRandomScoredResource(rewardItems);
					for (int k = 0; k < r.m_amount; ++k) {
						addItemInBackpack(m_metagame, characterId, r);
					}

					string name = getResourceName(m_metagame, r.m_key, r.m_type);
					a["%item_name" + formatInt(i+1)] = name;
				}

				//sendFactionMessageKey(m_metagame, 0, "gift box delivery, reward", a);
				sendPrivateMessageKey(m_metagame, playerId, "gift box delivery, reward", a);
			} else {
				// no such player, break
				return;
			}
		}
	}

	// ------------------------------------------------------------------------------------------------
	void rewardPiece(int playerId, int characterId, int acceptedAmount, const Resource@ targetItem) {
	}

}
