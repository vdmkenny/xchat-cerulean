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

#import "SGAlert.h"

#pragma mark -

@implementation SGAlert

+ (void) doitWithStyle:(NSAlertStyle) style
               message:(NSString *)alertText
               andWait:(BOOL) wait
{
    /* Autoreleased: a copied block retains what it captures and releases it
     * again when the block is destroyed, so the handler must not release the
     * alert itself. */
    NSAlert *panel = [[[NSAlert alloc] init] autorelease];
    [panel setAlertStyle:style];
    [panel addButtonWithTitle:NSLocalizedStringFromTable(@"OK", @"libsg", @"button")];
    [panel setMessageText:alertText];

    NSWindow *parent = [NSApp keyWindow] ?: [NSApp mainWindow];

    if (wait || parent == nil)
    {
        [panel runModal];
    }
    else
    {
        // Sheet on the front window; does not block the caller.
        [panel beginSheetModalForWindow:parent completionHandler:^(NSModalResponse response) {
        }];
    }
}

+ (void) alertWithString:(NSString *)alertText andWait:(BOOL)wait
{
    [self doitWithStyle:NSAlertStyleWarning message:alertText andWait:wait];
}

+ (void) noticeWithString:(NSString *)alertText andWait:(BOOL)wait
{
    [self doitWithStyle:NSAlertStyleInformational message:alertText andWait:wait];
}

+ (void) errorWithString:(NSString *)alertText andWait:(BOOL) wait
{
    [self doitWithStyle:NSAlertStyleCritical message:alertText andWait:wait];
}

+ (BOOL) confirmWithString:(NSString *)alertText
{
    NSAlert *panel = [[NSAlert alloc] init];
    [panel addButtonWithTitle:NSLocalizedStringFromTable(@"No", @"libsg", @"button")];
    [panel addButtonWithTitle:NSLocalizedStringFromTable(@"Yes",@"libsg", @"button")];
    [panel setMessageText:alertText];
    [panel setAlertStyle:NSAlertStyleInformational];
    
    NSInteger ret = [panel runModal];
    [panel release];
    return ret == NSAlertSecondButtonReturn;
}

+ (void) confirmWithString:(NSString *)alertText
                    inform:(id) obj
                    yesSel:(SEL) yesSel
                     noSel:(SEL) noSel
{
    /* Autoreleased, and nothing is released inside the handler: a copied
     * block retains what it captures and releases it again when the block is
     * destroyed. Releasing there as well lands on freed memory, and the
     * answering selector may itself dispose of the target. */
    NSAlert *panel = [[[NSAlert alloc] init] autorelease];
    [panel addButtonWithTitle:NSLocalizedStringFromTable(@"No" ,@"libsg", @"button")];
    [panel addButtonWithTitle:NSLocalizedStringFromTable(@"Yes",@"libsg", @"button")];
    [panel setMessageText:alertText];
    [panel setAlertStyle:NSAlertStyleInformational];

    /* Ownership here is the caller's convention: fe_confirm() releases its
     * object as soon as this returns, and the answering selector releases it
     * once more. So take exactly one retain, and use a __block variable so
     * the block neither retains nor releases it. Retaining twice, or letting
     * the block release it as well, frees it under the selector. */
    __block id target = [obj retain];

    void (^report)(NSModalResponse) = ^(NSModalResponse response) {
        SEL selector = (response == NSAlertSecondButtonReturn) ? yesSel : noSel;
        if (selector != NULL && [target respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [target performSelector:selector];
#pragma clang diagnostic pop
        }
    };

    NSWindow *parent = [NSApp keyWindow] ?: [NSApp mainWindow];
    if (parent != nil) {
        [panel beginSheetModalForWindow:parent completionHandler:report];
    } else {
        report([panel runModal]);
    }
}

@end
