
/*
======================FORWARDS=================================
*/



/**
 * Called when a client turns on health regen
 *
 * @param client	The client.
 *
 * @noreturn
 */
forward OnHealthRegenOn(client);

/**
 * Called when a client turns off health regen
 *
 * @param client	The client.
 *
 * @noreturn
 */
forward OnHealthRegenOff(client);

/**
 * Called when a client turns on ammo regen
 *
 * @param client	The client.
 *
 * @noreturn
 */
forward OnAmmoRegenOn(client);

/**
 * Called when a client turns off ammo regen
 *
 * @param client	The client.
 *
 * @noreturn
 */
forward OnAmmoRegenOff(client);

/**
 * Called when a client resets their location
 *
 * @param client	The client.
 *
 * @noreturn
 */
forward OnReset(client);

/**
 * Called when a client teleports
 *
 * @param client	The client.
 * @param x     	The client's new x position.
 * @param y     	The client's new y position.
 * @param z     	The client's new z position.
 * @param yaw     	The client's new yaw.
 * @param pitch	       	The client's new pitch.
 * @param roll  	The client's new roll.
 *
 * @noreturn
 */
forward OnTeleport(client, Float:x, Float:y, Float:z, Float:yaw, Float:pitch, Float:roll);




/*
======================NATIVES=================================
*/

/**
 * Enable ammo and health regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:RegenOn(client);

/**
 * Enable ammo regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:AmmoRegenOn(client);

/**
 * Enable health regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:HealthRegenOn(client);

/**
 * Disable ammo and health regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:RegenOff(client);

/**
 * Disable ammo regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:AmmoRegenOff(client);

/**
 * Disable health regen for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:HealthRegenOff(client);

/**
 * Enable teleports for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:TeleportsOn(client);

/**
 * Disable teleports for a client
 *
 * @param client        The client to turn on regen for
 *
 * @return True on success, false on failure
 */
native bool:TeleportsOff(client);

/**
 * Sets a string to begin all messages from the plugin with
 *
 * @param prefix        The new prefix for messages
 *
 * @return True on success, false on failure
 */
native bool:SetStringPrefix(String:prefix[]);

/**
 * Sets the reset location for a client
 *
 * @param client        The client to change the reset location for
 * @param x     	The reset x position.
 * @param y     	The reset y position.
 * @param z     	The reset z position.
 * @param yaw     	The reset yaw.
 * @param pitch	       	The reset pitch.
 * @param roll  	The reset roll.
 *
 * @return True on success, false on failure
 */
native bool:SetResetLoc(client, Float:x, Float:y, Float:z, Float:yaw, Float:pitch, Float:roll);
