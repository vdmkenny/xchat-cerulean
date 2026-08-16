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

/* LogViewWindow.m
 * Correspond to main menu: Window -> Log List...
 */

#include <sys/stat.h>

#include "cfgfiles.h"

#import "LogViewWindow.h"
#import "XALayout.h"

@interface LogItem : NSObject
{
    NSString *filename;
}

@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) NSString *contents;

+ (LogItem *)logWithFilename:(NSString *)filename;
- (BOOL)filter:(NSString *)filter;

@end

@implementation LogItem
@synthesize filename;

- (void) dealloc
{
    [filename release];
    [super dealloc];
}

+ (LogItem *) logWithFilename:(NSString *)aFilename {
    LogItem *log = [[self alloc] init];
    if ( log != nil ) {
        log->filename = [aFilename retain];
    }
    return [log autorelease];
}

- (BOOL) filter:(NSString *)filter
{
    if (filter == nil || [filter length] == 0)
        return YES;
    NSRange where = [filename rangeOfString:filter options:NSCaseInsensitiveSearch];
    return where.location != NSNotFound;
}


- (NSString *) path
{
    return [NSString stringWithFormat:@"%s/xchatlogs/%@", get_xdir_fs (), filename];
}

- (NSString *) contents
{    
    int fd = open ([[self path] fileSystemRepresentation], O_RDONLY);
    
    struct stat sb;
    fstat (fd, &sb);
    
    char *buff = (char *) malloc ((size_t)sb.st_size + 1);
    
    char *ptr = buff;
    
    while ((read (fd, ptr, (size_t)sb.st_size - (ptr - buff))) > 0)
        ;
    buff[sb.st_size] = 0;
    
    NSString *contents = @(buff);
    
    free(buff);
    
    return contents;
}

@end

#pragma mark -

@implementation LogViewWindow

- (void)LogViewWindowInit {
    filteredLogs = [[NSMutableArray alloc] init];
    allLogs = [[NSMutableArray alloc] init];
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self LogViewWindowInit];
    return self;
}

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    [self LogViewWindowInit];
    return self;
}

- (void) dealloc
{
    [filteredLogs release];
    [allLogs release];
    [super dealloc];
}

- (void) awakeFromNib
{
    [self setTitle:NSLocalizedStringFromTable(@"Log Viewer", @"xchataqua", @"Title of Window: MainMenu->Window->Log List")];
    [self setTabTitle:NSLocalizedStringFromTable(@"logviewer", @"xchataqua", @"Title of Tab: MainMenu->Window->Log List")];
    
#if 0
    [logTextView setPalette:[[AquaChat sharedAquaChat] palette]];
    [logTextView setFont:[[AquaChat sharedAquaChat] font]
                boldFont:[[AquaChat sharedAquaChat] boldFont]];
#endif
    
    [self refreshList:nil];
}

/* The nib stacks the controls down the left of the log text at fixed
 * frames. This puts the list and its controls in one column, the log in the
 * other, and lets the divider between them be dragged. */
static NSButton *XAButtonForAction(NSView *root, SEL action)
{
    for (NSView *child in [root subviews]) {
        if (![child isKindOfClass:[NSButton class]]) continue;
        if ([(NSButton *)child action] == action) return (NSButton *)child;
    }
    return nil;
}

static void XAAddArranged(NSStackView *stack, NSView *view)
{
    if (view == nil) return;
    [[view retain] autorelease];
    [view removeFromSuperview];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:view];
}

