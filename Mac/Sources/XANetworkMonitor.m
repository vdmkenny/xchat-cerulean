/* XANetworkMonitor.m
 *
 * See XANetworkMonitor.h.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>

#include <time.h>

#include "xchat.h"
#include "xchatc.h"
#include "server.h"
#include "fe.h"

#include "XANetworkMonitor.h"

/* Updates arrive about once at startup and then only when something really
 * changes, so there is no need to work out what changed: any update with a
 * usable route is worth acting on. The guard is only there to stop a burst
 * of updates turning into a burst of pings. */
#define XA_MIN_SECONDS_BETWEEN_CHECKS 3

static nw_path_monitor_t monitor = NULL;
static dispatch_queue_t monitor_queue = NULL;

/* Touched on the monitor queue only. */
static BOOL have_baseline = NO;
static time_t last_check = 0;

/* Runs on the main thread. Everything it touches is xchat state, which is
 * single threaded and belongs to the run loop. */
static void route_changed (void)
{
    for (GSList *list = serv_list; list; list = list->next)
    {
        server *serv = (server *) list->data;

        if (serv->connected || serv->connecting || !serv->server_session)
            continue;

        /* A backoff timer was waiting for a network that has just arrived,
         * so drop it and try now. */
        if (serv->recondelay_tag)
        {
            fe_timeout_remove (serv->recondelay_tag);
            serv->recondelay_tag = 0;
        }

        serv->connect (serv, serv->hostname, serv->port, FALSE);
    }

    /* Connections that were up before the change may be attached to a route
     * that no longer exists. Pinging now means the timeout notices within
     * one interval instead of up to two. */
    lag_check ();
}

void xa_network_monitor_start (void)
{
    if (monitor != NULL)
        return;

    monitor_queue = dispatch_queue_create ("dev.vdmkenny.xchatcerulean.network",
                                           DISPATCH_QUEUE_SERIAL);
    monitor = nw_path_monitor_create ();

    nw_path_monitor_set_queue (monitor, monitor_queue);
    nw_path_monitor_set_update_handler (monitor, ^(nw_path_t path) {
        /* The first update describes the route already in use, so it is a
         * baseline rather than a change. */
        if (!have_baseline)
        {
            have_baseline = YES;
            return;
        }

        /* Nothing to reconnect to until there is a usable route again. */
        if (nw_path_get_status (path) != nw_path_status_satisfied)
            return;

        time_t now = time (NULL);
        if (now - last_check < XA_MIN_SECONDS_BETWEEN_CHECKS)
            return;
        last_check = now;

        dispatch_async (dispatch_get_main_queue (), ^{
            route_changed ();
        });
    });

    nw_path_monitor_start (monitor);
}

void xa_network_monitor_stop (void)
{
    if (monitor == NULL)
        return;

    nw_path_monitor_cancel (monitor);
    nw_release (monitor);
    monitor = NULL;

    dispatch_release (monitor_queue);
    monitor_queue = NULL;

    have_baseline = NO;
    last_check = 0;
}
