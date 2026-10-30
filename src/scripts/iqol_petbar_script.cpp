#include "Chat.h"
#include "CharmInfo.h"
#include "Config.h"
#include "Pet.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldSession.h"

#include <cstdlib>
#include <functional>
#include <string>
#include <unordered_map>

namespace
{
constexpr size_t MAX_ADDON_PACKET = 240;
constexpr uint32 BAR_POLL_MS = 400;
constexpr char CAST_PREFIX[] = "IQOL\tPETCAST:";
constexpr size_t CAST_PREFIX_LEN = sizeof(CAST_PREFIX) - 1;
constexpr char AUTO_PREFIX[] = "IQOL\tPETAUTO:";
constexpr size_t AUTO_PREFIX_LEN = sizeof(AUTO_PREFIX) - 1;
constexpr uint32 SPELL_TAME_BEAST = 1515;
constexpr uint32 HUNTER_CLASS_BIT = 1u << (CLASS_HUNTER - 1);

struct BarState
{
    uint32 timer = 0;
    std::string last;
    bool haveLast = false;
};

std::unordered_map<uint64, BarState> barStates;

bool SpellBarEnabled()
{
    return sConfigMgr->GetOption<uint32>("InfinityQoL.Enable", 1) != 0
        && sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.Enable", 0) != 0
        && sConfigMgr->GetOption<uint32>("InfinityQoL.Pets.SpellBar", 0) != 0;
}

bool AltHunter(Player const* player)
{
    return player && player->getClass() != CLASS_HUNTER
        && (player->GetUnboundClassMask() & HUNTER_CLASS_BIT) != 0;
}

void SendPetBar(Player* player, std::string const& body)
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

void ForEachControlledPet(Player* player, std::function<void(Pet*)> const& visitor)
{
    for (Unit* unit : player->m_Controlled)
    {
        if (!unit || !unit->IsPet() || !unit->IsAlive())
            continue;

        Pet* pet = unit->ToPet();
        if (!pet)
            continue;

        PetType type = pet->getPetType();
        if (type == HUNTER_PET || type == SUMMON_PET)
            visitor(pet);
    }
}

Pet* FindPetWithSpell(Player* player, uint32 spellId)
{
    Pet* found = nullptr;
    ForEachControlledPet(player, [&](Pet* pet)
    {
        if (!found && pet->HasSpell(spellId))
            found = pet;
    });
    return found;
}

bool SpellAlreadyListed(std::string const& list, uint32 spellId)
{
    std::string token = std::to_string(spellId) + ":";
    size_t pos = 0;
    while ((pos = list.find(token, pos)) != std::string::npos)
    {
        if (pos == 0 || list[pos - 1] == ',')
            return true;
        pos += token.size();
    }
    return false;
}

bool IsCastablePetSpell(UnitActionBarEntry const* entry)
{
    if (!entry || !entry->GetAction())
        return false;

    ActiveStates type = entry->GetType();
    return type != ACT_COMMAND && type != ACT_REACTION && type != ACT_DECIDE;
}

std::string ControlledPetSpellList(Player* player)
{
    std::string list;
    ForEachControlledPet(player, [&](Pet* pet)
    {
        CharmInfo* charm = pet->GetCharmInfo();
        if (!charm)
            return;

        for (uint8 i = 0; i < MAX_UNIT_ACTION_BAR_INDEX; ++i)
        {
            UnitActionBarEntry const* entry = charm->GetActionBarEntry(i);
            if (!IsCastablePetSpell(entry))
                continue;

            uint32 spellId = entry->GetAction();
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
            if (!spellInfo || spellInfo->IsPassive() || !pet->HasSpell(spellId))
                continue;

            if (SpellAlreadyListed(list, spellId))
                continue;

            uint8 mode = 2;
            if (spellInfo->IsAutocastable())
                mode = entry->GetType() == ACT_ENABLED ? 1 : 0;

            if (!list.empty())
                list += ',';
            list += std::to_string(spellId) + ":" + std::to_string(mode);
        }
    });

    if (AltHunter(player) && !SpellAlreadyListed(list, SPELL_TAME_BEAST))
    {
        if (!list.empty())
            list += ',';
        list += std::to_string(SPELL_TAME_BEAST) + ":2";
    }

    return list;
}

void PublishBar(Player* player, BarState& state, std::string const& list)
{
    if (state.haveLast && state.last == list)
        return;

    state.last = list;
    state.haveLast = true;
    SendPetBar(player, "PETBAR:" + list);
}

void CastClassPetSpell(Player* player, uint32 spellId)
{
    if (!SpellBarEnabled() || !spellId)
        return;

    if (spellId == SPELL_TAME_BEAST && AltHunter(player))
    {
        Unit* beast = player->GetSelectedUnit();
        if (!beast)
            return;

        player->CastSpell(beast, SPELL_TAME_BEAST, TRIGGERED_NONE);
        return;
    }

    Pet* pet = FindPetWithSpell(player, spellId);
    SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
    if (!pet || !spellInfo || spellInfo->IsPassive() || !pet->HasSpell(spellId))
        return;

    Unit* target = player->GetSelectedUnit();
    if (spellInfo->NeedsExplicitUnitTarget() && !target)
        return;

    if (pet->CastSpell(target, spellId, TRIGGERED_NONE) != SPELL_CAST_OK)
        return;

    uint32 recovery = spellInfo->GetRecoveryTime();
    if (!recovery)
        recovery = spellInfo->StartRecoveryTime;
    if (!recovery)
        return;

    SendPetBar(player, "PETCD:" + std::to_string(spellId) + ":" + std::to_string(recovery));
}

void TogglePetAutocast(Player* player, uint32 spellId)
{
    if (!SpellBarEnabled() || !spellId)
        return;

    Pet* pet = FindPetWithSpell(player, spellId);
    SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
    CharmInfo* charm = pet ? pet->GetCharmInfo() : nullptr;
    if (!pet || !spellInfo || !charm || !spellInfo->IsAutocastable() || !pet->HasSpell(spellId))
        return;

    bool enabled = false;
    for (uint8 i = 0; i < MAX_UNIT_ACTION_BAR_INDEX; ++i)
    {
        UnitActionBarEntry const* entry = charm->GetActionBarEntry(i);
        if (entry && entry->GetAction() == spellId && entry->GetType() == ACT_ENABLED)
        {
            enabled = true;
            break;
        }
    }

    pet->ToggleAutocast(spellInfo, !enabled);
    charm->SetSpellAutocast(spellInfo, !enabled);

    auto state = barStates.find(player->GetGUID().GetRawValue());
    if (state != barStates.end())
        state->second.haveLast = false;
}
}

