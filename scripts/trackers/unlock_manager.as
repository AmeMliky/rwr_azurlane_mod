// internal
#include "tracker.as"
#include "log.as"
#include "query_helpers.as"

// generic trackers
#include "resource.as"
#include "resource_unlocker.as"

// --------------------------------------------
class ResourceTimer {
	protected float m_timer;
	protected const Resource@ m_resource;

	// --------------------------------------------
	ResourceTimer(float t, const Resource@ resource) {
		m_timer = t;
		@m_resource = @resource;
	}

	// --------------------------------------------
	void update(float time) {
		m_timer -= time;
	}

	// --------------------------------------------
	bool hasExpired() const {
		return m_timer < 0.0;
	}

	// --------------------------------------------
	const Resource@ getResource() const {
		return m_resource;
	}

	// --------------------------------------------
	float getTime() const {
		return m_timer;
	}

	// --------------------------------------------
	void replaceResource(const Resource@ resource) {
		@m_resource = @resource;
	}
};

// --------------------------------------------
interface UnlockRemoveListener {
	void itemUnlockRemoved(const Resource@ resource);
}

// --------------------------------------------
class UnlockManager : Tracker {
	protected Metagame@ m_metagame;
	protected array<ResourceTimer@> m_unlocks;
	protected int m_factionId ;
	protected float m_unlockStartTime;
	protected UnlockRemoveListener@ m_listener;

	// --------------------------------------------
	UnlockManager(Metagame@ metagame, UnlockRemoveListener@ listener, float unlockStartTime = -1.0) {
		@m_metagame = @metagame;
		@m_listener = @listener;
		m_unlockStartTime = 4.0 * 60.0 * 60.0;

		if (unlockStartTime > 0) {
			m_unlockStartTime = unlockStartTime;
		}
	}

	// --------------------------------------------
	void init(int factionId) {
		m_factionId = factionId;
	}

	// --------------------------------------------
	void start() {
	}

	// --------------------------------------------
	void update(float time) {
		// update all timers
		for (uint i = 0; i < m_unlocks.size(); ++i) {
			ResourceTimer@ unlock = m_unlocks[i];
			unlock.update(time);
			if (unlock.hasExpired()) {
				// time to drop to unlock
				const Resource@ r = unlock.getResource(); 
				if (r !is null) {
					dropResource(r);
					m_unlocks.erase(i);
					i--;
					_log("unlocks: " + m_unlocks.size(), 1);
				}
			}
		}
	}

    // ----------------------------------------------------
	// debugging tools
    protected void handleChatEvent(const XmlElement@ event) {
		// player_id
		// player_name
		// message
		// global

		string message = event.getStringAttribute("message");
		// for the most part, chat events aren't commands, so check that first
		if (!startsWith(message, "/")) {
				return;
		}

		string sender = event.getStringAttribute("player_name");
		int senderId = event.getIntAttribute("player_id");

		if (!m_metagame.getAdminManager().isAdmin(sender, senderId)) {
			return;
		}

        if (checkCommand(message, "remove_unlock")) {
			sendFactionMessage(m_metagame, 0, "removing unlock");
			if (m_unlocks.size() > 0) {
				ResourceTimer@ first = m_unlocks[0];
				first.update(m_unlockStartTime);
			}
		}
	}

	// --------------------------------------------
	bool hasEnded() const {
		// always on
		return false;
	}

	// --------------------------------------------
	bool hasStarted() const {
		// always on
		return true;
	}

	// --------------------------------------------
	void add(const Resource@ resource) {
		if (resource is null) return;

		m_unlocks.insertLast(ResourceTimer(m_unlockStartTime, resource));

		_log("unlocks: " + m_unlocks.size(), 1);
	}

	// --------------------------------------------
	protected void dropResource(const Resource@ resource) {
		if (resource is null) return;

		_log("* resource unlock expired, removing unlock for " + resource.m_key + " (" + resource.m_type + ")", 1);

		// disable the resource
		array<string> groupsChanged;
		changeFactionResources(m_metagame, m_factionId, array<const Resource@> = {resource}, false, groupsChanged);

		// query for unlock name
		string name = getResourceName(m_metagame, resource.m_key, resource.m_type);
		if (name != "") {
			dictionary a = {
				{"%resource_name", name}
			}; 
			string textKey = getResourceAvailabilityTextKey("resource out of stock", groupsChanged);
			sendFactionMessageKey(m_metagame, m_factionId, textKey, a);
		}		

		m_listener.itemUnlockRemoved(resource);
	}

	// --------------------------------------------
	void applyUnlocks() {
		array<const Resource@> resources;

		for (uint i = 0; i < m_unlocks.size(); ++i) {
			ResourceTimer@ unlock = m_unlocks[i];
			const Resource@ r = unlock.getResource();
			resources.insertLast(r);
		}

		changeFactionResources(m_metagame, m_factionId, resources, true);
	}

	// --------------------------------------------
	void save(XmlElement@ root) {
		XmlElement@ parent = @root;
		XmlElement subroot("unlock_manager");
		subroot.setIntAttribute("faction_id", m_factionId);
		for (uint i = 0; i < m_unlocks.size(); ++i) {
			ResourceTimer@ unlock = m_unlocks[i];
			XmlElement e("resource");
			e.setFloatAttribute("time", unlock.getTime());
			const Resource@ r = unlock.getResource();
			e.setStringAttribute("key", r.m_key);
			e.setStringAttribute("type", r.m_type);

			const MultiGroupResource@ mgr = cast<const MultiGroupResource>(r);
			if (mgr !is null) {
				for (uint j = 0; j < mgr.m_groups.size(); ++j) {
					XmlElement g("group");
					string group = mgr.m_groups[j];
					g.setStringAttribute("name", group);
					e.appendChild(g);
				}
			}

			subroot.appendChild(e);
		}
		parent.appendChild(subroot);
	}

	// --------------------------------------------
	void load(const XmlElement@ root) {
		_log("loading unlock manager", 1);
		m_unlocks.clear();

		const XmlElement@ subroot = root.getFirstElementByTagName("unlock_manager");
		if (subroot !is null) {
			m_factionId = subroot.getIntAttribute("faction_id");
			_log("unlock_manager found, faction_id " + m_factionId, 1);
			array<const XmlElement@> list = subroot.getElementsByTagName("resource");
			for (uint i = 0; i < list.size(); ++i) {
				const XmlElement@ e = list[i];
				float time = e.getFloatAttribute("time");
				string key = e.getStringAttribute("key");
				string type = e.getStringAttribute("type");

				Resource@ r;

				array<const XmlElement@>@ groups = e.getElementsByTagName("group");
				if (groups.size() == 0) {
					// no groups, use the general way
					@r = Resource(key, type);
				} else {
					// yes groups, add them in the resource
					array<string> groupList;
					for (uint j = 0; j < groups.size(); ++j) {
						const XmlElement@ g = groups[j];
						groupList.insertLast(g.getStringAttribute("name"));
					}
					@r = MultiGroupResource(key, type, groupList);
				}

				_log("adding unlock: " + time + ", key=" + key + ", type=" + type, 1);
				m_unlocks.insertLast(ResourceTimer(time, r));
			}
		} else {
			_log("unlock_manager not found?");
		}
	}
}
