/* X-Chat Aqua
 * Copyright (C) 2002 Steve Green
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA */

#include <Carbon/Carbon.h>
#include <dlfcn.h>

#include "cfgfiles.h"

#import "AquaChat.h"
#import "ColorPalette.h"
#import "SGGuiUtility.h"
#import "XATabView.h"
#import "TabOrWindowView.h"

/* Below this the channel list is not usefully readable. */
static const CGFloat XAMinimumSidebarWidth = 150.0;

//! @abstract   Cell of each row of outline tab mode
@interface XATabViewOutlineCell : NSTextFieldCell {
    BOOL _hasCloseButton;
    NSButtonCell *closeCell; // not shown now...
    NSImage *_icon;
}

@property (nonatomic, assign) BOOL hasCloseButton;
@property (nonatomic, retain) NSImage *icon;

@end

NSImage *XATabViewOutlineCellCloseImage;

@implementation XATabViewOutlineCell
@synthesize hasCloseButton=_hasCloseButton;
@synthesize icon=_icon;

+ (void)initialize {
    if (self == [XATabViewOutlineCell class]) {
        XATabViewOutlineCellCloseImage = [[NSImage imageNamed:@"close.tiff"] retain];
    }
}

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:aString];
    if (self != nil) {
        closeCell = [[NSButtonCell alloc] initImageCell:XATabViewOutlineCellCloseImage];
        [closeCell setButtonType:NSButtonTypeMomentaryLight];
        [closeCell setImagePosition:NSImageOnly];
        [closeCell setBordered:NO];
        [closeCell setHighlightsBy:NSContentsCellMask];
    }
    return self;
}

- (void) dealloc
{
    [closeCell release];
    [_icon release];
    [super dealloc];
}

- (id) copyWithZone:(NSZone *) zone
{
    XATabViewOutlineCell *copy = [super copyWithZone:zone];
    copy->closeCell = [closeCell copyWithZone:zone];
    copy->_icon = [_icon retain];
    return copy;
}

- (void)performClose:(id)sender {
    [[closeCell target] performSelector:[closeCell action]];
}

- (NSRect) calculateCloseRectWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect r;
    
    r.size = XATabViewOutlineCellCloseImage.size;
    r.origin.x = cellFrame.origin.x;
    r.origin.y = cellFrame.origin.y + floor ((cellFrame.size.height - r.size.height) / 2);
    
    return r;
}

- (void) drawInteriorWithFrame:(NSRect) cellFrame inView:(NSView *) controlView
{
    NSRect closeRect = NSZeroRect;

    if (self.hasCloseButton) {
        closeRect = [self calculateCloseRectWithFrame:cellFrame inView:controlView];
        cellFrame.origin.x += closeRect.size.width + 2.0f;
    }

    /* Leading symbol, the way a Finder source list row is laid out. */
    if (self.icon != nil) {
        const CGFloat side = 15.0;
        const CGFloat gap = 6.0;
        NSRect iconRect = NSMakeRect(cellFrame.origin.x,
                                     cellFrame.origin.y + floor((cellFrame.size.height - side) / 2.0),
                                     side, side);

        [self.icon drawInRect:iconRect
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];

        cellFrame.origin.x += side + gap;
        cellFrame.size.width -= side + gap;
    }

    [super drawInteriorWithFrame:cellFrame inView:controlView];

    // Gotta draw the icon last because highlighted cells have a
    // blue background which will cover the image otherwise.                  
    if (self.hasCloseButton) {
        [closeCell drawInteriorWithFrame:closeRect inView:controlView];
    }
}

- (BOOL)mouseDown:(NSEvent *)theEvent cellFrame:(NSRect)cellFrame controlView:(NSView *)controlView
      closeAction:(SEL)closeAction closeTarget:(id)closeTarget {
    if (!self.hasCloseButton) {
        return NO;
    }

    [closeCell setAction:closeAction];
    [closeCell setTarget:closeTarget];
        
    NSPoint point = [theEvent locationInWindow];
    NSPoint where = [controlView convertPoint:point fromView:nil];
    NSRect closeRect = [self calculateCloseRectWithFrame:cellFrame inView:controlView];
        
    if (NSPointInRect (where, closeRect))
    {
        [SGGuiUtility trackButtonCell:closeCell withEvent:theEvent inRect:closeRect controlView:controlView];
        return YES;
    }
    
    return NO;
}