class iqol_petbar_script : public PlayerScript
{
public:
    iqol_petbar_script() : PlayerScript("iqol_petbar_script") {}

    bool OnPlayerCanUseChat(Player* player, uint32 type, uint32 language, std::string& msg, Player* receiver) override
    {
        if (!player || receiver != player || type != CHAT_MSG_WHISPER || language != LANG_ADDON)
            return true;

        if (msg.compare(0, CAST_PREFIX_LEN, CAST_PREFIX) == 0)
        {
            uint32 spellId = static_cast<uint32>(std::strtoul(msg.c_str() + CAST_PREFIX_LEN, nullptr, 10));
            CastClassPetSpell(player, spellId);
            return false;
        }

        if (msg.compare(0, AUTO_PREFIX_LEN, AUTO_PREFIX) == 0)
        {
            uint32 spellId = static_cast<uint32>(std::strtoul(msg.c_str() + AUTO_PREFIX_LEN, nullptr, 10));
            TogglePetAutocast(player, spellId);
            return false;
        }

        return true;
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (!player)
            return;

        BarState& state = barStates[player->GetGUID().GetRawValue()];
        state.timer += diff;
        if (state.timer < BAR_POLL_MS)
            return;
        state.timer = 0;

        if (!SpellBarEnabled())
        {
            PublishBar(player, state, "OFF");
            return;
        }

        PublishBar(player, state, ControlledPetSpellList(player));
    }

    void OnPlayerLogout(Player* player) override
    {
        if (player)
            barStates.erase(player->GetGUID().GetRawValue());
    }
};

void AddSC_iqol_petbar_script()
{
    new iqol_petbar_script();
}
