#include "tracker.as"
#include "helpers.as"
#include "log.as"
#include "query_helpers.as"
#include "query_helpers2.as"

/*
Credits:
originally adapted by Xe-No from a10_gun_run.as
heavily modified and upgraded by Unit G17
*/

//when an AC130 gun run is requested the caller's character and faction id and the call's position are stored
class AC130Request {
	int m_callId;
	int m_characterId;
	Vector3 m_targetPos;
	int m_factionId;
	float m_timer;
	int m_bursts;
	bool m_runGun = false;
	
	AC130Request(int callId, int characterId, Vector3 targetPos, int factionId, float timer, int bursts) {
		m_callId = callId;
		m_characterId = characterId;
		m_targetPos = targetPos;
		m_factionId = factionId;
		m_timer = timer;
		m_bursts = bursts;
	}
}

class AC130GunRun : Tracker {
  protected Metagame@ m_metagame;
  protected bool m_running = false; //the update function is only running when there are calls in queue
  protected array<AC130Request@> AC130Queue; //AC-130 requests are stored here
  protected float m_pi = acos(-1.0f); //pi constant
  protected float m_arrivalTime = 6.0; //synchronize with particle animation time
  protected float m_circleTime = 10.0; //synchronize with particle animation time
  protected float m_circleCount = 2.0; //number of loops the plane takes
  protected int m_burstCount = 48; //number of times the plane fires
  protected float m_cooldown = m_circleTime / m_burstCount; //delay between bursts
  protected int m_hmg_rounds = 3; //number of hmg rounds the plane fires during a single burst
  protected float m_radius = 68.0; //scanning range for enemies
  protected float m_delayTime = 0.017; //this value is based on the minimum sleep time between commands (pasik), testing confirms it's accurate
  //I attempted to tie the delay between each shots to the update() function, but it resulted in a slow and very inconsistent firerate
  protected array<string> vehicleExceptionKeys = { "cargo_truck.vehicle" }; //list of vehicles we don't want the AC-130 to shoot at with the howitzer
  //受保护的bool m_running=false//只有在队列中有调用时，更新功能才会运行

//受保护阵列<AC130Request@>AC130队列//AC-130请求存储在这里

//受保护浮点数m_pi=acos（-1.0f）//π常数

//受保护浮动m_到达时间=6.0//与粒子动画时间同步

//受保护浮点数 m_circleTime=20.0//与粒子动画时间同步

//受保护浮点数 m_circleCount=1.0//飞机的循环次数

//受保护整数 m_burstCount=8//飞机开火的次数

//受保护浮动m_冷却时间=m_循环时间/m_负荷计数//脉冲之间的延迟

//受保护的整数m_hmg_轮=30//在一次爆炸中，hmg向飞机发射的子弹数

//保护浮子m_半径=35.0//扫描敌人的射程

//受保护浮动m_延迟时间=0.017//该值基于命令之间的最小睡眠时间（pasik），测试证实其准确

//我试图将每次放炮之间的延迟与update（）函数联系起来，但它导致了缓慢且非常不一致的燃烧速率

//受保护数组<string>VehicleeExceptionKeys={“cargo_truck.vehicle”}//我们不希望AC-130用榴弹炮射击的车辆清单
  AC130GunRun(Metagame@ metagame) {
    @m_metagame = @metagame;
  }

  protected void handleCallEvent(const XmlElement@ event) {
    // Hey we got a call!

    // Check call key
    if (event.getStringAttribute("call_key") == "zhihuijian_0.call" || event.getStringAttribute("call_key") == "zhihuijian_1.call") {
		string phase = event.getStringAttribute("phase");
		
		int callId = event.getIntAttribute("id");
		
		//during the request all necessary information gets stored about the call
		if (phase == "queue") {
			int characterId = event.getIntAttribute("character_id");
			int factionId = event.getIntAttribute("faction_id");
			Vector3 targetPos = stringToVector3(event.getStringAttribute("target_position"));

			//creating a new request with the given data
			AC130Request@ thisCall = AC130Request(callId, characterId, targetPos, factionId, m_arrivalTime + m_circleTime, m_burstCount);
			
			//the queue is necessary to handle multiple simultaneous AC130 requests
			AC130Queue.insertLast(thisCall);
		}

		//starting the timer and thus starting the fireworks :)
		if (phase == "launch") {
			//finding the launched call
			for (uint i = 0; i < AC130Queue.length() ; ++i){
				if (AC130Queue[i].m_callId == callId){
					//starting update function (if it's not running already)
					m_running = true;
					//starting the timer of the launched call
					AC130Queue[i].m_runGun = true;
					break;
				}
			}
		}
    }
  }
  