@end

#pragma mark -

//! @abstract   Channel view for outline tab mode
@interface XATabViewOutlineView : NSOutlineView<XAEventChain>

- (void)selectRowForTabViewItem:(XATabViewItem *)tabViewItem;
- (NSRect) frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row;

@end

@implementation XATabViewOutlineView

- (BOOL) acceptsFirstResponder
{
    return NO;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row {
  NSRect superFrame = [super frameOfCellAtColumn:column row:row];
  id item = [self itemAtRow:row];

  if (column == 0 && [item isKindOfClass:[XATabViewItem class]]) {
      return NSMakeRect(10, superFrame.origin.y, [self bounds].size.width - 10, superFrame.size.height);
  }
  return superFrame;
}

// Grab mouse down and deal with the close button without selecting
// the item.  We have to find the item, the column, and the data cell.
// If all the classes look right, we'll call the delegate to prep the
// cell and then let the cell deal with tracking the close button.
// (if it has one).
- (void) mouseDown:(NSEvent *) theEvent
{
    NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:where];
    NSInteger col = [self columnAtPoint:where];
    
    if (row >= 0 && col >= 0)
    {
        id item = [self itemAtRow:row];

        if ([item isKindOfClass:[XATabViewItem class]])
        {
            NSTableColumn *tableColumn = [self tableColumns][col];
            XATabViewOutlineCell *cell = [tableColumn dataCell];
            
            if ([cell isKindOfClass:[XATabViewOutlineCell class]])
            {
                [[self delegate] outlineView:self willDisplayCell:cell forTableColumn:tableColumn item:item];
                if ([cell mouseDown:theEvent 
                          cellFrame:[self frameOfCellAtColumn:col row:row]
                        controlView:self
                        closeAction:@selector(performClose:)
                        closeTarget:item])
                {
                    return;
                }
            }
        }
    }
    
    [super mouseDown:theEvent];
}

- (NSMenu *) menuForEvent:(NSEvent *) theEvent
{
    NSPoint where = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:where];
    NSInteger col = [self columnAtPoint:where];
    
    if (row >= 0 && col >= 0)
    {
        id item = [self itemAtRow:row];

        if ([item isKindOfClass:[XATabViewItem class]]) {
            return ((XATabViewItem *)item)->contextMenu;
        }
    }
    
    return [super menuForEvent:theEvent];
}

/*
 * Applies the currently set preferences when changed
 *
 * When the user presses "Apply" or "Ok" in the Preferences window,
 * applyPreferences: is called to actually make them live. Mostly this matters
 * for fonts and colors and other visually apparent changes.
 *
 * The call chain for this is a bit fuzzy: not sure how it's propogated to
 * every object that needs it.
 *
 */
- (void)applyPreferences:(id)sender {
    CGFloat fontSize = prefs.style_namelistgad ? [AquaChat sharedAquaChat].font.pointSize * 0.9 : [NSFont smallSystemFontSize];
    if (prefs.tab_small) {
        fontSize *= 0.86;
    }
    NSFont *font = [NSFont systemFontOfSize:fontSize];
    XATabViewOutlineCell *dataCell = [(self.tableColumns)[0] dataCell];
    dataCell.font = font;
    
    NSLayoutManager *layoutManager=[[NSLayoutManager new] autorelease];
    /* Sidebar rows are roomier than table rows; 28pt is the Finder metric. */
    CGFloat lineHeight = [layoutManager defaultLineHeightForFont:font];
    [self setRowHeight:MAX(round(lineHeight * 1.7) + 4, 28.0)];
    [self setIntercellSpacing:NSMakeSize(3.0, 2.0)];
    [self setIndentationPerLevel:12.0];
    
    // Source list styling: inset rounded selection, sidebar metrics.
    self.style = NSTableViewStyleSourceList;
    self.floatsGroupRows = NO;

    ColorPalette *p = [[AquaChat sharedAquaChat] palette];
    if (prefs.style_namelistgad) {
        dataCell.textColor = [p getColor:XAColorForeground];
        self.backgroundColor = [p getColor:XAColorBackground];
        [self setSidebarMaterialEnabled:NO];
    } else {
        dataCell.textColor = [NSColor textColor];
        // Let the vibrant sidebar material behind the list show through.
        [self setSidebarMaterialEnabled:YES];
    }
    [self setNeedsDisplay:YES];
}

