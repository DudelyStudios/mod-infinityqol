#include "ScriptMgr.h"
#include "Log.h"

void AddSC_iqol_world_script();
void AddSC_iqol_stack_script();
void AddSC_iqol_spellbook_script();
void AddSC_iqol_petbar_script();

// Next feature: add a script under src/scripts/, call its AddSC_* here,
// and add InfinityQoL.<Feature>.Enable to conf/mod_infinityqol.conf.dist.
void Addmod_infinityqolScripts()
{
    AddSC_iqol_world_script();
    AddSC_iqol_stack_script();
    AddSC_iqol_spellbook_script();
    AddSC_iqol_petbar_script();
}
