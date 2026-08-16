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
