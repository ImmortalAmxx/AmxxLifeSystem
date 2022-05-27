#include <AmxModX>
#include <SqlX>

native amxx_get_user_lifes(pPlayer);
native amxx_set_user_lifes(pPlayer, iAmount);

new const PVA [][] = {
	"[SQL] Save: Lifes",
	"0.1",
	"ImmortalAmxx"
};

public plugin_init() {
	register_plugin(PVA[0], PVA[1], PVA[2]);
}

new g_iUserLifes[MAX_PLAYERS + 1];

// Данные От БД;
new const SQL_HOST[]		= "127.0.0.1";	// Хост.
new const SQL_USER[]		= "root";		// Пользователь.
new const SQL_PASSWORD[] 	= "";			// Пароль.
new const SQL_DATABASE[] 	= "sborka";		// БД.
new const SQL_TABLENAME[] 	= "test_pl"; 	// Имя Таблицы.

new Handle:MYSQL_Tuple;
new Handle:MYSQL_Connect;
new g_szQuery[MAX_PLAYERS * 16];

new bool:UserLoaded[MAX_PLAYERS + 1];
new UserSteamID[MAX_PLAYERS + 1][MAX_PLAYERS + 2];

public client_putinserver(pPlayer) {
	LoadData(pPlayer);
}

public client_disconnected(pPlayer) {
	if(!UserLoaded[pPlayer])
		return;

	g_iUserLifes[pPlayer] = amxx_get_user_lifes(pPlayer);
	
	formatex(g_szQuery, charsmax(g_szQuery), "UPDATE `%s` SET `Lifes` = '%d' WHERE `%s`.`SteamID` = '%s';", SQL_TABLENAME, g_iUserLifes[pPlayer], SQL_TABLENAME, UserSteamID[pPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
}

public plugin_cfg() {
	SQL_LoadDebug();
}

public plugin_end() {
	if(MYSQL_Tuple) 
		SQL_FreeHandle(MYSQL_Tuple);
	
	if(MYSQL_Connect) 
		SQL_FreeHandle(MYSQL_Connect);
}

public SQL_LoadDebug() {
	new szError[MAX_PLAYERS * 16];
	new iErrorCode;
	
	MYSQL_Tuple = SQL_MakeDbTuple(SQL_HOST, SQL_USER, SQL_PASSWORD, SQL_DATABASE);
	MYSQL_Connect = SQL_Connect(MYSQL_Tuple, iErrorCode, szError, charsmax(szError));
	
	if(MYSQL_Connect == Empty_Handle)
		set_fail_state(szError);
	
	if(!SQL_TableExists(MYSQL_Connect, SQL_TABLENAME)) {
		new Handle:hQueries;
		new szQuery[MAX_PLAYERS * 16];
		
		formatex( szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (SteamID VARCHAR(32) CHARACTER SET cp1250 COLLATE cp1250_general_ci NOT NULL, Lifes INT NOT NULL, PRIMARY KEY (SteamID))", SQL_TABLENAME);
		hQueries = SQL_PrepareQuery(MYSQL_Connect, szQuery);
		
		if(!SQL_Execute(hQueries)) {
			SQL_QueryError(hQueries, szError, charsmax(szError));
			set_fail_state(szError);
		}

		SQL_FreeHandle(hQueries);
	}

	SQL_QueryAndIgnore(MYSQL_Connect, "SET NAMES utf8");
}

public SQL_Query(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], iParamsSize) {
	switch(iState) {
		case TQUERY_CONNECT_FAILED: log_amx("Load - Could not connect to SQL database. [%d] %s", iErrorCode, szError)
		case TQUERY_QUERY_FAILED: log_amx("Load Query failed. [%d] %s", iErrorCode, szError)
	}
	
	new pPlayer = iParams[0];
	UserLoaded[pPlayer] = true;
	
	g_iUserLifes[pPlayer] = amxx_get_user_lifes(pPlayer);

	if(SQL_NumResults(hQuery) < 1) {
		if(equal(UserSteamID[pPlayer], "ID_PENDING"))
			return PLUGIN_HANDLED;

		formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `%s` (`SteamID`, `Lifes`) VALUES ('%s', '%d');", SQL_TABLENAME, UserSteamID[pPlayer], g_iUserLifes[pPlayer]);
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
		
		return PLUGIN_HANDLED;
	}
	else 
		g_iUserLifes[pPlayer] = SQL_ReadResult(hQuery, 1);
	
	return PLUGIN_HANDLED;
}

public LoadData(pPlayer) {
	if(!is_user_connected(pPlayer))
		return;
	
	new iParams[1];
	iParams[0] = pPlayer;
	
	get_user_authid(pPlayer, UserSteamID[pPlayer], charsmax(UserSteamID[]));
	
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT * FROM `%s` WHERE (`%s`.`SteamID` = '%s')", SQL_TABLENAME, SQL_TABLENAME, UserSteamID[pPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Query", g_szQuery, iParams, sizeof iParams);

	set_task(1.0, "SetUserData", pPlayer);
}

public SetUserData(pPlayer) 
	amxx_set_user_lifes(pPlayer, g_iUserLifes[pPlayer]);

public SQL_Thread(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], iParamsSize) {
	if(iState == 0)
		return;
	
	log_amx("SQL Error: %d (%s)", iErrorCode, szError);
}

stock bool: SQL_TableExists(Handle: hDataBase, const szTable[]) {
	new Handle: hQuery = SQL_PrepareQuery(hDataBase, "SELECT * FROM information_schema.tables WHERE table_name = '%s' LIMIT 1;", szTable);
	new szError[MAX_PLAYERS * 16];
	
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
