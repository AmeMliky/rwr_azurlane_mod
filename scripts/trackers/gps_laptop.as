#include "tracker.as"
#include "helpers.as"
#include "admin_manager.as"
#include "log.as"
#include "query_helpers.as"
#include "query_helpers2.as"

//Author: Unit G17

class gpsTarget {
	string m_key;
	string m_name;
	
	gpsTarget(string key, string name){
		m_key = key;
		m_name = name;
	}
}

	// --------------------------------------------
class GpsLaptop : Tracker {
	protected Metagame@ m_metagame;
	protected array<int> m_markers;

	// --------------------------------------------
	GpsLaptop(Metagame@ metagame) {
		@m_metagame = @metagame;
		//_log("GpsLaptop");
	}

	// --------------------------------------------
	//to avoid major scripts (such as the a10 script) interfering with each other, this script is ran during the corresponding call
	protected void handleCallEvent(const XmlElement@ event) {
		//_log("handleCallEvent gps");
		//gps laptop call key
		string gpsKey = "gps.call";
			
		//checking if the event was triggered by the gps call
		string key = event.getStringAttribute("call_key");
		//checking which phase the call is at
		string phase = event.getStringAttribute("phase");
		
		if (key == gpsKey) {
			if (phase == "launch") {
				
				//list of vehicles that get marked on the map
				//getVehicles can't extract their names, so those were added separately
				array<gpsTarget@> gpsTargets = {
					gpsTarget("aa_emplacement.vehicle", "Anti-Air"),
					gpsTarget("cargo_truck.vehicle", "Cargo truck"),
					gpsTarget("prison_bus.vehicle", "Prisoner transport"),
					gpsTarget("prison_door.vehicle", "Prison door"),
					gpsTarget("prison_hatch.vehicle", "Prison hatch"),
					gpsTarget("radar_tower.vehicle", "Radar Tower"),
					gpsTarget("radar_truck.vehicle", "Comms truck"),
					gpsTarget("radio_jammer.vehicle", "Radio jammer"),
					gpsTarget("radio_jammer2.vehicle", "Radio jammer"),
					gpsTarget("icecream.vehicle", "Ice cream van"),
					gpsTarget("tank2.vehicle", "DarkCat"),
					gpsTarget("darkcat.vehicle", "DarkCat")
				};
				
				//scanning all major enemy factions (neutral wasn't necessary this time)
				bool anyFound = false;
				for (uint f = 1; f < 3; ++f){
					//scanning for all vehicles on the list
					for (uint i = 0; i < gpsTargets.length(); ++i){
						array<const XmlElement@>@ vehicles = getVehicles(m_metagame, f, gpsTargets[i].m_key);
						for (uint j = 0; j < vehicles.length(); ++j){
							const XmlElement@ vehicle = getVehicleInfo(m_metagame, vehicles[j].getIntAttribute("id"));
							if (vehicle !is null) {
								float health = vehicle.getFloatAttribute("health");
								if (health > 0.0) {
									int markerId = vehicles[j].getIntAttribute("id") + 7000;
									string position = vehicles[j].getStringAttribute("position");
									
									//collecting marker ids for removal later
									m_markers.insertLast(markerId);
									
									//placing the marker
									XmlElement command("command");
										command.setStringAttribute("class", "set_marker");
										command.setIntAttribute("id", markerId);
										command.setIntAttribute("faction_id", 0);
										command.setIntAttribute("atlas_index", 0);
										command.setFloatAttribute("size", 1.0);
										command.setFloatAttribute("range", 0.0);
										command.setIntAttribute("enabled", 1);
										command.setStringAttribute("position", position);
										command.setStringAttribute("text", gpsTargets[i].m_name);
										command.setStringAttribute("color", "#00b9ff");
										command.setBoolAttribute("show_in_map_view", true);
										command.setBoolAttribute("show_in_game_view", false);
										command.setBoolAttribute("show_at_screen_edge", false);
										
									m_metagame.getComms().send(command);
	
									if (!anyFound) {
										sendFactionMessageKey(m_metagame, 0, "gps_laptop, targets ok", dictionary = {}, 1.0);
										anyFound = true;
									}
								}
							}
						}
					}
				}
				if (!anyFound) {
					sendFactionMessageKey(m_metagame, 0, "gps_laptop, targets not ok", dictionary = {}, 1.0); 
				}
				
			} else if (phase == "end") {
				//duration is defined by the call
				for (uint i = 0; i < m_markers.length(); ++i){
					//removing the marker
					XmlElement command("command");
						command.setStringAttribute("class", "set_marker");
						command.setIntAttribute("id", m_markers[i]);
						command.setIntAttribute("enabled", 0);
						command.setIntAttribute("faction_id", 0);
					m_metagame.getComms().send(command);
				}
				//clearing the marker list
				m_markers.resize(0);
			}
		}
	}
}