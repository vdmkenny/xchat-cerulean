/* XALayout.m
 *
 * See XALayout.h.
 */

#import "XALayout.h"

NSStackView *XAStackFromBox(NSView *box,
                            NSUserInterfaceLayoutOrientation orientation,
                            CGFloat spacing,
                            NSEdgeInsets insets,
                            NSArray *expanding)
{
    NSView *parent = [box superview];
    if (box == nil || parent == nil) return nil;

    BOOL vertical = (orientation == NSUserInterfaceLayoutOrientationVertical);
    BOOL flipped = [box isFlipped];

    NSArray *ordered = [[box subviews] sortedArrayUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        CGFloat av, bv;
        if (vertical) {
            /* A stack fills top to bottom; unflipped, the topmost view has
             * the largest y. */
            av = flipped ? NSMinY(a.frame) : -NSMinY(a.frame);
            bv = flipped ? NSMinY(b.frame) : -NSMinY(b.frame);
        } else {
            av = NSMinX(a.frame);
            bv = NSMinX(b.frame);
        }
        if (av < bv) return NSOrderedAscending;
        if (av > bv) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSStackView *stack = [[[NSStackView alloc] initWithFrame:box.frame] autorelease];
    stack.orientation = orientation;
    stack.spacing = spacing;
    stack.edgeInsets = insets;
    stack.distribution = NSStackViewDistributionFill;
    stack.alignment = vertical ? NSLayoutAttributeWidth : NSLayoutAttributeHeight;
    stack.autoresizingMask = box.autoresizingMask;
    stack.translatesAutoresizingMaskIntoConstraints = YES;

    NSLayoutConstraintOrientation axis = vertical ? NSLayoutConstraintOrientationVertical
                                                  : NSLayoutConstraintOrientationHorizontal;
    NSLayoutConstraintOrientation across = vertical ? NSLayoutConstraintOrientationHorizontal
                                                    : NSLayoutConstraintOrientationVertical;

    for (NSView *child in ordered) {
        CGFloat extent = vertical ? NSHeight(child.frame) : NSWidth(child.frame);
        BOOL grows = [expanding containsObject:child];

        [[child retain] autorelease];
        [child removeFromSuperview];
        child.translatesAutoresizingMaskIntoConstraints = NO;
        [stack addArrangedSubview:child];

        [child setContentHuggingPriority:(grows ? NSLayoutPriorityDefaultLow
                                                : NSLayoutPriorityDefaultHigh)
                          forOrientation:axis];

        if (!grows && extent > 0.0) {
            NSLayoutConstraint *pin = vertical
                ? [child.heightAnchor constraintEqualToConstant:extent]
                : [child.widthAnchor constraintEqualToConstant:extent];
            pin.priority = NSLayoutPriorityDefaultHigh;
            pin.active = YES;
        }

        /* Across the stack the children must be free to shrink so their
         * content width does not become a floor for the whole window. */
        [child setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                        forOrientation:across];

        /* A hidden view should not reserve a gap. */
        if ([child isHidden])
            [stack setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible forView:child];
    }

    /* Every row spans the column. The stack's own alignment loses to a row
     * that hugs its content, which leaves a row sized to its widest control
     * and parked against one edge, so constrain the widths outright. */
    if (vertical) {
        CGFloat sideInsets = insets.left + insets.right;
        for (NSView *child in [stack arrangedSubviews]) {
            NSLayoutConstraint *fullWidth =
                [child.widthAnchor constraintEqualToAnchor:stack.widthAnchor
                                                  constant:-sideInsets];
            fullWidth.priority = NSLayoutPriorityRequired - 1;
            fullWidth.active = YES;
        }
    }

    [stack setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    [stack setContentHuggingPriority:NSLayoutPriorityDefaultLow
                      forOrientation:NSLayoutConstraintOrientationHorizontal];

    [parent replaceSubview:box with:stack];
    return stack;
}

/* Empty view that takes whatever width is left over. */
static NSView *XASpacerView(void)
{
    NSView *spacer = [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow - 1
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    [spacer setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow - 1
                                     forOrientation:NSLayoutConstraintOrientationHorizontal];
    return spacer;
}

/* Two views belong to the same row when their vertical spans overlap. Nib
 * layouts rarely align baselines exactly, so this compares ranges rather
 * than origins. */
static NSArray *XARowsFromSubviews(NSView *root)
{
    NSArray *ordered = [[root subviews] sortedArrayUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        /* Unflipped coordinates, so the topmost view has the largest y. */
        CGFloat av = [root isFlipped] ? NSMinY(a.frame) : -NSMaxY(a.frame);
        CGFloat bv = [root isFlipped] ? NSMinY(b.frame) : -NSMaxY(b.frame);
        if (av < bv) return NSOrderedAscending;
        if (av > bv) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableArray *rows = [NSMutableArray array];
    NSMutableArray *current = nil;
    CGFloat rowMin = 0.0, rowMax = 0.0;

    for (NSView *view in ordered) {
        NSRect frame = [view frame];
        if (current != nil && NSMinY(frame) < rowMax && NSMaxY(frame) > rowMin) {
            [current addObject:view];
            rowMin = MIN(rowMin, NSMinY(frame));
            rowMax = MAX(rowMax, NSMaxY(frame));
            continue;
        }

        current = [NSMutableArray arrayWithObject:view];
        [rows addObject:current];
        rowMin = NSMinY(frame);
        rowMax = NSMaxY(frame);
    }

    return rows;
}

void XAModernizeFlatLayout(NSView *root,
                           NSEdgeInsets insets,
                           CGFloat rowSpacing,
                           CGFloat columnSpacing,
                           NSArray *expanding)
{
    if (root == nil || [[root subviews] count] == 0) return;

    /* Already rebuilt. */
    if ([[root subviews] count] == 1 && [[root subviews][0] isKindOfClass:[NSStackView class]])
        return;

    NSArray *rows = XARowsFromSubviews(root);

    /* A tall view beside short controls means the nib is laid out in columns,
     * not rows, and grouping by vertical overlap would put a whole panel on
     * the same line as a button. Those layouts are left alone. */
    for (NSArray *row in rows) {
        if ([row count] < 2) continue;

        CGFloat shortest = CGFLOAT_MAX, tallest = 0.0;
        for (NSView *view in row) {
            CGFloat height = NSHeight([view frame]);
            shortest = MIN(shortest, height);
            tallest = MAX(tallest, height);
        }
        if (shortest > 0.0 && tallest / shortest > 2.5) return;
    }

    NSStackView *column = [[[NSStackView alloc] initWithFrame:[root bounds]] autorelease];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.spacing = rowSpacing;
    column.edgeInsets = insets;
    column.distribution = NSStackViewDistributionFill;
    column.alignment = NSLayoutAttributeWidth;
    column.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    column.translatesAutoresizingMaskIntoConstraints = YES;

    for (NSArray *row in rows) {
        NSView *rowView;
        CGFloat rowHeight = 0.0;
        BOOL rowGrows = NO;

        for (NSView *view in row) {
            rowHeight = MAX(rowHeight, NSHeight([view frame]));
            if ([expanding containsObject:view]) rowGrows = YES;
        }

        if ([row count] == 1) {
            rowView = row[0];
            [[rowView retain] autorelease];
            [rowView removeFromSuperview];
        } else {
            NSArray *sorted = [row sortedArrayUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
                if (NSMinX(a.frame) < NSMinX(b.frame)) return NSOrderedAscending;
                if (NSMinX(a.frame) > NSMinX(b.frame)) return NSOrderedDescending;
                return NSOrderedSame;
            }];

            NSStackView *rowStack = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
            rowStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            rowStack.spacing = columnSpacing;
            rowStack.distribution = NSStackViewDistributionFill;
            rowStack.alignment = NSLayoutAttributeCenterY;

            CGFloat previousEdge = -1.0;
            NSView *previousView = nil;
            BOOL rowFills = NO;

            for (NSView *view in sorted) {
                NSRect frame = [view frame];
                BOOL grows = [expanding containsObject:view];
                CGFloat gap = NSMinX(frame) - previousEdge;

                /* A wide gap in the nib separates groups, such as a label on
                 * the left from controls on the right. Narrow gaps are just
                 * spacing and are replaced by the stack's own. */
                if (previousEdge >= 0.0 && gap > columnSpacing * 2.0) {
                    [rowStack addArrangedSubview:XASpacerView()];
                    previousView = nil;
                    rowFills = YES;
                } else if (previousView != nil && gap <= 2.0 &&
                           NSWidth(frame) <= 34.0 && NSWidth([previousView frame]) <= 34.0) {
                    /* Small controls drawn touching are one set, such as a
                     * pair of add and remove buttons, and stay joined. Wider
                     * buttons that happen to abut are just a crowded nib. */
                    [rowStack setCustomSpacing:0.0 afterView:previousView];
                }
                previousEdge = NSMaxX(frame);
                previousView = view;

                [[view retain] autorelease];
                [view removeFromSuperview];
                view.translatesAutoresizingMaskIntoConstraints = NO;
                [rowStack addArrangedSubview:view];

                [view setContentHuggingPriority:(grows ? NSLayoutPriorityDefaultLow
                                                       : NSLayoutPriorityDefaultHigh)
                                 forOrientation:NSLayoutConstraintOrientationHorizontal];

                if (!grows && NSWidth(frame) > 0.0) {
                    NSLayoutConstraint *pin = [view.widthAnchor constraintEqualToConstant:NSWidth(frame)];
                    pin.priority = NSLayoutPriorityDefaultHigh;
                    pin.active = YES;
                }
                if (grows) rowFills = YES;
            }

            /* Without something to absorb the slack a short row is centred,
             * which reads as an accident next to a full-width list. */
            if (!rowFills)
                [rowStack addArrangedSubview:XASpacerView()];

            rowView = rowStack;
        }

        rowView.translatesAutoresizingMaskIntoConstraints = NO;
        [column addArrangedSubview:rowView];

        [rowView setContentHuggingPriority:(rowGrows ? NSLayoutPriorityDefaultLow
                                                     : NSLayoutPriorityDefaultHigh)
                            forOrientation:NSLayoutConstraintOrientationVertical];

        if (!rowGrows && rowHeight > 0.0) {
            NSLayoutConstraint *pin = [rowView.heightAnchor constraintEqualToConstant:rowHeight];
            pin.priority = NSLayoutPriorityDefaultHigh;
            pin.active = YES;
        }
    }

    [root addSubview:column];
}

void XAModernizeScrollView(NSScrollView *scrollView)
{
    if (scrollView == nil) return;

    scrollView.borderType = NSNoBorder;
    scrollView.drawsBackground = NO;
    scrollView.automaticallyAdjustsContentInsets = YES;

    NSView *document = [scrollView documentView];

    /* A text area with no bezel at all reads as empty space, so it keeps a
     * filled, rounded background the way current text fields do. */
    if ([document isKindOfClass:[NSTextView class]]) {
        scrollView.drawsBackground = YES;
        scrollView.backgroundColor = [NSColor textBackgroundColor];
        scrollView.wantsLayer = YES;
        scrollView.layer.cornerRadius = 6.0;
        scrollView.layer.borderWidth = 1.0;
        scrollView.layer.borderColor = [[NSColor separatorColor] CGColor];
        ((NSTextView *)document).textContainerInset = NSMakeSize(6.0, 6.0);
        return;
    }

    if (![document isKindOfClass:[NSTableView class]]) return;

    NSTableView *table = (NSTableView *)document;
    table.style = NSTableViewStyleInset;
    table.intercellSpacing = NSMakeSize(6.0, 3.0);
    table.usesAlternatingRowBackgroundColors = NO;
    table.gridStyleMask = NSTableViewGridNone;
    if (table.rowHeight < 20.0)
        table.rowHeight = 22.0;

    /* The nib widths predate the current header font, so titles arrive
     * truncated to an ellipsis. Widen anything narrower than its own
     * heading, then spread the leftover width across the columns rather
     * than leaving it as dead space on the right. */
    NSDictionary *headerAttributes =
        @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]};

    for (NSTableColumn *column in [table tableColumns]) {
        NSString *title = [[column headerCell] stringValue];
        if ([title length] == 0) continue;

        CGFloat needed = ceil([title sizeWithAttributes:headerAttributes].width) + 18.0;
        if (column.minWidth < needed) column.minWidth = needed;
        if (column.width < needed) column.width = needed;
    }

    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;

    /* Deferred a turn: this runs while the nib is still loading, so the
     * table does not have its final width yet and would spread the columns
     * over the wrong total. */
    [table retain];
    dispatch_async(dispatch_get_main_queue(), ^{
        [table sizeToFit];
        [table release];
    });
}

void XAModernizeScrollViewsInTree(NSView *root)
{
    if (root == nil) return;

    if ([root isKindOfClass:[NSScrollView class]])
        XAModernizeScrollView((NSScrollView *)root);

    for (NSView *child in [root subviews])
        XAModernizeScrollViewsInTree(child);
}