/* Places a vibrant sidebar behind the list, the way a stock source list sits
 * on the window's material. */
- (void)setSidebarMaterialEnabled:(BOOL)enabled {
    NSScrollView *scrollView = [self enclosingScrollView];
    if (scrollView == nil) return;

    if (!enabled) {
        self.backgroundColor = [NSColor textBackgroundColor];
        scrollView.drawsBackground = YES;
        return;
    }

    self.backgroundColor = [NSColor clearColor];
    scrollView.drawsBackground = NO;

    NSView *parent = scrollView.superview;

    /* Once wrapped the parent is the container, so this runs only the first
     * time. A sibling of the split view would become a third pane, so the
     * material goes behind the list inside a container that takes its place
     * as the pane. */
    if (![parent isKindOfClass:[NSSplitView class]]) return;

    for (NSView *sibling in [[[parent subviews] copy] autorelease]) {
        if ([sibling isKindOfClass:[NSVisualEffectView class]])
            [sibling removeFromSuperview];
    }

    /* Remember the pane that follows the list so the container can be put
     * back in the same slot rather than appended after the conversation. */
    NSArray *panes = [parent subviews];
    NSInteger paneIndex = [panes indexOfObject:scrollView];
    NSView *nextPane = (paneIndex != NSNotFound && paneIndex + 1 < (NSInteger)[panes count])
        ? panes[paneIndex + 1] : nil;

    NSRect paneFrame = [scrollView frame];

    NSView *container = [[[NSView alloc] initWithFrame:paneFrame] autorelease];
    container.autoresizingMask = [scrollView autoresizingMask];

    NSVisualEffectView *material =
        [[[NSVisualEffectView alloc] initWithFrame:[container bounds]] autorelease];
    material.material = NSVisualEffectMaterialUnderWindowBackground;
    material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    material.state = NSVisualEffectStateInactive;
    material.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    [[scrollView retain] autorelease];
    [scrollView removeFromSuperview];
    [scrollView setFrame:[container bounds]];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [container addSubview:material];
    [container addSubview:scrollView];

    if (nextPane != nil)
        [parent addSubview:container positioned:NSWindowBelow relativeTo:nextPane];
    else
        [parent addSubview:container];

    [parent resizeSubviewsWithOldSize:[parent frame].size];
}

