/* XALayout.h
 *
 * Turns nib layouts that position their children by frame into stack views,
 * so windows pick up current macOS spacing without every nib being rebuilt.
 */

#import <Cocoa/Cocoa.h>

/* Replaces box with a stack view holding its children, ordered by frame along
 * the given axis. Children listed in expanding take the leftover space; the
 * rest keep their current size along the axis. Returns the new stack, or nil
 * if box has no superview. */
NSStackView *XAStackFromBox(NSView *box,
                            NSUserInterfaceLayoutOrientation orientation,
                            CGFloat spacing,
                            NSEdgeInsets insets,
                            NSArray *expanding);

/* Groups a view's children into rows by their vertical position, converts
 * each row to a horizontal stack, and stacks the rows vertically inside the
 * view. Use for nibs whose children are positioned individually rather than
 * grouped into boxes. */
void XAModernizeFlatLayout(NSView *root,
                           NSEdgeInsets insets,
                           CGFloat rowSpacing,
                           CGFloat columnSpacing,
                           NSArray *expanding);

/* Removes the bezel from a scroll view and gives its table current row
 * metrics, matching what stock macOS lists look like. */
void XAModernizeScrollView(NSScrollView *scrollView);

/* Applies XAModernizeScrollView to every scroll view under root. */
void XAModernizeScrollViewsInTree(NSView *root);

/* Puts a vibrant sidebar behind a scroll view, the way a stock source list
 * sits on the window's material. The scroll view is moved into a container
 * that takes its place, so this works wherever it sits. */
void XAApplySidebarMaterial(NSScrollView *scrollView);

/* Re-spaces rows of buttons that the nib left touching, anchored to whichever
 * edge of their container they sit closest to. Views laid out by a stack view
 * are left alone. */
void XASpaceOutButtonRows(NSView *root, CGFloat spacing);