	// --------------------------------------------
	void update(float time) {
		
		//checking all calls
		for (uint i = 0; i < AC130Queue.length() ; ++i){
			//if the call is running, then reduce it's timer variable
			if (AC130Queue[i].m_runGun == true){
				AC130Queue[i].m_timer -= time;
				
				//if it's time to fire, then scanning for targets
				if (AC130Queue[i].m_timer < (AC130Queue[i].m_bursts * m_cooldown)){
					string fireTarget = "empty";
					
					//scanning for vehicles in every odd numbered firing round (note that m_bursts counts backwards to 0)
					if (AC130Queue[i].m_bursts % 2 == 1){
						fireTarget = getVehicleTarget(AC130Queue[i], m_radius);
						
						//fireTarget = (AC130Queue[i].m_targetPos).toString(); //testing shots
						
						if (fireTarget != "empty"){
							
							fireProjectiles(AC130Queue[i], fireTarget, "gunship_40mm.projectile", "ac130_autocannon_burst.wav", 5.0, 1, 0.3, 0, 1.4);
							fireProjectiles(AC130Queue[i], fireTarget, "gunship_105mm.projectile", "ac130_cannon_shot.wav", 3.0, 1, 0.0, 4 * m_delayTime);
							//note that the 105mm's offset value accounts for the 40mm's fireProjectiles duration
						}
					}
					//if no vehicles were found (or if they weren't scanned for at all), then the gunship scans for infantry targets
					if (fireTarget == "empty"){
						fireTarget = getInfantryTarget(AC130Queue[i], m_radius);
						
						//fireTarget = (AC130Queue[i].m_targetPos).toString(); //testing shots
						
						//if a target is found, then firing
						if (fireTarget != "no_target"){
							fireProjectiles(AC130Queue[i], fireTarget, "gunship_105mm.projectile", "ac130_hmg_burst.wav", 3.0, 1, 0.0,1.4 );
							fireProjectiles(AC130Queue[i], fireTarget, "gunship_25mm.projectile", "ac130_hmg_burst.wav", 5.0, m_hmg_rounds, 0.032, 0);
							fireProjectiles(AC130Queue[i], fireTarget, "gunship_40mm.projectile", "ac130_autocannon_burst.wav", 3.0, 1, 0.3, (m_hmg_rounds + 1) * m_delayTime, 1.4);
							//note that the 40mm's offset value accounts for the 25mm's fireProjectiles duration
						}
					}
					//reducing number of remaining burst
					AC130Queue[i].m_bursts--;
					//if none remaining, the removing the request from the queue
					if (AC130Queue[i].m_bursts == 0){
						AC130Queue.removeAt(i);
						--i;
					}
				}
			}
		}
		//if the queue is empty, then stopping the update function
		if (AC130Queue.length() == 0) m_running = false;
	}

	Vector3 gunRunVector(float direction) {
		//recalculating the 3d vector from the direction data
		//this function has been modified to use m_timer value of a request, which can translate to the current position of the plane
		float angle = (direction / m_circleTime) * m_pi * 2 * m_circleCount;
				
		Vector3 attackVector = Vector3(-sin(angle), 0, cos(angle));
				
		return attackVector;
	}

	array<int> indexRandomizer(uint arrayLength, int excludeIndex) {
		//this function randomizes a simple sequential array, then returns the randomized array
		array<int> baseArray;
		for (uint i = 0; i < arrayLength; ++i){
			baseArray.insertLast(i);
		}
		
		array<int> randomizedArray;
		for (uint i = 0; i < arrayLength; ++i){
			int r = rand(0, baseArray.length() - 1);

			//excluding can be used to remove our own faction id from the array
			if (baseArray[r] != excludeIndex){
				randomizedArray.insertLast(baseArray[r]);
			}
			baseArray.removeAt(r);
		}
		
		return randomizedArray;
	}
	
	string getInfantryTarget(AC130Request@ AC130Request, float range) {
		//extracting data
		int factionId = AC130Request.m_factionId;
		Vector3 targetPos = AC130Request.m_targetPos;
		
		//randomizing faction order, so that the AC130 won't always prioritize targeting one faction over an another
		array<int> fRandomized = indexRandomizer(4, factionId);
	
		//scanning for a target
		for (uint f = 0; f < 3; ++f){
			//custom query, collects all soldiers of a faction near target position
			array<const XmlElement@>@ soldiers = getCharactersNearPosition(m_metagame, targetPos, fRandomized[f], range);				
			int s_size = soldiers.length();
			
			//if no target is found, then move on to the next faction
			if (s_size == 0) continue;
			
			//randomly selecting a soldier
			int s_i = rand(0,soldiers.length()-1);
			int soldier_id = soldiers[s_i].getIntAttribute("id");

			//extracting the targeted soldier's position
			const XmlElement@ character = getCharacterInfo(m_metagame, soldier_id);
			if (character !is null) {
				string soldierPos = character.getStringAttribute("position");
				return soldierPos;
			}
		}
		
		//if no valid target is found at all, then we return this message
		return "no_target";
	}
	
