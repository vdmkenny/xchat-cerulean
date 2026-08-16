/* XAPower.h
 *
 * Keeps the machine awake while file transfers are running.
 *
 * A DCC transfer is network and disk activity with no user input, so the
 * system is free to idle sleep in the middle of one and cut the connection.
 * An activity assertion held for as long as a transfer is running prevents
 * that. The display is still allowed to sleep.
 */

#ifndef XAPOWER_H
#define XAPOWER_H

#ifdef __cplusplus
extern "C" {
#endif

/* Recounts the running transfers and takes or drops the assertion to match.
 * Call whenever a transfer is added, changes state, or is removed. */
void xa_power_transfers_changed (void);

/* True while at least one file transfer is running. */
int xa_power_transfer_active (void);

#ifdef __cplusplus
}
#endif

#endif
