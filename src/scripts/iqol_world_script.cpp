#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"

class iqol_world_script : public WorldScript
{
public:
    iqol_world_script() : WorldScript("iqol_world_script") {}

    void OnStartup() override
    {
        if (sConfigMgr->GetOption<uint32>("InfinityQoL.Enable", 1) == 0)
        {
            LOG_INFO("module", "Infinity QoL: disabled in configuration.");
            return;
        }

        LOG_INFO("module", "Infinity QoL: loaded.");

        if (sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.Enable", 0) == 0)
            LOG_INFO("module", "Infinity QoL pets: disabled in configuration.");
        else
            LOG_INFO("module", "Infinity QoL pets: hunter stable slots {}, class pets stay out beside the beast.",
                sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.StableSlots", 20));

        if (sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.Enable", 0) == 0
            || sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.SpellBar", 0) == 0)
            LOG_INFO("module", "Infinity QoL pet bar: disabled in configuration.");
        else
            LOG_INFO("module", "Infinity QoL pet bar: stance and aggression stay on the pet bar, abilities are consolidated.");

        if (sConfigMgr->GetOption<uint32>("InfinityQoL.Spellbook.Enable", 0) == 0)
            LOG_INFO("module", "Infinity QoL spellbook: disabled in configuration.");
        else
            LOG_INFO("module", "Infinity QoL spellbook: sending learned spell ids to the client.");
    }
};

void AddSC_iqol_world_script()
{
    new iqol_world_script();
}
