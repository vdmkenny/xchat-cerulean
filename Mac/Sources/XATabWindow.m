//
//  XATabWindow.m
//  XChatAqua
//
//  Created by Jeong YunWon on 12. 6. 14..
//  Copyright (c) youknowone.org All rights reserved.
//

#import "XATabWindow.h"
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

        [self makeKeyAndOrderFront:self];
    }
    return self;
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
