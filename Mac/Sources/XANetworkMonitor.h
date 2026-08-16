/* XANetworkMonitor.h
 *
 * Watches the system's network path and reacts when the route changes.
 *
 * Sleep and wake are already handled, but they are only half the problem: a
 * Wi-Fi hop, a VPN coming up or going down, or an Ethernet cable being
 * plugged in leaves established sockets pointing at a route that no longer
 * works. Nothing notices until the ping timeout expires, which can be a
 * minute. Watching the path lets a reconnect start as soon as the route
 * settles.
 */

#ifndef XANETWORKMONITOR_H
#define XANETWORKMONITOR_H

#ifdef __cplusplus
extern "C" {
#endif

void xa_network_monitor_start (void);
void xa_network_monitor_stop (void);

#ifdef __cplusplus
}
#endif

#endif
