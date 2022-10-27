// declare include paths
#include "path://media/packages/vanilla/scripts"

#include "gamemode_invasion.as"

// --------------------------------------------
void main(dictionary@ inputData) {
        XmlElement inputSettings(inputData);

        UserSettings settings;

        _setupLog("dev_verbose");

        settings.m_factionChoice = 1;
        settings.m_playerAiCompensationFactor = 1.1;
        settings.m_enemyAiAccuracyFactor = 0.95;
        settings.m_playerAiReduction = 1.0;
        settings.m_teamKillPenaltyEnabled = true;
        settings.m_completionVarianceEnabled = false;

        array<string> overlays = {
                "media/packages/invasion"
        };
        settings.m_overlayPaths = overlays;

        settings.m_startServerCommand = """
<command class='start_server'
	server_name='Test1'
	server_port='1240'
	comment='Coop campaign'
	url=''
	register_in_serverlist='0'
	mode='COOP'
	persistency='forever'
	max_players='24'>
	<client_faction id='0' />
</command>
""";
        settings.print();

        GameModeInvasion metagame(settings);

        metagame.init();
        metagame.run();
        metagame.uninit();

        _log("ending execution");
}



