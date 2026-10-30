#include "Chat.h"
#include "Config.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"

#include <string>

namespace
{
constexpr size_t MAX_ADDON_PACKET = 240;

bool SpellbookEnabled()
{
    return sConfigMgr->GetOption<uint32>("InfinityQoL.Enable", 1) != 0
        && sConfigMgr->GetOption<uint32>("InfinityQoL.Spellbook.Enable", 0) != 0;
}

void SendSpellbook(Player* player, std::string const& body)
{
    if (!player || !player->GetSession())
        return;

    std::string payload = std::string("IQOL\t") + body;
    if (payload.size() > MAX_ADDON_PACKET)
        return;

    WorldPacket data;
    ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, payload);
    player->GetSession()->SendPacket(&data);
}

void SendKnownSpells(Player* player)
{
    std::string chunk = "S:";

    for (auto const& pair : player->GetSpellMap())
    {
        if (!player->HasSpell(pair.first))
            continue;

        std::string id = std::to_string(pair.first);
        std::string next = chunk.size() == 2 ? id : ("," + id);
        if ((std::string("IQOL\t").size() + chunk.size() + next.size()) > MAX_ADDON_PACKET)
        {
            SendSpellbook(player, chunk);
            chunk = "S:" + id;
        }
        else
            chunk += next;
    }

    if (chunk.size() > 2)
        SendSpellbook(player, chunk);

    SendSpellbook(player, "S:END");
}
}

class iqol_spellbook_script : public PlayerScript
{
public:
    iqol_spellbook_script() : PlayerScript("iqol_spellbook_script") {}

    bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) override
    {
        if (!player || receiver != player || type != CHAT_MSG_WHISPER || language != LANG_ADDON)
            return true;

        if (msg != "IQOL\tSPELLS")
            return true;

        if (SpellbookEnabled())
            SendKnownSpells(player);
        else
            SendSpellbook(player, "OFF");

        return false;
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellId) override
    {
        if (!SpellbookEnabled() || !player || !player->HasSpell(spellId))
            return;

        SendSpellbook(player, "A:" + std::to_string(spellId));
    }

    void OnPlayerForgotSpell(Player* player, uint32 spellId) override
    {
        if (!SpellbookEnabled() || !player)
            return;

        SendSpellbook(player, "R:" + std::to_string(spellId));
    }
};

void AddSC_iqol_spellbook_script()
{
    new iqol_spellbook_script();
}