- (void)selectRowForTabViewItem:(XATabViewItem *)tabViewItem {
    NSInteger row = [self rowForItem:tabViewItem];
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

@end

#pragma mark -


@implementation XATabViewGroup
@synthesize tabItems=_tabItems;
@synthesize name=_name;
@synthesize identifier=_identifier;

- (id)initWithIdentifier:(NSInteger)identifier {
    self = [super init];
    if (self != nil) {
        _tabItems = [[NSMutableArray alloc] init];
        _identifier = identifier;
    }
    return self;
}

- (void) dealloc
{
    self.name = nil;
    [_tabItems release];
    [super dealloc];
}

@end

#pragma mark -

//! @abstract   Button for tab mode

#pragma mark -

NSNib *XATabViewItemTabMenuNib;

@implementation XATabViewItem
@synthesize view=_view;
@synthesize label=_label;
@synthesize groupIdentifier=_groupIdentifier;
@synthesize tabView=_tabView;
@synthesize titleColorIndex=_titleColorIndex;
@synthesize initialFirstResponder=_initialFirstResponder;

+ (void)initialize {
    if (self == [XATabViewItem class]) {
        XATabViewItemTabMenuNib = [[NSNib alloc] initWithNibNamed:@"TabMenu" bundle:nil];
    }
}

- (id) initWithIdentifier:(id) identifier
{
    self = [super init];
    if (self != nil) {
        NSArray *topLevelObjects;
        [XATabViewItemTabMenuNib instantiateWithOwner:self topLevelObjects:&topLevelObjects];
        _topLevelObjects = [topLevelObjects retain];
        self->_titleColorIndex = XAColorForeground;
    }
    return self;
}

- (void) dealloc
{
    self.label = nil;
    self.view = nil;
    [contextMenu release];
    [super dealloc];
}

- (BOOL)isFrontTab {
    return self.tabView.selectedTabViewItem == self;
}

- (void)redrawTitle {
    [self.tabView.tabOutlineView reloadData];
}

- (NSColor *)titleColor {
    if (!prefs.style_namelistgad && self.titleColorIndex == XAColorForeground) {
        return [NSColor textColor];
    }
    return [[[AquaChat sharedAquaChat] palette] getColor:self.titleColorIndex];
}

- (void)setTitleColorIndex:(NSInteger)index {
    if (_titleColorIndex == index) return;
    self->_titleColorIndex = index;
    [self redrawTitle];
}

- (void)performClose:(id)sender {
    [(TabOrWindowView *)self.view close];
}

- (void)link_delink:(id)sender {
    if (self.tabView) {
        [self.tabView.delegate link_delink:self];
    }
}

- (void)performSelect:(id)sender {
    [self.tabView selectTabViewItem:self];
}

- (void)setLabel:(NSString *)label {
    [_label autorelease];
    _label = [label retain];
    
    [self redrawTitle];
}

- (void) setView:(NSView *)view
{
    [_view removeFromSuperview];
    [_view release];

    _view = [view retain];

    if ([self isFrontTab]) {
        self.tabView.chatView = view;
    }
}

@end

#pragma mark -

@implementation XATabView
@synthesize delegate=_delegate;
@synthesize tabOutlineView=_tabOutlineView;
@synthesize selectedTabViewItem=_selectedTabViewItem;
@synthesize tabViewItems=_tabViewItems;

- (void)XATabViewInit {
    self->_tabViewItems = [[NSMutableArray alloc] init];
    self->_groups = [[NSMutableArray alloc] init];
    [_chatViewContainer setMinorDefaultJustification:SGBoxMinorJustificationFull];
}

- (id) initWithFrame:(NSRect) frameRect
{
    self = [super initWithFrame:frameRect];
    if (self != nil) {
        [self XATabViewInit];
        [self makeOutline];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self XATabViewInit];
    return self;
}

- (void)awakeFromNib {
    [self makeOutline];
}

- (void)dealloc {
    self.chatView = nil;
    self.tabOutlineView = nil;
    [_tabViewItems release];
    [_groups release];
    [super dealloc];
}

- (void)applyPreferences:sender {
    [_tabOutlineView applyPreferences:sender];
    [self setOutlineWidth:prefs.xa_outline_width];
    [self redrawTabItems];
}

/* The list is inside a material container that fills the pane, so the width
 * is stored and the split view laid out again rather than resizing the
 * scroll view, which the container would immediately override. */
- (void) setOutlineWidth:(CGFloat) width
{
    prefs.xa_outline_width = MAX(width, XAMinimumSidebarWidth);

    NSSplitView *splitView = self.channelSplitView;
    [splitView resizeSubviewsWithOldSize:[splitView frame].size];
}

- (id)chatView {
    return [[_chatViewContainer subviews] firstObject];
}

- (void)setChatView:(id)chatView {
    if (chatView == nil) return;
    while (_chatViewContainer.subviews.count > 0) {
        [(_chatViewContainer.subviews)[0] removeFromSuperview];
    }
    if (xchat_is_quitting) return; // optimization..?

    [chatView setFrame:_chatViewContainer.bounds];
    [_chatViewContainer addSubview:chatView];
    [_chatViewContainer setStretchView:chatView];
}

- (XATabViewGroup *)groupForIdentifier:(NSInteger)identifier {
    XATabViewGroup *group = nil;
    
    for (XATabViewGroup *aGroup in _groups) {
        if (aGroup.identifier == identifier) {
            group = aGroup;
            break;
        }
    }
    
    if (group == nil) {
        group = [[XATabViewGroup alloc] initWithIdentifier:identifier];
        [_groups addObject:group];
        [group release];
        
        [self redrawTabItems];
        [_tabOutlineView expandItem:group];
    }
    
    return group;
}

- (void)setName:(NSString *)name forGroup:(NSInteger)identifier {
    [[self groupForIdentifier:identifier] setName:name];
    [self redrawTabItems];
}

- (void) makeOutline
{
    [[_tabOutlineView enclosingScrollView] setFrameSize: NSMakeSize(prefs.xa_outline_width, self.frame.size.height)];
    
    [_tabOutlineView setOutlineTableColumn:(_tabOutlineView.tableColumns)[0]];
    [_tabOutlineView reloadData];
        
    for (XATabViewGroup *group in _groups) {
        [_tabOutlineView expandItem:group];
    }
    
    [_tabOutlineView selectRowForTabViewItem:self.selectedTabViewItem];
}


- (XATabViewItem *)tabViewItemAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.tabViewItems.count) return nil;
    return (self.tabViewItems)[index];
}

