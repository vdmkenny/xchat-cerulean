//
//  xchatext.m
//  XChatAqua
//
//  Created by Jeong YunWon on 12. 6. 18..
//  Copyright (c) 2012 youknowone.org All rights reserved.
//

#import "SystemVersion.h"

#import "PluginManager.h"
#import "XAFileUtil.h"

#include "text.h"
#include "plugin.h"
#include "outbound.h"

char *get_xdir_fs(void) {
    static NSString *applicationSupportDirectory = nil;
    if (applicationSupportDirectory == nil) {
        applicationSupportDirectory = [[[XAFileUtil findSupportFolderFor:@PRODUCT_NAME] path] retain];
    }
    return (char *)[applicationSupportDirectory UTF8String];
}

char *get_appdir_fs(void) {
    return (char *)[[[NSBundle mainBundle] bundlePath] UTF8String];
}

char *get_downloaddir_fs(void) {
    static NSString *path = nil;
    if (path == nil) {
        path = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES)[0] retain];
    }
    char *path_alloc = malloc(sizeof(char) * (strlen(path.UTF8String) + 1));
    strncpy(path_alloc, path.UTF8String, path.length);
    return path_alloc;
}

char *get_plugin_bundle_path(char *filename) {
    NSString *bundlePath = @(filename);
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    if (bundle == nil) {
        return NULL;
    }
    
    NSString *version = [bundle infoDictionary][@"XChatAquaMacOSVersionBranch"];
    if(version != nil && [[SystemVersion systemBranch] compare:version options:NSNumericSearch] != NSOrderedSame) {
        return NULL;
    }
    
    NSString *path = [bundle executablePath];
    return (char *)[path fileSystemRepresentation];
}

void aqua_plugin_auto_load_item(struct session *ps, const char *filename) {
    /* Going through the command rather than calling the loader straight off
     * gives the script interpreters their chance to claim the file. They
     * hook LOAD, and a .rb or .pl is not something the binary loader can
     * open: it would report that the file is not a valid executable. The
     * path is quoted because it runs through the application bundle, whose
     * name contains a space. */
    char *command = g_strdup_printf ("load \"%s\"", filename);
    handle_command (ps, command, FALSE);
    g_free (command);
}

void aqua_plugin_auto_load(struct session *ps) {
    PluginFileManager *manager = [EmbeddedPluginManager sharedPluginManager];
    for (PluginItem *item in manager.items) {
        if ([manager hasAutoloadItem:item]) {
            aqua_plugin_auto_load_item(ps, item.filename.UTF8String);
        }
    }
    manager = [UserPluginManager sharedPluginManager];
    for (PluginItem *item in manager.items) {
        if ([manager hasAutoloadItem:item]) {
            aqua_plugin_auto_load_item(ps, item.filename.UTF8String);
        }
    }
}
