#include "Config.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "ScriptMgr.h"

#include <unordered_map>
#include <vector>

namespace
{
constexpr int32 STACK_CAP_LIMIT = 100000;

std::unordered_map<uint32, int32> originalStacks;

int32 ClampCap(int32 cap)
{
    if (cap > STACK_CAP_LIMIT)
        return STACK_CAP_LIMIT;
    return cap;
}

void ApplyStackSizes()
{
    std::vector<ItemTemplate*> const* store = sObjectMgr->GetItemTemplateStoreFast();
    if (!store || store->empty())
        return;

    bool master = sConfigMgr->GetOption<uint32>("InfinityQoL.Enable", 1) != 0;
    bool enabled = master && sConfigMgr->GetOption<uint32>("InfinityQoL.Stack.Enable", 0) != 0;
    int32 consumableCap = ClampCap(sConfigMgr->GetOption<int32>("InfinityQoL.Stack.Consumable", 200));
    int32 tradeCap = ClampCap(sConfigMgr->GetOption<int32>("InfinityQoL.Stack.TradeGoods", 200));

    uint32 changed = 0;
    for (ItemTemplate* proto : *store)
    {
        if (!proto)
            continue;

        if (proto->Class != ITEM_CLASS_CONSUMABLE && proto->Class != ITEM_CLASS_TRADE_GOODS)
            continue;

        if (originalStacks.find(proto->ItemId) == originalStacks.end())
            originalStacks.emplace(proto->ItemId, proto->Stackable);

        int32 original = originalStacks[proto->ItemId];
        int32 cap = proto->Class == ITEM_CLASS_CONSUMABLE ? consumableCap : tradeCap;
        int32 next = original;
        if (enabled && cap > 1 && original > 1)
            next = cap;

        if (proto->Stackable != next)
        {
            proto->Stackable = next;
            ++changed;
        }
    }

    if (!enabled)
        LOG_INFO("module", "Infinity QoL stacks: using database stack sizes.");
    else
        LOG_INFO("module", "Infinity QoL stacks: consumables {}, trade goods {}, templates updated {}.",
            consumableCap, tradeCap, changed);
}

class iqol_stack_script : public WorldScript
{
public:
    iqol_stack_script() : WorldScript("iqol_stack_script") {}

    void OnStartup() override
    {
        ApplyStackSizes();
    }

    void OnAfterConfigLoad(bool reload) override
    {
        if (reload)
            ApplyStackSizes();
    }
};
}

void AddSC_iqol_stack_script()
{
    new iqol_stack_script();
}
