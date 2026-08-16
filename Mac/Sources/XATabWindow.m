//
//  XATabWindow.m
//  XChatAqua
//
//  Created by Jeong YunWon on 12. 6. 14..
//  Copyright (c) youknowone.org All rights reserved.
//

#import "XATabWindow.h"
#import "XATabView.h"
#import "AquaChat.h"
#import "ColorPalette.h"

@implementation XATabWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
    contentRect = NSMakeRect(prefs.mainwindow_left, prefs.mainwindow_top, prefs.mainwindow_width, prefs.mainwindow_height);

    self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    if (self != nil) {
        // The content view lays itself out manually and has no constraints
        // tying it below the titlebar, so it must not extend under it.
        self.titlebarAppearsTransparent = NO;
        self.toolbarStyle = NSWindowToolbarStyleUnified;

        [self installToolbar];
        [self makeKeyAndOrderFront:self];
    }
    return self;
}

#pragma mark Toolbar

static NSString * const XAToolbarIdentifier   = @"XAMainToolbar2";
static NSString * const XAToolbarChannelList  = @"toggleChannelList";
static NSString * const XAToolbarUserList     = @"toggleUserList";
static NSString * const XAToolbarSidebarSplit = @"sidebarSeparator";
static NSString * const XAToolbarNetworks     = @"networks";
static NSString * const XAToolbarJoinChannel  = @"joinChannel";
static NSString * const XAToolbarChannelWindow = @"channelWindow";
static NSString * const XAToolbarSearch       = @"search";
static NSString * const XAToolbarPreferences  = @"preferences";

/* Deferred a turn so the channel list exists: the tracking separator needs
 * the split view it aligns with. */
- (void)installToolbar {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:XAToolbarIdentifier] autorelease];
        toolbar.delegate = self;
        toolbar.displayMode = NSToolbarDisplayModeIconOnly;
        toolbar.allowsUserCustomization = YES;
        toolbar.autosavesConfiguration = YES;
        self.toolbar = toolbar;
    });
}

/* Actions are sent down the responder chain, so they reach AquaChat the same
 * way the equivalent menu items do. */
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)identifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    NSString *symbol = nil, *label = nil;
    SEL action = NULL;

    if ([identifier isEqualToString:XAToolbarSidebarSplit]) {
        NSSplitView *splitView = self.tabView.channelSplitView;
        if (splitView == nil || [[splitView subviews] count] < 2)
            return nil;
        return [NSTrackingSeparatorToolbarItem trackingSeparatorToolbarItemWithIdentifier:identifier
                                                                               splitView:splitView
                                                                            dividerIndex:0];
    }

    if ([identifier isEqualToString:XAToolbarChannelList]) {
        symbol = @"sidebar.left";
        label = NSLocalizedStringFromTable(@"Channels", @"xchataqua", @"Toolbar item");
        action = @selector(toggleChannelList:);
    } else if ([identifier isEqualToString:XAToolbarUserList]) {
        symbol = @"sidebar.right";
        label = NSLocalizedStringFromTable(@"Users", @"xchataqua", @"Toolbar item");
        action = @selector(toggleUserList:);
    } else if ([identifier isEqualToString:XAToolbarNetworks]) {
        symbol = @"network";
        label = NSLocalizedStringFromTable(@"Networks", @"xchataqua", @"Toolbar item");
        action = @selector(showNetworkWindow:);
    } else if ([identifier isEqualToString:XAToolbarJoinChannel]) {
        symbol = @"plus.bubble";
        label = NSLocalizedStringFromTable(@"Join Channel", @"xchataqua", @"Toolbar item");
        action = @selector(openNewChannel:);
    } else if ([identifier isEqualToString:XAToolbarChannelWindow]) {
        symbol = @"list.bullet";
        label = NSLocalizedStringFromTable(@"Channel List", @"xchataqua", @"Toolbar item");
        action = @selector(showChannelWindow:);
    } else if ([identifier isEqualToString:XAToolbarSearch]) {
        symbol = @"magnifyingglass";
        label = NSLocalizedStringFromTable(@"Search", @"xchataqua", @"Toolbar item");
        action = @selector(showSearchPanel:);
    } else if ([identifier isEqualToString:XAToolbarPreferences]) {
        symbol = @"gearshape";
        label = NSLocalizedStringFromTable(@"Settings", @"xchataqua", @"Toolbar item");
        action = @selector(showPreferencesWindow:);
    } else {
        return nil;
    }

    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    item.label = label;
    item.paletteLabel = label;
    item.toolTip = label;
    item.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label];
    item.target = nil;
    item.action = action;
    return item;
}

/* The channel list toggle sits over the sidebar and the user list toggle at
 * the trailing edge, each above the pane it hides. */
- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[XAToolbarChannelList,
             XAToolbarSidebarSplit,
             XAToolbarNetworks,
             XAToolbarJoinChannel,
             XAToolbarChannelWindow,
             NSToolbarFlexibleSpaceItemIdentifier,
             XAToolbarSearch,
             XAToolbarPreferences,
             XAToolbarUserList];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[XAToolbarChannelList,
             XAToolbarSidebarSplit,
             XAToolbarUserList,
             XAToolbarNetworks,
             XAToolbarJoinChannel,
             XAToolbarChannelWindow,
             XAToolbarSearch,
             XAToolbarPreferences,
             NSToolbarFlexibleSpaceItemIdentifier,
             NSToolbarSpaceItemIdentifier];
}

- (XATabView *)tabView {
    return (id)self.contentView;
}

- (void) performClose:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        [(id<XATabWindowDelegate>)[self delegate] windowCloseTab:self];
    } else {
        [super performClose:sender];
    }
}

- (void)close {
    [NSApp terminate:self]; // this prevent parting!
}

- (void)applyPreferences:(id)sender {
    [self.tabView applyPreferences:sender];
}

@end
