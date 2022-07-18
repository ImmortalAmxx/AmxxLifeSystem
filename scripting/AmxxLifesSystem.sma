#include <AmxModX>
#include <AmxMisc>
#include <ReApi_V>
#include <SqlX>

#define rg_get_user_money(%0) get_member(%0, m_iAccount)
#define is_user_valid(%1) (1 <= %1 <= MaxClients)

new const szPluginInfo[][] = {
	"[AMXX] Addon: Life",
	"0.2",
	"Immortal-",

	"lifes_system.ini"
};

enum {
	ADD_BUY = 0,
	ADD_SELL,
	ADD_SPAWNED
};

enum _:CvarData {
	SQL_HOST[128],
	SQL_USER[128],
	SQL_PASS[128],
	SQL_DBNAME[128],
	SQL_TABLENAME[128],
	COMMAND_OPEN[64],

	LIMIT,
	CHANSE
};

enum _:ArrData {
	MENU_TYPE[32],
	NAME_ITEM[128],
	PRICE[4]
};

new Array:g_aLifesData;
new Handle:MYSQL_Tuple, Handle:MYSQL_Connect;
new g_pCvarData[CvarData], g_szQuery[512], g_szUserSteamID[35][35], g_szConfigsDir[256], g_iLimit[33], g_iLifes[33], bool:g_bUserLoaded[33];

public client_putinserver(iPlayer) @LoadData(iPlayer);