	string getVehicleTarget(AC130Request@ AC130Request, float range) {
		//extracting data
		int factionId = AC130Request.m_factionId;
		Vector3 targetPos = AC130Request.m_targetPos;

		//randomizing faction order, so that the AC130 won't always prioritize targeting one faction over an another
		//we have to check our own vehicles too, cuz the enemy may have stolen it
		array<int> fRandomized = indexRandomizer(4, -1);
	
		//scanning for a target
		for (uint f = 0; f < 4; ++f){
			//custom query, collects all vehicles of a faction
			array<const XmlElement@>@ vehicles = getAllVehicles(m_metagame, fRandomized[f]);
			int v_size = vehicles.length();
			
			//if no vehicle is found, then move on to the next faction
			if (v_size == 0) continue;
			
			//randomizing vehicle scanning order, so the plane wouldn't always fire on the same vehicle if multiple valid targets are in the area
			array<int> vRandomized = indexRandomizer(v_size, -1);
						
			for (int i = 0; i < v_size; ++i) {
				Vector3 vehiclePos = stringToVector3(vehicles[vRandomized[i]].getStringAttribute("position"));
				if (checkRange(targetPos, vehiclePos, range)) {
					int vehicleId = vehicles[vRandomized[i]].getIntAttribute("id");
					const XmlElement@ vehicleInfo = getVehicleInfo(m_metagame, vehicleId);
					if (vehicleInfo !is null) {
						string vehicleKey = vehicleInfo.getStringAttribute("key");
						
						//making sure that certain vehicles are not targeted
						if (vehicleExceptionKeys.find(vehicleKey) == -1){
							int holderId = vehicleInfo.getIntAttribute("holder_id");
							array<const XmlElement@> characterList = vehicleInfo.getElementsByTagName("character");
							
							//if it is a vehicle held by the enemy and somebody is inside, presumably an enemy, then it is a valid target
							if (holderId != factionId && characterList.length() != 0){
								return vehiclePos.toString();
							}
						}
					}
				}
			}
		}
		
		//if no valid target is found at all, then we return this message
		return "empty";
	}
	
  	void fireProjectiles(AC130Request@ AC130Request, string fireTarget, string instanceKey, string soundFile, float spread, uint number, float delay, float offset, float speed = 1.0) {
		//extracting data
		int characterId = AC130Request.m_characterId;
		int factionId = AC130Request.m_factionId;
		Vector3 fireTargetVector = stringToVector3(fireTarget);
		
		//if the delay time is lower than m_delayTime, the lowest possible time between each shot, then it is disregarded
		if (delay > m_delayTime){
			delay -= m_delayTime;
		} else {
			delay = 0.0;
		}
				
		for (uint i = 0; i < number; ++i){		
			//direction is based on the current request's timer, which determines where the plane is at currently
			//m_delayTime is the time difference between shots, aka the time it takes to accomplish each create_instance commands
			//delay is used for imitating slower firerates, it is also accounted for determining the starting position
			//offset is used for manually offsetting the firing angle, such as accounting for a previous fireProjectiles function usage
			//a single m_delayTime is always added to account for the delay by the play_sound command
			Vector3 direction = gunRunVector(AC130Request.m_timer - i * (m_delayTime + delay) - offset - m_delayTime);
			//the above function gives us a normalized, horizontal direction vector

			//with the current settings (40h, 40v position, -1h, -1v speed by default) it takes roughly 0.66 seconds for projectiles to arrive
			//slower firerate is imitated by making consequtive shots have a slower velocity, thus they arrive later, determined by the delay value
			float delaySpeed = 0.66 / ((0.66 / speed) + delay * i);
			
			//projectile speed has been calibrated for 40 horizontal, 40 vertical spawn offset
			//delay makes consquent projectiles slower, thus seemingly decreasing the firerate
			//with this delay method all shots can be fired as soon as possible, thus finishing the script faster. We don't want to significantly delay other scripts
			Vector3 projectileSpeed = (Vector3(-direction.get_opIndex(0), -1, -direction.get_opIndex(2))).scale(delaySpeed);
		
			//determining the starting position by substracting a scaled up normalized direction vector
			Vector3 newPos = fireTargetVector.subtract(direction.scale(-40.0));
			
			//only playing the firing sound at the beginning of a salvo, for optimization reasons
			if (i == 0){
				XmlElement command("command");
					command.setStringAttribute("class", "play_sound");
					command.setStringAttribute("filename", soundFile);
					command.setStringAttribute("position", newPos.toString());
				m_metagame.getComms().send(command);
			}

			//randomizing the positions of the shots, based on the spread value
			float randx = rand(-spread, spread);
			float randz = rand(-spread, spread);
			newPos.set(newPos.get_opIndex(0) + randx, newPos.get_opIndex(1) + 40.0, newPos.get_opIndex(2) + randz);

			//spawning projectiles
			string c = 
				"<command class='create_instance'" +
				" faction_id='" + factionId + "'" +
				" instance_class='grenade'" +
				" instance_key='" + instanceKey + "'" +
				" position='" + newPos.toString() + "'" +
				" character_id='" + characterId + "'" +
				" offset='" + projectileSpeed.toString() + "' />";
			m_metagame.getComms().send(c);
		}
	}

	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		//timer on/off
		return m_running;
	}
}