- (NSInteger) indexOfTabViewItem:(XATabViewItem *) tabViewItem
{
    return [self.tabViewItems indexOfObject:tabViewItem];
}

- (void) addTabViewItem:(XATabViewItem *) tabViewItem
{
    [self addTabViewItem:tabViewItem toGroup:0];
}

- (void)removeTabViewItem:(XATabViewItem *)tabViewItem {
    if (tabViewItem.tabView != self) return;
    
    [tabViewItem.view removeFromSuperview];
    tabViewItem.tabView = nil;

    if (_selectedTabViewItem == tabViewItem)
    {
        _selectedTabViewItem = nil;

        if (self.tabViewItems.count > 1 && !xchat_is_quitting) {
            // If there is another tab on the right of the tab being closed, and it's in the same group, choose it;
            // Else, if there is another tab on the left of the tab being closed, and it's in the same group, choose it;
            // Else, choose the tab on the right unless it's the last tab;
            // Else, choose the tab on the left.
            NSUInteger tabIndex = [self.tabViewItems indexOfObject:tabViewItem];
            NSUInteger lastTabIndex = self.tabViewItems.count - 1;
            NSUInteger selectedIndex;
            if (tabIndex < lastTabIndex && [(self.tabViewItems)[tabIndex + 1] groupIdentifier] == tabViewItem.groupIdentifier) {
                selectedIndex = tabIndex + 1;
            } else if (tabIndex > 0 && [(self.tabViewItems)[tabIndex - 1] groupIdentifier] == tabViewItem.groupIdentifier) {
                selectedIndex = tabIndex - 1;
            } else {
                selectedIndex = tabIndex == lastTabIndex ? tabIndex - 1 : tabIndex + 1;
            }
            [self selectTabViewItemAtIndex:selectedIndex];
        }
    }
    
    [_tabViewItems removeObject:tabViewItem];
    
    XATabViewGroup *group = [self groupForIdentifier:tabViewItem.groupIdentifier];
    [group.tabItems removeObject:tabViewItem];
    if (group.tabItems.count == 0) {
        [_groups removeObject:group];
    }
    
    if (xchat_is_quitting) return;

    [_tabOutlineView reloadData];
    // Removing items above the current item muck up the selected item in the outline
    [self.tabOutlineView selectRowForTabViewItem:self.selectedTabViewItem];
}

- (void) selectNextTabViewItem:(id)sender
{
    NSInteger n = [self indexOfTabViewItem:self.selectedTabViewItem] + 1;
    if (n < self.tabViewItems.count) {
        [self selectTabViewItemAtIndex:n];
    }
}