public client_disconnected(iPlayer) { 
	if(!g_bUserLoaded[iPlayer])
		return;

	formatex(g_szQuery, charsmax(g_szQuery), "UPDATE `%s` SET `Lifes` = '%d' WHERE `%s`.`SteamID` = '%s';", g_pCvarData[SQL_TABLENAME], g_iLifes[iPlayer], g_pCvarData[SQL_TABLENAME], g_szUserSteamID[iPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
}

public plugin_init() {
	register_plugin(
		.plugin_name = szPluginInfo[0], 
		.version = szPluginInfo[1], 
		.author = szPluginInfo[2]
	);

	register_dictionary(.filename = "AmxxLifes.txt");

	@CreateCvar();
	@GameHook();
	@ArrayFunc();
}

@ArrayFunc() {
	g_aLifesData = ArrayCreate(ArrData);

	get_configsdir(g_szConfigsDir, charsmax(g_szConfigsDir));

	@CreateFile();
	@ReadFile();
}

@CreateCvar() {
	bind_pcvar_string(
		create_cvar(
			.name = "lifes_sql_host",
			.string = "localhost",
			.description = "Веб-хост (IP) от базы данных."
		), g_pCvarData[SQL_HOST], charsmax(g_pCvarData[SQL_HOST])
	);

	bind_pcvar_string(
		create_cvar(
			.name = "lifes_sql_user",
			.string = "root",
			.description = "Имя пользователя от базы данных."
		), g_pCvarData[SQL_USER], charsmax(g_pCvarData[SQL_USER])
	);

	bind_pcvar_string(
		create_cvar(
			.name = "lifes_sql_password",
			.string = "",
			.description = "Пароль от базы данных."
		), g_pCvarData[SQL_PASS], charsmax(g_pCvarData[SQL_PASS])
	);

	bind_pcvar_string(
		create_cvar(
			.name = "lifes_sql_dbname",
			.string = "sborka",
			.description = "Пароль от базы данных."
		), g_pCvarData[SQL_DBNAME], charsmax(g_pCvarData[SQL_DBNAME])
	);

	bind_pcvar_string(
		create_cvar(
			.name = "lifes_sql_tablename",
			.string = "lifes",
			.description = "Имя таблицы в базе данных."
		), g_pCvarData[SQL_TABLENAME], charsmax(g_pCvarData[SQL_TABLENAME])
	);

	bind_pcvar_string(
		create_cvar(
			.name = "lifes_command_open",
			.string = "lifes",
			.description = "Команда для открытия."
		), g_pCvarData[COMMAND_OPEN], charsmax(g_pCvarData[COMMAND_OPEN])
	);

	bind_pcvar_num(
		create_cvar(
			.name = "lifes_limit",
			.string = "2",
			.description = "Лимит использований жизней за раунд^n0 - Не использовать. Другое число - количество лимита.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[LIMIT]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "lifes_chanse",
			.string = "25",
			.description = "Шанс получения жизни при убийстве игрока.^nМаксимум - 100. Если не нужно выпадение - ставим 0.",
			.has_min = true,
			.min_val = 0.0,
			.has_max = true,
			.max_val = 100.0
		), g_pCvarData[CHANSE]
	);

	AutoExecConfig(.autoCreate = true, .name = "AmxxLifes");

	UTIL_RegisterClCmd(.szCmd = g_pCvarData[COMMAND_OPEN], .szFunc = "@ClientCommand_LifeMenu");   
}

@GameHook() {
	RegisterHookChain(RG_CBasePlayer_Killed, "@CSGameRules_PlayerKilled", .post = true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "@CSGameRules_RestartRound", .post = true);
}

public plugin_cfg() SQL_LoadDebug();

public plugin_end() {
	if(MYSQL_Tuple) SQL_FreeHandle(MYSQL_Tuple);
		  
	if(MYSQL_Connect) SQL_FreeHandle(MYSQL_Connect);
}

public SQL_LoadDebug() {
	new szError[512], iErrorCode; 
	  
	MYSQL_Tuple = SQL_MakeDbTuple(g_pCvarData[SQL_HOST], g_pCvarData[SQL_USER], g_pCvarData[SQL_PASS], g_pCvarData[SQL_DBNAME]);
	MYSQL_Connect = SQL_Connect(MYSQL_Tuple, iErrorCode, szError, charsmax(szError));
	  
	if(MYSQL_Connect == Empty_Handle) set_fail_state(szError);

	if(!SQL_TableExists(MYSQL_Connect, g_pCvarData[SQL_TABLENAME])) {
		new Handle:hQueries, szQuery[512];
		  
		formatex( szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (SteamID VARCHAR(32) CHARACTER SET cp1250 COLLATE cp1250_general_ci NOT NULL, Lifes INT NOT NULL, PRIMARY KEY (SteamID))", g_pCvarData[SQL_TABLENAME]);
		hQueries = SQL_PrepareQuery(MYSQL_Connect, szQuery);
		  
		if(!SQL_Execute(hQueries)) {
			SQL_QueryError(hQueries, szError, charsmax(szError));
			set_fail_state(szError);
		}

		SQL_FreeHandle(hQueries);
	}

	SQL_QueryAndIgnore(MYSQL_Connect, "SET NAMES utf8");
}

public SQL_Query(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], const iParamsSize) {
	switch(iState) {
		case TQUERY_CONNECT_FAILED: log_amx("Load - Could not connect to SQL database. [%d] %s", iErrorCode, szError);
		case TQUERY_QUERY_FAILED: log_amx("Load Query failed. [%d] %s", iErrorCode, szError);
	}
	  
	new iPlayer = iParams[0];
	g_bUserLoaded[iPlayer] = true;

	  
	if(SQL_NumResults(hQuery) < 1) {
		if(equal(g_szUserSteamID[iPlayer], "ID_PENDING"))
			return PLUGIN_HANDLED;
		  
		formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `%s` (`SteamID`, `Lifes`) VALUES ('%s', '%d');", g_pCvarData[SQL_TABLENAME], g_szUserSteamID[iPlayer], g_iLifes[iPlayer])
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery)
		  
		return PLUGIN_HANDLED;
	}
	else
		g_iLifes[iPlayer] = SQL_ReadResult(hQuery, 1);
	  
	return PLUGIN_HANDLED;
}

@LoadData(const iPlayer) {
	if(!is_user_connected(iPlayer))
		return;
	  
	new iParams[1];
	iParams[0] = iPlayer;	 
	  
	get_user_authid(iPlayer, g_szUserSteamID[iPlayer], charsmax(g_szUserSteamID[]));
	  
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT * FROM `%s` WHERE (`%s`.`SteamID` = '%s')", g_pCvarData[SQL_TABLENAME], g_pCvarData[SQL_TABLENAME], g_szUserSteamID[iPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Query", g_szQuery, iParams, sizeof iParams);
}

