//
//  IGJSConsoleConnection.m
//  IGJavaScriptConsole
//
//  Created by Francis Chong on 1/11/14.
//  Copyright (c) 2014 Francis Chong. All rights reserved.
//
#import "GCDAsyncSocket.h"
#import "HTTPMessage.h"
#import "HTTPResponse.h"
#import "HTTPDynamicFileResponse.h"

#import "DDLog.h"
#import "IGJSConsoleConnection.h"
#import "IGJavaScriptEvaulatorWebSocket.h"
#import "IGJavaScriptConsoleServer.h"

#import "IGRubyEvaulatorWebSocket.h"

#undef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF jsConsoleLogLevel
static const int jsConsoleLogLevel = LOG_LEVEL_ERROR;

@implementation IGJSConsoleConnection

-(NSObject<HTTPResponse>*) httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    DDLogDebug(@"%@ %@", method, path);
    
    if ([path isEqualToString:@"/scripts/application.js"]) {
        // The /scripts/application.js file contains a URL template that needs to be completed:
        //
        // ws = new WebSocket("%%WEBSOCKET_URL%%");
        //
        // We need to replace "%%WEBSOCKET_URL%%" with whatever URL the server is running on.
        // We can accomplish this easily with the HTTPDynamicFileResponse class,
        // which takes a dictionary of replacement key-value pairs,
        // and performs replacements on the fly as it uploads the file.
        
        NSString *wsLocation;
        NSString *scheme = [asyncSocket isSecure] ? @"wss" : @"ws";
        NSString *wsHost = [request headerField:@"Host"];
        if (wsHost == nil) {
            NSString *port = [NSString stringWithFormat:@"%hu", [asyncSocket localPort]];
            wsLocation = [NSString stringWithFormat:@"%@://localhost:%@", scheme, port];
        } else {
            wsLocation = [NSString stringWithFormat:@"%@://%@", scheme, wsHost];
        }
        
        IGJavaScriptConsoleServer* server = (IGJavaScriptConsoleServer*) config.server;
        NSString* language = server.language == IGJavaScriptConsoleServerLanguageRuby ? @"ruby" : @"javascript";
        NSDictionary *replacementDict = @{
                                          @"WEBSOCKET_URL": wsLocation,
                                          @"LANGUAGE": language
                                        };
        
        return [[HTTPDynamicFileResponse alloc] initWithFilePath:[self filePathForURI:path]
                                                   forConnection:self
                                                       separator:@"%%"
                                           replacementDictionary:replacementDict];
    }

    return [super httpResponseForMethod:method URI:path];
}

- (WebSocket *)webSocketForURI:(NSString *)path {
    DDLogDebug(@"%@[%p]: webSocketForURI: %@", THIS_FILE, self, path);
    IGJavaScriptConsoleServer* server = (IGJavaScriptConsoleServer*) config.server;

    if([path isEqualToString:@"/eval/javascript"]) {
        return [[IGJavaScriptEvaulatorWebSocket alloc] initWithRequest:request socket:asyncSocket context:server.context];
    }

    if ([path isEqualToString:@"/eval/ruby"]) {
        return [[IGRubyEvaulatorWebSocket alloc] initWithRequest:request socket:asyncSocket context:server.context];
    }

    return [super webSocketForURI:path];
}

@end
