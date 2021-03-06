//
//  GHInstallViewController.m
//  GhostSKB
//
//  Created by mingxin.ding on 2018/10/9.
//  Copyright © 2018 丁明信. All rights reserved.
//

#import "GHInstallViewController.h"
#import "GHKeybindingManager.h"
#import "GHInputSourceManager.h"
#import "GHDefaultManager.h"
#import "NSAttributedString+Hyperlink.h"

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#define SYMBOLICHOTKEYS @"com.apple.symbolichotkeys.plist"
#define SOURCE_SCRIPT_FILE @"switch_scpt"
#define DEST_SCRIPT_FILE @"switch"

@interface GHInstallViewController ()

@end

@implementation GHInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    [self updateShortCutStatus];
    [self initLinkLabel];
}

- (void)initLinkLabel {
    NSLocale *locale = [NSLocale currentLocale];
    NSString *readmeStr = @"README.md";
    if([locale.languageCode isEqualToString:@"en"]) {
        readmeStr = @"README_en.md";
    }
    
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/dingmingxin/GhostSKB/blob/v%@/%@", version, readmeStr]];
    
    
    self.readmeLabel.stringValue = [NSAttributedString hyperlinkFromString:NSLocalizedString(@"label_please_read_readme", @"") withURL:url];
}

- (void)updateShortCutStatus {
    self.readBtn.title = NSLocalizedString(@"btn_text_read_shortcuts", @"");
    NSString *switchKey = [GHDefaultManager getInstance].switchKey;
    if(switchKey != nil && switchKey.length > 0) {
        self.shortcutStatusLabel.textColor = [NSColor greenColor];
        self.shortcutStatusLabel.stringValue = @"DONE";
    }
    else {
        self.shortcutStatusLabel.textColor = [NSColor redColor];
        self.shortcutStatusLabel.stringValue = @"TODO";
    }
}

- (BOOL)checkSwitchScriptInstalled {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    NSURL *directoryURL = [fileManager URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSURL *scriptFileUrl = [directoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.scpt", DEST_SCRIPT_FILE]];
    if([fileManager fileExistsAtPath:[scriptFileUrl path]]) {
        return TRUE;
    }
    return FALSE;
}

- (void)doInstallScript {
    NSError *error;
    NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setDirectoryURL:directoryURL];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    [openPanel setPrompt:@"Select Script Folder"];

    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *selectedURL = [openPanel URL];
            if ([selectedURL isEqual:directoryURL]) {
                NSURL *destinationURL = [selectedURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.scpt", DEST_SCRIPT_FILE]];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSURL *sourceURL = [[NSBundle mainBundle] URLForResource:SOURCE_SCRIPT_FILE withExtension:@"txt"];
                
                NSError *error;
                BOOL success = false;
                if([fileManager fileExistsAtPath:[destinationURL path]]) {
                    NSString *fileName = [NSString stringWithFormat:@"%@.txt", SOURCE_SCRIPT_FILE];
                    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                    if([fileManager fileExistsAtPath:tmpPath]) {
                        [fileManager removeItemAtPath:tmpPath error:NULL];
                    }
                    [fileManager copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:tmpPath] error:NULL];
                    
                    //replaceItemAtURL is a move action
                    success = [fileManager replaceItemAtURL:destinationURL withItemAtURL:[NSURL fileURLWithPath:tmpPath] backupItemName:NULL options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:&error];
                }
                else {
                    success = [fileManager copyItemAtURL:sourceURL toURL:destinationURL error:&error];
                }
                
                
                if (success) {
                    NSAlert *alert = [[NSAlert alloc] init];
                    alert.messageText = @"Script Installed";
                    [alert addButtonWithTitle:@"OK"];
                    [alert setInformativeText:@"The Switch script was installed succcessfully."];
                    [alert runModal];
                
                    // NOTE: This is a bit of a hack to get the Application Scripts path out of the next open or save panel that appears.
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSNavLastRootDirectory"];
                }
                else {
                    NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
                }
            }
        }
    }];
    
    
}

//- (IBAction)installScript:(id)sender {
//    if(true) {
//        [self doInstallScript];
//        return;
//    }
//}

- (IBAction)getSystemShortcuts:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libDir = [dirs objectAtIndex:0];
    [panel setDirectoryURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/Preferences/%@", libDir, SYMBOLICHOTKEYS]]];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:@[@"plist"]];
    panel.delegate = self;
    
    NSWindow *window = self.view.window;
    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if(result != NSFileHandlingPanelOKButton) {
            return;
        }
        for (NSURL *url in [panel URLs]) {
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:url];
            NSPropertyListFormat plistFormat;
            NSDictionary *dict = (NSDictionary *)[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&plistFormat error:&error];
            if (!error) {
                //                NSLog(@"plist dict: %@", dict);
                NSString *switchKey = [self readShortcutFromDict:dict];
                [GHInputSourceManager getInstance].switchModifierStr = switchKey;
                [[GHDefaultManager getInstance] updateSwitchKey:switchKey];
                [self updateShortCutStatus];
                break;
            }
            
        }
    }];
}

- (NSString *)readShortcutFromDict:(NSDictionary *)dict {
    NSDictionary* hotKeys = dict[@"AppleSymbolicHotKeys"];
    if (!hotKeys) {
        return nil;
    }
    NSDictionary *hotKey = hotKeys[@"60"];
    if (!hotKey) {
        return nil;
    }
    
    NSNumber *enabled = hotKey[@"enabled"];
    if ([enabled intValue] != 1) {
        NSLog(@"hot key not enabled");
        return nil;
    }
    
    NSDictionary *value = hotKey[@"value"];
    NSArray *parameters = value[@"parameters"];
    if (!parameters) {
        return nil;
    }
    
    NSUInteger keyCode = [parameters[1] unsignedIntegerValue];
    NSUInteger modifier = [parameters[2] unsignedIntegerValue];
    
    return [self generateModifierStr:keyCode withModifier:modifier];
}

- (NSString *)generateModifierStr:(NSUInteger)keyCode withModifier:(NSUInteger)modifier {
    NSMutableArray *modifiers = [[NSMutableArray alloc] initWithCapacity:3];
    if (modifier & NSEventModifierFlagCommand) {
        [modifiers insertObject:@"command" atIndex:0];
    }
    if(modifier & NSEventModifierFlagControl) {
        [modifiers insertObject:@"control" atIndex:0];
    }
    if(modifier & NSEventModifierFlagOption) {
        [modifiers insertObject:@"option" atIndex:0];
    }
    if (modifier & NSEventModifierFlagShift) {
        [modifiers insertObject:@"shift" atIndex:0];
    }
    
    NSString *modifierStr = [modifiers componentsJoinedByString:@"_"];
    return modifierStr;
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    if ([url.path containsString:SYMBOLICHOTKEYS]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (IBAction)gotoReadme:(id)sender {
}
@end
