#pragma warning disable 239

#include <a_samp>
#include <a_mysql>
#include <zcmd>
#include <string>
#include <streamer>
#include <colors>
#include <sscanf2>

#define MAX_FACTIONS   10

enum FactionInfo 
{
    fID,
    fName[255],
    fLeaderID,
    fType,
    // ... other faction properties 
}

new FactionData[MAX_FACTIONS][FactionInfo];
new PlayerFaction[MAX_PLAYERS];
new PlayerRank[MAX_PLAYERS]; 
new MySQL:g_SQL;

CreateFaction(factionName[], factionType[], leaderid)
{
    // 1. Validate input (check for existing names)
    new query[256], existingFactionCheck[128];
    mysql_format(g_SQL, existingFactionCheck, sizeof(existingFactionCheck), "SELECT `id` FROM `factions` WHERE `name` = '%s'", factionName);
    
    // Check if the faction already exists
    mysql_tquery(g_SQL, existingFactionCheck, "OnFactionCheckExists", "ssi", factionName, factionType, leaderid);
    
    return 1; // Return if faction created successfully or validation failed
}

forward OnFactionCheckExists(result[], playerid, factionName[], factionType[], leaderid);
public OnFactionCheckExists(result[], playerid, factionName[], factionType[], leaderid)
{
    // Check if there are results from the query
    if (cache_num_rows(result) > 0)
    {
        SendClientMessage(playerid, COLOR_RED, "A faction with this name already exists.");
        return 0; // Stop execution if the faction exists
    }

    // 2. Insert into the 'factions' table
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "INSERT INTO `factions` (`name`, `leader`, `type`) VALUES ('%s', %d, '%s')", factionName, leaderid, factionType);
    
    // Using the new function to retrieve the last inserted ID
    mysql_tquery(g_SQL, query, "OnFactionCreateSuccess", "ii", playerid, leaderid);
    return 1; 
}

AddPlayerToFaction(playerid, factionId, rank) 
{
    // 1. Validation: 
    if (PlayerFaction[playerid] != -1) // Check if player is already in a faction
    {
        SendClientMessage(playerid, COLOR_RED, "You are already in a faction.");
        return 0;
    }

    // Check if the faction exists
    if (factionId < 0 || factionId >= MAX_FACTIONS || FactionData[factionId][fID] == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "This faction does not exist.");
        return 0;
    }

    // 2. Update the 'faction_members' table
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), "INSERT INTO `faction_members` (`accountId`, `factionId`, `rank`) VALUES (%d, %d, %d)", playerid, factionId, rank);
    mysql_tquery(g_SQL, query);

    // 3. Update player's faction and rank in-game
    PlayerFaction[playerid] = factionId;
    PlayerRank[playerid] = rank;

    SendClientMessage(playerid, COLOR_GREEN, "You have been added to the faction.");
    return 1; 
}

forward OnFactionCreateSuccess(result[], playerid, leaderAccountID);
public OnFactionCreateSuccess(result[], playerid, leaderAccountID)
{
    // 3. Get the last inserted faction ID
    new factionId = mysql_insert_id(g_SQL);
    new memberQuery[256];
    
    // Add the leader to 'faction_members'
    mysql_format(g_SQL, memberQuery, sizeof(memberQuery), "INSERT INTO `faction_members` (`accountId`, `factionId`, `rank`) VALUES (%d, %d, 1)", leaderAccountID, factionId);
    mysql_tquery(g_SQL, memberQuery); // Add leader as a member with a default rank of 1

    // 4. Load faction data into your FactionData array
    // Assuming FactionData is a global array defined for faction storage
    FactionData[factionId][fName] = factionName;
    FactionData[factionId][fType] = factionType;
    FactionData[factionId][fLeaderID] = leaderAccountID;

    SendClientMessage(playerid, COLOR_GREEN, "Faction created successfully!");
    return 1; 
}

CMD:createfaction(playerid, params[])
{
    // Example admin check and parameter parsing
    if (!IsPlayerAdmin(playerid)) return 0; // Replace with your admin check

    // Assume params is formatted like "FactionName FactionType"
    new factionName[255], factionType[32];
    sscanf(params, "s s", factionName, factionType);

    CreateFaction(playerid, factionName, factionType, playerid); // Assuming leader is the player creating 
    return 1;
}
