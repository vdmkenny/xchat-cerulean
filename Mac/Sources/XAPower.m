/* XAPower.m
 *
 * See XAPower.h.
 */

#import <Foundation/Foundation.h>

#include "xchat.h"
#include "xchatc.h"
#include "dcc.h"

#include "XAPower.h"

/* Held for as long as transfers are running, nil otherwise. */
static id<NSObject> activity = nil;

static int running_transfers (void)
{
    int count = 0;

    for (GSList *list = dcc_list; list; list = list->next)
    {
        struct DCC *dcc = (struct DCC *) list->data;

        /* Chat sessions carry no payload, so they do not justify keeping the
         * machine awake. */
        if (dcc->type != TYPE_SEND && dcc->type != TYPE_RECV)
            continue;

        if (dcc->dccstat == STAT_ACTIVE || dcc->dccstat == STAT_CONNECTING)
            count++;
    }

    return count;
}

int xa_power_transfer_active (void)
{
    return running_transfers () > 0;
}

void xa_power_transfers_changed (void)
{
    BOOL wanted = running_transfers () > 0;

    if (wanted && activity == nil)
    {
        /* NSActivityUserInitiated covers idle system sleep, sudden
         * termination and automatic termination. It deliberately leaves
         * display sleep alone. */
        activity = [[[NSProcessInfo processInfo]
                     beginActivityWithOptions:NSActivityUserInitiated
                                       reason:@"Transferring a file"] retain];
    }
    else if (!wanted && activity != nil)
    {
        [[NSProcessInfo processInfo] endActivity:activity];
        [activity release];
        activity = nil;
    }
}