public SQL_Thread(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], const iParamsSize) {
	if(iState == 0)
		return;
	  
	log_amx("SQL Error: %d (%s)", iErrorCode, szError);
}

public plugin_natives() {
	register_native("amxx_get_user_life", "@Native_Amxx_Get_User_Life");
	register_native("amxx_set_user_life", "@Native_Amxx_Set_User_Life");
}

@Native_Amxx_Get_User_Life(iPlugin, iParams) {
	new iPlayer = get_param(1);
  
	if(!is_user_valid(iPlayer)) {
		log_error(AMX_ERR_NATIVE, "[LIFES] Invalid Player (%d)", iPlayer);
		return -1;
	}

	return g_iLifes[iPlayer];
}

@Native_Amxx_Set_User_Life(iPlugin, iParams) {
	new iPlayer = get_param(1);
	new iAmount = get_param(2);
  
	if(!is_user_valid(iPlayer))
		return false;

	return g_iLifes[iPlayer] = iAmount;
}

@CSGameRules_PlayerKilled(const pPlayer, const pKiller, const iGibs) {
	if(!is_user_connected(pKiller) || !g_pCvarData[CHANSE])
		return;

	if(rg_get_user_team(pKiller) == rg_get_user_team(pPlayer))
		return;

	new iRandom = random_num(1, 100);

	if(iRandom <= g_pCvarData[CHANSE]) {
		g_iLifes[pKiller] ++;
		client_print_color(pKiller, print_team_default, "%L", LANG_PLAYER, "GIVE");
	}
}

@CSGameRules_RestartRound() {
	for(new pPlayer = 1; pPlayer < MaxClients; pPlayer++) {
		if(g_iLimit[pPlayer] > 0)
			g_iLimit[pPlayer] = 0;
	}
}

@ClientCommand_LifeMenu(const pPlayer) {
	new szNum[6];
	new iMenu = menu_create(fmt("%L", LANG_PLAYER, "MENU_TITLE", g_iLifes[pPlayer]), "@LifeMenu_Handler");

	new aData[ArrData];

	for(new iItem; iItem < ArraySize(g_aLifesData); iItem++) {
		num_to_str(iItem, szNum, charsmax(szNum));
		ArrayGetArray(g_aLifesData, iItem, aData);

		new iAddType = str_to_num(aData[MENU_TYPE]);
		
		if(iAddType == ADD_BUY || iAddType == ADD_SELL || iAddType == ADD_SPAWNED) {
			menu_additem(iMenu, aData[NAME_ITEM], fmt("%i", iItem));
		}
	}

	UTIL_RegisterMenu(pPlayer, iMenu);
}