- (void)modernizeContents
{
    [super modernizeContents];

    NSScrollView *listScroll = [logTableView enclosingScrollView];
    NSScrollView *textScroll = [logTextView enclosingScrollView];
    if (listScroll == nil || textScroll == nil) return;

    NSButton *refresh = XAButtonForAction(self, @selector(refreshList:));
    NSButton *openIn = XAButtonForAction(self, @selector(openInTextEdit:));
    NSButton *reveal = XAButtonForAction(self, @selector(revealInFinder:));

    NSStackView *controls = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 8.0;
    controls.alignment = NSLayoutAttributeCenterY;
    XAAddArranged(controls, refresh);
    XAAddArranged(controls, filterSearchField);
    [filterSearchField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *actions = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
    actions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    actions.spacing = 8.0;
    actions.alignment = NSLayoutAttributeCenterY;
    XAAddArranged(actions, openIn);
    XAAddArranged(actions, reveal);

    /* Absorbs the slack so the row sits against the leading edge rather than
     * being centred under the list. */
    NSView *spacer = [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow - 1
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    [actions addArrangedSubview:spacer];

    NSStackView *column = [[[NSStackView alloc] initWithFrame:NSZeroRect] autorelease];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.spacing = 10.0;
    column.alignment = NSLayoutAttributeWidth;
    [column addArrangedSubview:controls];
    XAAddArranged(column, listScroll);
    [column addArrangedSubview:actions];
    [listScroll setContentHuggingPriority:NSLayoutPriorityDefaultLow
                           forOrientation:NSLayoutConstraintOrientationVertical];

    [[textScroll retain] autorelease];
    [textScroll removeFromSuperview];
    textScroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSSplitView *split = [[[NSSplitView alloc] initWithFrame:[self bounds]] autorelease];
    split.vertical = YES;
    split.dividerStyle = NSSplitViewDividerStyleThin;
    [split addSubview:column];
    [split addSubview:textScroll];
    [split setHoldingPriority:NSLayoutPriorityDefaultHigh forSubviewAtIndex:0];
    [split setHoldingPriority:NSLayoutPriorityDefaultLow forSubviewAtIndex:1];

    NSStackView *root = [[[NSStackView alloc] initWithFrame:[self bounds]] autorelease];
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.edgeInsets = NSEdgeInsetsMake(14.0, 20.0, 16.0, 20.0);
    root.alignment = NSLayoutAttributeWidth;
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addArrangedSubview:split];

    [self addSubview:root];
    [[column.widthAnchor constraintGreaterThanOrEqualToConstant:260.0] setActive:YES];
}

#pragma mark Private method

- (void) removeSelectedLogFiles
{
    if (![SGAlert confirmWithString:NSLocalizedStringFromTable(@"Are you sure you want to remove the selected log files?", @"xchataqua", @"Alert message at: MainMenu->Window->Log List")])
        return;
    
    NSIndexSet *set = [logTableView selectedRowIndexes];
    if (set == nil)
        return;
    
    NSInteger row = [set firstIndex];
    while (row != NSNotFound)
    {
        LogItem *logItem = filteredLogs[row];
        unlink([[logItem path] fileSystemRepresentation]);
        row = [set indexGreaterThanIndex:row];
    }
    
    [logTableView deselectAll:nil];
    [self refreshList:nil];
}

#pragma mark IBActions

- (void) doFilter:(id)sender
{
    [filteredLogs removeAllObjects];
    
    NSString *filter = [filterSearchField stringValue];
    
    for (NSUInteger i = 0; i < [allLogs count]; i ++)
    {
        LogItem *log = allLogs[i];
        if ([log filter:filter])
            [filteredLogs addObject:log];
    }
    
    [logTableView reloadData];
}


- (void) revealInFinder:(id)sender
{
    NSInteger row = [logTableView selectedRow];
    if (row < 0) return;
    LogItem *log = filteredLogs[row];
    [[NSWorkspace sharedWorkspace] selectFile:[log path] inFileViewerRootedAtPath:@""];
}

- (void) openInTextEdit:(id)sender
{
    NSIndexSet *set = [logTableView selectedRowIndexes];
    if (!set)
        return;
    
    NSInteger row = [set firstIndex];
    while (row != NSNotFound)
    {
        LogItem *log = filteredLogs[row];
        // Let the system pick the handler for a .log file rather than
        // hardcoding TextEdit.
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[log path]]];
        row = [set indexGreaterThanIndex:row];
    }
}

- (void) refreshList:(id)sender
{
    [allLogs removeAllObjects];
    
    NSString *dir = [NSString stringWithFormat:@"%s/xchatlogs", get_xdir_fs ()];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dir];
    for (NSString *filename = [enumerator nextObject]; filename != nil; filename = [enumerator nextObject])
    {
        if ([filename compare:@".DS_Store"] == NSOrderedSame)
            continue;
        
        [allLogs addObject:[LogItem logWithFilename:filename]];
    }
    
    [self doFilter:nil];
}

#pragma mark NSTableView dataSource

- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView {
    return [filteredLogs count];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    LogItem *item = filteredLogs[rowIndex];
    
    switch ([[aTableView tableColumns] indexOfObjectIdenticalTo:aTableColumn])
    {
        case 0: return [item filename];
    }
    
    dassert(NO);
    return @"";
}

- (void) tableViewSelectionDidChange:(NSNotification *) aNotification
{
    NSString *contents = @"";
    
    NSInteger row = [logTableView selectedRow];
    if (row >= 0 && [logTableView numberOfSelectedRows] == 1)
    {
        LogItem *logItem = filteredLogs[row];
        contents = [logItem contents];
    }
    
    [logTextView setString:contents];
}

@end

#pragma mark -

@interface LogTableView : NSTableView

@end

@implementation LogTableView

- (void) keyDown:(NSEvent *) event 
{ 
    if ( [self selectedRow] < 0 ) return;
    
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    NSUInteger flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (key == NSDeleteCharacter && flags == 0) 
    { 
        [(LogViewWindow *)[self delegate] removeSelectedLogFiles];
    }
    else
    { 
        [super keyDown:event];
    } 
} 

@end
