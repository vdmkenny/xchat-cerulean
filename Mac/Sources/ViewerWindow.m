/* X-Chat Aqua
 * Copyright (C) 2011 Iphary
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

/* ViewerWindow.m
 * This is called 'Internal viewer' in application.
 * Correspond GUI: Right click URL on text -> Open with internal viewer
 */

#import "ViewerWindow.h"
#import "Branding.h"

@implementation ViewerWindow

- (void)dealloc
{
    [_webContent release];
    [super dealloc];
}

/* Lazily builds the web view inside the container supplied by the nib. */
- (WKWebView *)webContent
{
    if (_webContent == nil && webView != nil) {
        WKWebViewConfiguration *configuration = [[[WKWebViewConfiguration alloc] init] autorelease];

        _webContent = [[WKWebView alloc] initWithFrame:webView.bounds
                                         configuration:configuration];
        _webContent.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _webContent.allowsBackForwardNavigationGestures = YES;

        [webView addSubview:_webContent];
    }
    return _webContent;
}

- (void)showURL:(NSURL *)URL {
    [self setTitle:[NSString stringWithFormat:@"%s: Viewer / %@",
                    XA_PRODUCT_SHORT, [URL absoluteString]]];
    [[self webContent] loadRequest:[NSURLRequest requestWithURL:URL]];
}

@end