- (void) selectPreviousTabViewItem:(id)sender
{
    NSInteger n = [self indexOfTabViewItem:self.selectedTabViewItem] - 1;
    if (n >= 0) {
        [self selectTabViewItemAtIndex:n];
    }
}

- (void) selectTabViewItemAtIndex:(NSInteger) index
{
    [self selectTabViewItem:[self tabViewItemAtIndex:index]];
}

- (void)selectTabViewItem:(XATabViewItem *)tabViewItem {
    if (tabViewItem == _selectedTabViewItem) return;
    
    if (_selectedTabViewItem)
    {
        [_selectedTabViewItem.view removeFromSuperview];
    }

    self.chatView = tabViewItem.view;

    _selectedTabViewItem = tabViewItem;

    NSInteger row = [_tabOutlineView rowForItem:tabViewItem];
    [_tabOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    
    if (_selectedTabViewItem.view)
    {
        id responder = _selectedTabViewItem.initialFirstResponder;
        if (responder) {
            [[self window] makeFirstResponder:responder];
        }
    }
        
    if ([_delegate respondsToSelector:@selector(tabView:didSelectTabViewItem:)]) {
        [_delegate performSelector:@selector(tabView:didSelectTabViewItem:)
                        withObject:self
                        withObject:_selectedTabViewItem];
    }
    
    [_chatViewContainer layout_maybe];
}

- (BOOL) mouseDownCanMoveWindow
{
    return NO;
}

- (void)redrawTabItems {
    for (XATabViewItem *item in self.tabViewItems) {
        [item redrawTitle];
    }
    [self.tabOutlineView reloadData];
}

#define kBackgroundStyleGroup   0
#define kBackgroundStyleCL      1
#define kBackgroundStyleTheme   2
enum {
    kTabBorderInset = 9 /* the exact value which matches the NSBox look is 11; however, since we have very little space between the box and the window border, using 9 gives a better visual balance */
};
#define BACKGROUND_VERSION  kBackgroundStyleCL

#if BACKGROUND_VERSION == kBackgroundStyleTheme
typedef OSStatus 
    (*ThemeDrawSegmentProc)(
        const HIRect *                  inBounds,
        const HIThemeSegmentDrawInfo *  inDrawInfo,
        CGContextRef                    inContext,
        HIThemeOrientation              inOrientation);
#endif

- (void)addTabViewItem:(XATabViewItem *)tabViewItem toGroup:(NSInteger)groupIdentifier {
    if (self == tabViewItem.tabView) return;

    tabViewItem.tabView = self;
    tabViewItem.groupIdentifier = groupIdentifier;

    // In order for selectNext and selectPrevious to work, we need to add this item
    // in the correct order.  We'll also insert the tab button at the same position.
    
    NSUInteger index = 0;
    for (; index < self.tabViewItems.count; index ++) {
        XATabViewItem *tab = (self.tabViewItems)[index];
        if (tab.groupIdentifier == groupIdentifier) {
            index ++;
            break;
        }
    } // strat of matching group now
    for (; index < self.tabViewItems.count; index ++) {
        XATabViewItem *tab = (self.tabViewItems)[index];
        if (tab.groupIdentifier != groupIdentifier) {
            break;
        }
    } // end of matching group now

    [_tabViewItems insertObject:tabViewItem atIndex:index];
    
    XATabViewGroup *group = [self groupForIdentifier:tabViewItem.groupIdentifier];
    [group.tabItems addObject:tabViewItem];

    [_tabOutlineView reloadData];

    if (_selectedTabViewItem == nil) {
        [self selectTabViewItem:tabViewItem];
    }
}

#pragma mark NSOutlineViewDataSource

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil) {
        return _groups[index];
    }
        
    if ([item isKindOfClass:[XATabViewGroup class]]) {
        return [item tabItems][index];
    }
        
    // Not possible
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return [item isKindOfClass:[XATabViewGroup class]];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        return [_groups count];
    }
        
    if ([item isKindOfClass:[XATabViewGroup class]]) {
        return [[item tabItems] count];
    }
        
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if ([item isKindOfClass:[XATabViewGroup class]])
        return [item name];
        
    if ([item isKindOfClass:[XATabViewItem class]])
        return [item label];

    return @"";
}

