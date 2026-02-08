#include <amxmodx>
#include <reapi>
#include <json>
#include <ParamsController>
#include <ItemsController>

new const CONFIGS_PATH[] = "IC-CsdmEquip";
new const STAGES_FILE_PATH[] = "IC-CsdmEquip/Stages.json";

enum _:S_Stage {
    Stage_Title[64],
    Array:Stage_Items, // S_StageItem[]
}

enum _:S_StageItem {
    StageItem_Title[64],
    Array:StageItem_Items, // T_IC_Item[]
}

new Array:Stages = Invalid_Array;

new Trie:SelectedItem[MAX_PLAYERS + 1] = {Invalid_Trie, ...};

public plugin_precache() {
    register_plugin("[IC] CSDM Equip", "1.0.0", "ArKaNeMaN");
    ParamsController_Init();

    LoadStages();
    if (Stages == Invalid_Array || ArraySize(Stages) == 0) {
        set_fail_state("Stages not loaded. Plugin disabled.");
        return;
    }

    register_clcmd("ic_csdm_equip_auto", "@Cmd_Auto");
    register_clcmd("ic_csdm_equip_menu", "@Cmd_Menu");
    register_clcmd("ic_csdm_equip_stage", "@Cmd_Stage");
    register_clcmd("ic_csdm_equip_stage_item", "@Cmd_StageItem");

    RegisterHookChain(RG_CBasePlayer_Spawn, "@OnPlayerSpawn", .post = true);
}

public client_putinserver(playerIndex) {
    TrieDestroy(SelectedItem[playerIndex]);
}

@OnPlayerSpawn(const playerIndex) {
    @Cmd_Auto(playerIndex);
}

@Cmd_Auto(const playerIndex) {
    if (SelectedItem[playerIndex] != Invalid_Trie) {
        for (new i = 0, ii = ArraySize(Stages); i < ii; ++i) {
            new itemIndex;
            if (TrieGetCell(SelectedItem[playerIndex], fmt("%d", i), itemIndex)) {
                GiveStageItem(playerIndex, i, itemIndex);
            }
        }
    } else {
        ShowStageMenu(playerIndex, 0);
    }
}

@Cmd_Menu(const playerIndex) {
    ShowStageMenu(playerIndex, 0);
}

@Cmd_Stage(const playerIndex) {
    new stageIndex = read_argv_int(1);

    if ((stageIndex + 1) > ArraySize(Stages)) {
        return;
    }

    ShowStageMenu(playerIndex, stageIndex);
}

@Cmd_StageItem(const playerIndex) {
    GiveStageItem(playerIndex, read_argv_int(1), read_argv_int(2));
}

ShowStageMenu(const playerIndex, const stageIndex) {
    new stage[S_Stage];
    ArrayGetArray(Stages, stageIndex, stage);
    
    new menuHandler = menu_create(stage[Stage_Title], "@MenuHandler_Command");

    for (new i = 0, ii = ArraySize(stage[Stage_Items]); i < ii; ++i) {
        new stageItem[S_StageItem];
        ArrayGetArray(stage[Stage_Items], i, stageItem);

        menu_additem(menuHandler, stageItem[StageItem_Title], fmt("ic_csdm_equip_stage_item %d %d; ic_csdm_equip_stage %d", stageIndex, i, stageIndex + 1));
    }

    menu_display(playerIndex, menuHandler);
}

GiveStageItem(const playerIndex, const stageIndex, const stageItemIndex) {
    new stage[S_Stage];
    ArrayGetArray(Stages, stageIndex, stage);
    
    new stageItem[S_StageItem];
    ArrayGetArray(stage[Stage_Items], stageItemIndex, stageItem);
    
    IC_Item_GiveArray(playerIndex, stageItem[StageItem_Items]);
    
    if (SelectedItem[playerIndex] == Invalid_Trie) {
        SelectedItem[playerIndex] = TrieCreate();
    }
    TrieSetCell(SelectedItem[playerIndex], fmt("%d", stageIndex), stageItemIndex);
}

LoadStages() {
    new JSON:stagesJson = PCJson_ParseFile(
        PCPath_iMakePath(STAGES_FILE_PATH),
        PCPath_iMakePath(CONFIGS_PATH)
    );

    if (!json_is_array(stagesJson)) {
        PCJson_ErrorForFile(stagesJson, "Stages file must contain an array.");
        return;
    }

    Stages = ArrayCreate(S_Stage, 1);
    
    for (new i = 0, ii = json_array_get_count(stagesJson); i < ii; ++i) {
        new JSON:stageJson = json_array_get_value(stagesJson, i);

        if (!json_is_object(stageJson)) {
            json_free(stageJson);
            PCJson_ErrorForFile(stageJson, "Stages file must contain an array of objects.");
            continue;
        }

        new stage[S_Stage];

        PCSingle_ObjString(stageJson, "Title", stage[Stage_Title], charsmax(stage[Stage_Title]), .orFail = true);

        new JSON:itemsJson = json_object_get_value(stageJson, "Items");
        if (!json_is_array(itemsJson)) {
            json_free(stageJson);
            PCJson_ErrorForFile(itemsJson, "Field 'Items' must be an array or object.");
            continue;
        }

        stage[Stage_Items] = ArrayCreate(S_StageItem, 1);
        for (new j = 0, jj = json_array_get_count(itemsJson); j < jj; ++j) {
            new JSON:itemJson = json_array_get_value(itemsJson, j);

            if (!json_is_object(itemJson)) {
                json_free(itemJson);
                PCJson_ErrorForFile(itemJson, "Field 'Items' must be an array of objects.");
                continue;
            }

            new item[S_StageItem];

            PCSingle_ObjString(itemJson, "Title", item[StageItem_Title], charsmax(item[StageItem_Title]), .orFail = true);
            item[StageItem_Items] = PCSingle_ObjIcItems(itemJson, "Items");

            ArrayPushArray(stage[Stage_Items], item);
            json_free(itemJson);
        }

        ArrayPushArray(Stages, stage);
        json_free(stageJson);
    }

    PCJson_Free(stagesJson);
}

@MenuHandler_Command(const playerIndex, const menuIndex, const itemIndex) {
    if (itemIndex == MENU_EXIT) {
        menu_destroy(menuIndex);
        return;
    }

    new cmd[128];
    menu_item_getinfo(menuIndex, itemIndex, .info = cmd, .infolen = charsmax(cmd));
    
    if (cmd[0] != EOS) {
        client_cmd(playerIndex, cmd);
    }

    menu_destroy(menuIndex);
}
