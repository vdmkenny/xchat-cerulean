/* XAScreenshot.h
 *
 * On-demand capture of the app's own windows, for development.
 *
 * This renders the view hierarchy in-process rather than reading the screen,
 * so it needs no Screen Recording permission and works over ssh or from a
 * terminal that has not been granted TCC access.
 *
 * Inert unless XA_SCREENSHOT_DIR is set in the environment. When it is,
 * sending SIGUSR1 writes a PNG of every visible window into that directory:
 *
 *     XA_SCREENSHOT_DIR=/tmp/shots ./XChat\ Cerulean.app/Contents/MacOS/...
 *     kill -USR1 $(pgrep -f 'XChat Cerulean')
 */

#ifndef XCHAT_CERULEAN_SCREENSHOT_H
#define XCHAT_CERULEAN_SCREENSHOT_H

void XAScreenshotInstallHandler (void);

#endif /* XCHAT_CERULEAN_SCREENSHOT_H */