/* A server is a section header, which a source list draws in its own style. */
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return ![item isKindOfClass:[XATabViewItem class]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return [item isKindOfClass:[XATabViewItem class]];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[XATabViewItem class]]) {
        [cell setTextColor:[item titleColor]];
        [cell setHasCloseButton:!prefs.xa_hide_tab_close_buttons];

        /* A channel, a conversation with one person, or the server tab. */
        NSString *label = [item respondsToSelector:@selector(label)] ? [item label] : nil;
        NSString *symbol = @"bubble.left";
        if ([label hasPrefix:@"#"] || [label hasPrefix:@"&"])
            symbol = @"number";
        else if ([label length] == 0 || [label isEqualToString:@"<none>"])
            symbol = @"bolt.horizontal";

        NSImage *icon = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label];
        icon.template = YES;
        [cell setIcon:icon];
    } else {
        // Server rows read as section headers, so they are quieter than a channel.
        [cell setTextColor:[NSColor secondaryLabelColor]];
        [cell setHasCloseButton:NO];
        [cell setIcon:nil];
    }
}

- (void) outlineViewSelectionDidChange:(NSNotification *) notification
{
    id item = [_tabOutlineView itemAtRow:[_tabOutlineView selectedRow]];
    if (item && [item isKindOfClass:[XATabViewItem class]]) {
        [self selectTabViewItem:item];
    }
}

#pragma mark - NSSplitView

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    CGFloat width = [[_tabOutlineView enclosingScrollView] frame].size.width;
    if (width >= XAMinimumSidebarWidth)
        prefs.xa_outline_width = width;
}

/* The channel list keeps its width and the conversation takes the rest.
 * Laying the panes out here rather than letting adjustSubviews share the
 * space keeps the list from being squeezed by whatever the conversation
 * side asks for. */
- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    NSArray *panes = [splitView subviews];
    if ([panes count] != 2) {
        [splitView adjustSubviews];
        return;
    }

    NSView *sidebar = panes[0];
    NSView *content = panes[1];
    NSSize size = [splitView frame].size;
    CGFloat divider = [splitView dividerThickness];

    CGFloat sidebarWidth = _channelListCollapsed
        ? 0.0 : MAX(prefs.xa_outline_width, XAMinimumSidebarWidth);

    // Never let the list crowd out the conversation on a narrow window.
    sidebarWidth = MIN(sidebarWidth, MAX(size.width - divider - 200.0, 0.0));

    [sidebar setFrame:NSMakeRect(0.0, 0.0, sidebarWidth, size.height)];
    [content setFrame:NSMakeRect(sidebarWidth + divider, 0.0,
                                 MAX(size.width - sidebarWidth - divider, 0.0),
                                 size.height)];
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMinCoordinate:(CGFloat)proposedMin
         ofSubviewAt:(NSInteger)dividerIndex
{
    return _channelListCollapsed ? 0.0 : XAMinimumSidebarWidth;
}

- (IBAction)toggleChannelList:(id)sender
{
    _channelListCollapsed = !_channelListCollapsed;

    /* adjustSubviews is the default proportional layout and does not consult
     * the delegate, so go through resizeSubviewsWithOldSize: to reach the
     * layout that honours the collapsed flag. */
    NSSplitView *splitView = self.channelSplitView;
    [splitView resizeSubviewsWithOldSize:[splitView frame].size];
    [splitView setNeedsDisplay:YES];
}

/* The list is wrapped in a material container, so this walks up rather than
 * assuming the scroll view's parent is the split view. */
- (NSSplitView *)channelSplitView
{
    NSView *view = [_tabOutlineView enclosingScrollView];
    while (view != nil && ![view isKindOfClass:[NSSplitView class]])
        view = [view superview];
    return (NSSplitView *)view;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    return YES;
}

@end
