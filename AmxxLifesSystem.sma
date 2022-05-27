#include <AmxModX>
#include <ReApi>
#include <ReApi_V>

new const szPluginInfo[][] = {
	"[AMXX] System: Lifes",
	"0.1",
	"ImmortalAmxx"
};

#define USE_SaveMySQL
#define rg_get_user_money(%0) get_member(%0, m_iAccount)
#define is_user_valid(%1) (1 <= %1 <= 32)

enum _:Cvars {
	COMMAND[64],
	LIMIT,
	LIMIT_RESPAWN,
	COUNT_ADD,
	PRICE_BUY,
	PRICE_SELL
};

enum _:Player {
	LIFE_COUNT,
	RESPAWN_COUNT
};

new g_pCvars[Cvars],
	g_pPlayerData[33][Player];

public plugin_init() {
	register_plugin(
		.plugin_name = szPluginInfo[0], 
		.version = szPluginInfo[1], 
		.author = szPluginInfo[2]
	);
	register_dictionary(.filename = "AmxxLifes.txt");

	UTIL_Cvars();
	UTIL_Hook();
	UTIL_RegisterClCmd(.szCmd = g_pCvars[COMMAND], .szFunc = "ClientCommand_Lifes");
}

public UTIL_Cvars() {
	bind_pcvar_string(create_cvar(
		.name = "lifes_command_open",
		.string = "lifes",
		.description = "Команда для открытия меню"
	), g_pCvars[COMMAND], charsmax(g_pCvars[COMMAND]));

	bind_pcvar_num(create_cvar(
		.name = "lifes_limit",
		.string = "0.0",
		.description = "Лимит жизней. 0 - бесконечно."
	), g_pCvars[LIMIT]);

	bind_pcvar_num(create_cvar(
		.name = "lifes_limit_respawn",
		.string = "0.0",
		.description = "Лимит возрождений. 0 - бесконечно."
	), g_pCvars[LIMIT_RESPAWN]);	

	bind_pcvar_num(create_cvar(
		.name = "lifes_count_add",
		.string = "1.0",
		.description = "Сколько давать жизней за убийство? 0 - Не давать."
	), g_pCvars[COUNT_ADD]);

	bind_pcvar_num(create_cvar(
		.name = "lifes_price_buy",
		.string = "1000.0",
		.description = "Цена за жизнь (при покупке). 0 - Не добавлять возможность покупать."
	), g_pCvars[PRICE_BUY]);

	bind_pcvar_num(create_cvar(
		.name = "lifes_price_sell",
		.string = "1000.0",
		.description = "Цена за жизнь (при продаже). 0 - Не добавлять возможность продавать."
	), g_pCvars[PRICE_SELL]);

	AutoExecConfig(.autoCreate = true, .name = "AmxxLifes");
}

public plugin_natives() {
	register_native("amxx_get_user_lifes", "native_amxx_get_user_lifes", true);
	register_native("amxx_set_user_lifes", "native_amxx_set_user_lifes", true);
}

public native_amxx_get_user_lifes(pPlayer)
	return g_pPlayerData[pPlayer][LIFE_COUNT];

public native_amxx_set_user_lifes(pPlayer, iAmount) {
	if(!is_user_valid(pPlayer))
		return;

	g_pPlayerData[pPlayer][LIFE_COUNT] = iAmount;
}

public UTIL_Hook() {
	if(g_pCvars[COUNT_ADD] > 0)
		RegisterHookChain(RG_CBasePlayer_Killed, "RG_CBasePlayer_Killed_Post", .post = true);

	RegisterHookChain(RG_RoundEnd, "RG_RoundEnd_Post", .post = true);
}

public RG_CBasePlayer_Killed_Post(pVictim, pAttacker) {
	if(pAttacker == pVictim || rg_get_user_team(pAttacker) == rg_get_user_team(pVictim))
		return HC_CONTINUE;

	if(g_pCvars[LIMIT] > 0) {
		if(g_pPlayerData[pAttacker][LIFE_COUNT] < g_pCvars[LIMIT])
			g_pPlayerData[pAttacker][LIFE_COUNT]++;
	}
	else
		g_pPlayerData[pAttacker][LIFE_COUNT]++;

	return HC_CONTINUE;
}

public RG_RoundEnd_Post(WinStatus:iWinStatus) {
	for(new pPlayer = 1; pPlayer <= MaxClients; pPlayer++) 
		g_pPlayerData[pPlayer][RESPAWN_COUNT] = 0;
}

public ClientCommand_Lifes(pPlayer) {
	if(g_pCvars[PRICE_SELL] <= 0 && g_pCvars[PRICE_BUY] <= 0) {
		client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_NO_MENU");
		return;
	}

	new iMenu = menu_create(fmt("%L", LANG_PLAYER, "MENU_TITLE_LIFE", g_pPlayerData[pPlayer][LIFE_COUNT]), "MenuLife_Handler");

	menu_additem(iMenu, fmt("%L", LANG_PLAYER, "MENU_LIFE_BUY", g_pCvars[PRICE_BUY]), "1");
	menu_additem(iMenu, fmt("%L", LANG_PLAYER, "MENU_LIFE_SELL", g_pCvars[PRICE_SELL]), "2");
	menu_additem(iMenu, fmt("%L", LANG_PLAYER, "MENU_LIFE_RESPAWN"), "3");

	UTIL_RegisterMenu(pPlayer, iMenu, "Назад", "Далее", "Выход", "\y");
}

public MenuLife_Handler(pPlayer, iMenu, iItem) {
	if(iItem == MENU_EXIT)
		return menu_destroy(iMenu);
	
	new iAccess, szData[64], szName[64]; 
	new iMoney = rg_get_user_money(pPlayer);
	menu_item_getinfo(iMenu, iItem, iAccess, szData, charsmax(szData), szName, charsmax(szName));
	menu_destroy(iMenu);

	switch(str_to_num(szData)) {
		case 1: {
			if(g_pCvars[LIMIT] > 0) {
				if(g_pPlayerData[pPlayer][LIFE_COUNT] < g_pCvars[LIMIT]) {
					client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_LIMIT");
					ClientCommand_Lifes(pPlayer);
				}
			}

			if(iMoney >= g_pCvars[PRICE_BUY]) {
				rg_add_account(pPlayer, iMoney - g_pCvars[PRICE_BUY], AS_SET);
				client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_BUY");
				g_pPlayerData[pPlayer][LIFE_COUNT]++;
			}			
		}
		case 2: {
			if(g_pPlayerData[pPlayer][LIFE_COUNT] > 0) {
				rg_add_account(pPlayer, iMoney + g_pCvars[PRICE_SELL], AS_SET);
				client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_SELL");
				g_pPlayerData[pPlayer][LIFE_COUNT]--;
			}
		}
		case 3: {
			if(is_user_alive(pPlayer)) {
				client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_ALREADY_ALIVE");
				return PLUGIN_HANDLED;
			}
			if(g_pCvars[LIMIT_RESPAWN] > 0) {
				if(g_pPlayerData[pPlayer][RESPAWN_COUNT] >= g_pCvars[LIMIT_RESPAWN]) {
					client_print_color(pPlayer, print_team_default, "%l %l", "LIFE_TAG", "LIFE_LIMIT_RESPAWN", g_pCvars[LIMIT_RESPAWN]);
					ClientCommand_Lifes(pPlayer);
				}
			}

			rg_round_respawn(pPlayer);
			g_pPlayerData[pPlayer][RESPAWN_COUNT]++;
			g_pPlayerData[pPlayer][LIFE_COUNT]--;
		}		
	}

	return PLUGIN_HANDLED;
}