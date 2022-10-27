#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "query_helpers2.as"

//Author: Unit G17

	// --------------------------------------------
class SquadEquipmentKit : Tracker {
	protected Metagame@ m_metagame;

	// --------------------------------------------
	SquadEquipmentKit(Metagame@ metagame) {
		@m_metagame = @metagame;
	}

	// --------------------------------------------
	protected void handleItemDropEvent(const XmlElement@ event) {
		//squad equipment kit key
		string key = "squad_equipment_kit.weapon";

		string itemKey = event.getStringAttribute("item_key");
		int containerId = event.getIntAttribute("target_container_type_id");
		if (key == itemKey && containerId == 2) {
			int characterId = event.getIntAttribute("character_id");
			//Announcing item description when equipping the kit
			sendFactionMessageKeySaidAsCharacter(m_metagame, 0, characterId, "squad_equipment_kit, equip");
			//m_metagame.getComms().send("<command class='chat' text='I can use this to equip nearby soldiers with vests!' said_as_character_id='" + characterId + "' priority='1.0' />");
		}
	}

	// --------------------------------------------
	protected void handleResultEvent(const XmlElement@ event) {
		//squad equipment kit notify_script key
		string key = "squad_equipment_kit";
		
		//checking if the event was triggered by a squad equipment kit
		string eventKey = event.getStringAttribute("key");
		if (key == eventKey) {
			//deploying character's id
			int characterId = event.getIntAttribute("character_id");
			
			//announcing deployment
			sendFactionMessageKeySaidAsCharacter(m_metagame, 0, characterId, "squad_equipment_kit, done");
			//m_metagame.getComms().send("<command class='chat' text='Vests handed out!' said_as_character_id='" + characterId + "' priority='1.0' />");
		
			//maximum number of soldiers that may receive equipment
			int max_soldier_count = 10;
			//effect radius
			float range = 30.0;
		
			//list of soldier classes that may be affected
			array<string> targetKeys = {
				"default",
				"default_ai",
				"medic",
				"sniper"
			};
			
			//list of costumes that may be found in faulty kits
			array<string> vestKeys = {
				"costume_banana.carry_item",
				"costume_butcher.carry_item",
				"costume_clown.carry_item",
				"costume_lizard.carry_item",
				"costume_santa.carry_item",
				"costume_underpants.carry_item",
				"costume_werewolf.carry_item"
			};
			
			//extracting the faction id of the soldier that deployed the kit
			const XmlElement@ character = getCharacterInfo(m_metagame, characterId);
			if (character !is null) {
				int factionId = character.getIntAttribute("faction_id");
				
				//extracting the position of said soldier
				Vector3 position = stringToVector3(event.getStringAttribute("position"));

				//collecting all nearby soldiers
				array<const XmlElement@>@ characters = getCharactersNearPosition(m_metagame, position, factionId, range);
				
				//counting the number of soldiers that have received new vests so far
				int soldier_count = 0;
				
				//total number of nearby soldiers
				uint total_soldier_count = characters.length();
				
				//running script for nearby soldiers
				for (uint i = 0; i < total_soldier_count; ++i) {
					//randomizing selection
					int k = rand(0, characters.length() - 1);
				
					//extracting character id
					int soldierId = characters[k].getIntAttribute("id");
					
					//modified getCharacterInfo, includes equipment
					const XmlElement@ characterInfo = getCharacterInfo2(m_metagame, soldierId);
					
					//checking if they are from a valid soldier class
					string soldierClass = characterInfo.getStringAttribute("soldier_group_name");
					
					//checking if they have enough experience
					float soldierXp = characterInfo.getFloatAttribute("xp");
					
					if (targetKeys.find(soldierClass) != -1 && soldierXp >= 0.1) {
						//determining if they wear any vest currently
						array<const XmlElement@>@ equipment = characterInfo.getElementsByTagName("item");
						if (equipment.size() > 0) {
							int vestAmount = equipment[4].getIntAttribute("amount");
							string vestKey = equipment[4].getStringAttribute("key");
							
							//they get a new vest only if they have none or the one they wear is damaged
							if (vestAmount == 0 || (vestAmount == 1 && (vestKey == "vest2_2" || vestKey == "vest2_3" || vestKey == "vest1.carry_item" || vestKey == "vest1_2"))) {
								string newVest = "vest2.carry_item";
								
								//1% chance that they receive a costume instead of a vest, faulty kit contents happen :)
								int r = rand(1, 100);						
								if (r == 1) {
									r = rand(0, vestKeys.length() - 1);
									newVest = vestKeys[r];
								}

								//equipping them with the new vest
								XmlElement c("command");
								c.setStringAttribute("class", "update_inventory");

								c.setIntAttribute("character_id", soldierId); 
								c.setIntAttribute("container_type_id", 4);
								{
									XmlElement j("item");
									j.setStringAttribute("class", "carry_item");
									j.setStringAttribute("key", newVest);
									c.appendChild(j);
								}
								m_metagame.getComms().send(c);
								
								//checking how many soldiers have received a new vest so far
								soldier_count++;
								if (soldier_count >= max_soldier_count) {
									break;
								}
							}
						}
					}
					
					//removing the selected soldier from the list
					characters.removeAt(k);
				}
			}
		}
    }
}