@LifeMenu_Handler(pPlayer, iMenu, iItem) {
	if(iItem == MENU_EXIT)
		return menu_destroy(iMenu);
  
	new iAccess, szData[64], aData[ArrData];
	menu_item_getinfo(iMenu, iItem, iAccess, szData, charsmax(szData));
	menu_destroy(iMenu);

	ArrayGetArray(g_aLifesData, iItem, aData);

	new iAddType, iPrice;
	iAddType = str_to_num(aData[MENU_TYPE]);
	iPrice = str_to_num(aData[PRICE]); 

	switch(iAddType) {
		case ADD_BUY: {
			if(aData[PRICE] != EOS) {
				if(rg_get_user_money(pPlayer) < iPrice) {
					client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "NO_MONEY");
					@ClientCommand_LifeMenu(pPlayer);
				}
				else rg_add_account(pPlayer, rg_get_user_money(pPlayer) - iPrice, AS_SET);
			}

			g_iLifes[pPlayer]++;
			client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "GIVE");
		}
		case ADD_SELL: {
			if(g_iLifes[pPlayer] <= 0) {
				client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "NO_LIFE");
				@ClientCommand_LifeMenu(pPlayer);

				return PLUGIN_HANDLED;
			}
			else {
				if(aData[PRICE] != EOS) rg_add_account(pPlayer, rg_get_user_money(pPlayer) + iPrice, AS_SET);

				g_iLifes[pPlayer]--;
				client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "SELL");
			}
		}
		default: {
			if(is_user_alive(pPlayer)) {
				client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "ALIVE");
				return PLUGIN_HANDLED;
			}
			  
			if(g_iLifes[pPlayer] <= 0) {
				client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "NO_LIFE");
				return PLUGIN_HANDLED;
			}

			if(g_pCvarData[LIMIT]) {
				if(g_iLimit[pPlayer] >= g_pCvarData[LIMIT]) {
					client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "LIMIT");
					return PLUGIN_HANDLED;	 
				}
				else g_iLimit[pPlayer] ++;
			} 

			if(aData[PRICE] != EOS) {
				if(rg_get_user_money(pPlayer) < iPrice) {
					client_print_color(pPlayer, print_team_default, "%L", LANG_PLAYER, "NO_MONEY");
					@ClientCommand_LifeMenu(pPlayer);
				}
				else {
					rg_add_account(pPlayer, rg_get_user_money(pPlayer) - iPrice, AS_SET);
					rg_round_respawn(pPlayer);
					g_iLifes[pPlayer] --;
				}
			}
			else {
				rg_round_respawn(pPlayer);
				g_iLifes[pPlayer] --;
			}
		}
	}

	return PLUGIN_CONTINUE;
}

@CreateFile() {
	new szData[256];

	formatex(szData, charsmax(szData), "%s", g_szConfigsDir);

	if(!dir_exists(szData))
		mkdir(szData);
  
	formatex(szData, charsmax(szData), "%s/%s", szData, szPluginInfo[3]);

	if(!file_exists(szData))
		write_file(szData,
		";  /*-----[Пример записи в файл]-----*/^n\
		;^n\
		;   ^"Что именно добавляем?^" ^"Название пункта^" ^"Цена (Если не нужно - пустота)^"^n\
		;   Что именно добавляем -- Куда записываем:^n\
		;	   0 -- В покупку.^n\	 
		;	   1 -- В продажу.^n\
		;	   2 -- Возродится.^n\
		;^n\
		;   Название пункта -- Название пункта в меню.^n\
		;^n\
		;   Цена -- Цена за покупку/продажу/возрождение.^n\
		;^n\
		;   /*-----[Глобальные Настройки]-----*/^n\
		"
	);
}

@ReadFile() {
	new szData[256], szFile[256], f, aData[ArrData];
	formatex(szFile, charsmax(szFile), "%s/%s", g_szConfigsDir, szPluginInfo[3]);
	f = fopen(szFile, "r");

	while(!feof(f)) {
        fgets(f, szData, charsmax(szData));
        trim(szData);

        if(szData[0] == EOS || szData[0] == ';' || szData[0] == '/' && szData[1] == '/')
            continue;

        if(szData[0] == '"') {
            parse(szData,
                aData[MENU_TYPE], charsmax(aData),
                aData[NAME_ITEM], charsmax(aData),
                aData[PRICE], charsmax(aData)
            );

            ArrayPushArray(g_aLifesData, aData);
		}
		else
			continue;
	}

	fclose(f);
}

stock bool:SQL_TableExists(Handle: hDataBase, const szTable[]) {
	new Handle: hQuery = SQL_PrepareQuery(hDataBase, "SELECT * FROM information_schema.tables WHERE table_name = '%s' LIMIT 1;", szTable);
	new szError[512];
  
	if(!SQL_Execute(hQuery)) {
		SQL_QueryError(hQuery, szError, charsmax(szError));
		set_fail_state(szError);
	}
	else if( !SQL_NumResults(hQuery)) {
		SQL_FreeHandle(hQuery);
		return false;
	}

	SQL_FreeHandle(hQuery);
	return true;
}
