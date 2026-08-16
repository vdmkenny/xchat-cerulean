/* XAScreenshot.m
 *
 * See XAScreenshot.h. Development aid; does nothing unless
 * XA_SCREENSHOT_DIR is set.
 */

#import <Cocoa/Cocoa.h>

#import "XAScreenshot.h"

static NSString *XAScreenshotDirectory (void)
{
    const char *dir = getenv ("XA_SCREENSHOT_DIR");
    if (dir == NULL || dir[0] == '\0') return nil;
    return [NSString stringWithUTF8String:dir];
}

/* Sanitised so a window title can be used as a filename. */
static NSString *XAScreenshotName (NSWindow *window, NSUInteger index)
{
    NSString *title = [window title];
    if ([title length] == 0)
        title = [NSString stringWithFormat:@"window-%lu", (unsigned long)index];

    NSCharacterSet *unsafe = [NSCharacterSet characterSetWithCharactersInString:@"/:\\?%*|\"<> "];
    NSArray *parts = [title componentsSeparatedByCharactersInSet:unsafe];
    return [[parts componentsJoinedByString:@"-"] lowercaseString];
}

static void XAScreenshotCaptureWindow (NSWindow *window, NSString *directory, NSUInteger index)
{
    /* The content view's superview is the frame view, so the titlebar and
     * toolbar are included rather than just the content. */
    NSView *view = [[window contentView] superview] ?: [window contentView];
    if (view == nil) return;

    NSRect bounds = [view bounds];
    if (NSIsEmptyRect (bounds)) return;

    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:bounds];
    if (rep == nil) return;

    [view cacheDisplayInRect:bounds toBitmapImageRep:rep];

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (png == nil) return;

    NSString *path = [directory stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.png", XAScreenshotName (window, index)]];

    NSError *error = nil;
    if (![png writeToFile:path options:NSDataWritingAtomic error:&error])
        NSLog (@"screenshot: could not write %@: %@", path, error);
    else
        NSLog (@"screenshot: wrote %@ (%.0fx%.0f)", path, NSWidth (bounds), NSHeight (bounds));
}

/* Frames of the whole hierarchy, so layout can be diagnosed from the
 * numbers rather than guessed at from a picture. */
static void XAScreenshotDumpView (NSView *view, NSMutableString *out, NSUInteger depth)
{
    NSRect f = [view frame];
    [out appendFormat:@"%*s%@ (%.0f,%.0f %.0fx%.0f)%@\n",
                      (int)(depth * 2), "",
                      NSStringFromClass ([view class]),
                      NSMinX (f), NSMinY (f), NSWidth (f), NSHeight (f),
                      [view isHidden] ? @" HIDDEN" : @""];

    for (NSView *child in [view subviews])
        XAScreenshotDumpView (child, out, depth + 1);
}

static void XAScreenshotDumpWindow (NSWindow *window, NSString *directory, NSUInteger index)
{
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"%@ frame=%@\n", [window title], NSStringFromRect ([window frame])];
    XAScreenshotDumpView ([window contentView], out, 0);

    NSString *path = [directory stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.tree.txt", XAScreenshotName (window, index)]];
    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

/* Opens every utility window so one capture run covers them all. Sent on
 * SIGUSR2; the actions are the same ones the menu bar sends. */
static void XAScreenshotOpenAllWindows (void)
{
    NSArray *actions = @[@"showPreferencesWindow:", @"showNetworkWindow:",
                         @"showAsciiWindow:", @"showIgnoreWindow:",
                         @"showFriendWindow:", @"showPluginWindow:",
                         @"showRawLogWindow:", @"showUrlGrabberWindow:",
                         @"showLogViewWindow:", @"showDccChatWindow:",
                         @"showDccReceiveWindow:", @"showDccSendWindow:",
                         @"showUserCommandsWindow:", @"showCtcpRepliesWindow:",
                         @"showUserlistButtonsWindow:", @"showUserlistPopupWindow:",
                         @"showDialogButtonsWindow:", @"showReplacePopupWindow:",
                         @"showUrlHandlersWindow:", @"showTextEventsWindow:",
                         @"showUserMenusWindow:"];

    for (NSString *name in actions) {
        SEL action = NSSelectorFromString (name);
        if (![NSApp sendAction:action to:nil from:nil])
            NSLog (@"screenshot: %@ went unhandled", name);
    }
}

static void XAScreenshotCaptureAll (void)
{
    NSString *directory = XAScreenshotDirectory ();
    if (directory == nil) return;

    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    NSUInteger index = 0;
    for (NSWindow *window in [NSApp windows]) {
        if (![window isVisible]) continue;
        XAScreenshotCaptureWindow (window, directory, index);
        XAScreenshotDumpWindow (window, directory, index);
        index++;
    }

    if (index == 0)
        NSLog (@"screenshot: no visible windows");
}

/* Forces one appearance so both can be captured without changing the system
 * setting. Set XA_APPEARANCE to light or dark. */
static void XAScreenshotApplyAppearance (void)
{
    const char *want = getenv ("XA_APPEARANCE");
    if (want == NULL || want[0] == '\0') return;

    NSString *name = (strcasecmp (want, "light") == 0) ? NSAppearanceNameAqua
                                                       : NSAppearanceNameDarkAqua;
    [NSApp setAppearance:[NSAppearance appearanceNamed:name]];
}

void XAScreenshotInstallHandler (void)
{
    if (XAScreenshotDirectory () == nil) return;

    XAScreenshotApplyAppearance ();

    /* The default action would kill us, and the dispatch source needs the
     * signal left unhandled by signal(2). */
    signal (SIGUSR1, SIG_IGN);
    signal (SIGUSR2, SIG_IGN);

    static dispatch_source_t capture = nil;
    capture = dispatch_source_create (DISPATCH_SOURCE_TYPE_SIGNAL, SIGUSR1, 0,
                                      dispatch_get_main_queue ());
    if (capture == nil) return;

    dispatch_source_set_event_handler (capture, ^{
        XAScreenshotCaptureAll ();
    });
    dispatch_resume (capture);

    static dispatch_source_t openAll = nil;
    openAll = dispatch_source_create (DISPATCH_SOURCE_TYPE_SIGNAL, SIGUSR2, 0,
                                      dispatch_get_main_queue ());
    if (openAll == nil) return;

    dispatch_source_set_event_handler (openAll, ^{
        XAScreenshotOpenAllWindows ();
    });
    dispatch_resume (openAll);

    NSLog (@"screenshot: SIGUSR1 captures windows into %@, SIGUSR2 opens them all",
           XAScreenshotDirectory ());
}
