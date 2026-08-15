/* debug.h
 *
 * Minimal stand-in for the "cdebug" CocoaPod that XChat Aqua used to depend
 * on. Only dlog() and dassert() were ever used, so the pod (and CocoaPods
 * itself) is no longer worth carrying.
 *
 * dlog() takes a per-subsystem switch as its first argument so individual
 * areas can be made noisy without drowning in everything else.
 */

#ifndef XCHATAQUA_DEBUG_H
#define XCHATAQUA_DEBUG_H

#include <assert.h>

/* Per-subsystem switches for dlog(). Flip to 1 while debugging that area. */
#ifndef DEBUG_BOXVIEW
#define DEBUG_BOXVIEW 0
#endif

#if defined(DEBUG) && !defined(NDEBUG)

#define dassert(condition) assert(condition)

#ifdef __OBJC__
/* The format strings at the call sites are NSString literals. */
#define dlog(flag, ...)                       \
    do {                                      \
        if (flag) NSLog(__VA_ARGS__);         \
    } while (0)
#else
#define dlog(flag, ...) ((void)0)
#endif

#else /* release */

#define dassert(condition) ((void)0)
#define dlog(flag, ...) ((void)0)

#endif

#endif /* XCHATAQUA_DEBUG_H */
