#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (BOOL)isContentValid {
    // Do validation of contentText and/or NSExtensionContext attachments here
    return YES;
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }

    self.view = rootView;
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}



RCT_EXPORT_METHOD(openURL:(NSString *)url) {
  UIApplication *application = [UIApplication sharedApplication];
  NSURL *urlToOpen = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  [application openURL:urlToOpen options:@{} completionHandler: nil];
}



RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSException* err, NSString* _url, NSString* _image, NSString* _text) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            NSMutableDictionary *shareData = [[NSMutableDictionary alloc] init];
            [shareData setObject:_url  forKey:@"url"];
            [shareData setObject:_image  forKey:@"image"];
            [shareData setObject:_text  forKey:@"text"];

            resolve(shareData);
        }
    }];
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSException *exception, NSString* url, NSString* image, NSString* text))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;

        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;

        __block NSString* url = @"";
        __block NSString* image = @"";
        __block NSString* text = @"";

        __block BOOL needUrl = FALSE;
        __block BOOL needImage = FALSE;
        __block BOOL needText = FALSE;

        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                needUrl = TRUE;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                needImage = TRUE;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                needText = TRUE;

            }
        }];

        if(urlProvider) {
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *_url = (NSURL *)item;
                url = [_url absoluteString];
                needUrl = FALSE;
                if(callback) {
                    // all providers finished?
                    if (!needUrl && !needImage && !needText) {
                        callback(nil, url, image, text);
                    }
                }
            }];
        }

        if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *_url = (NSURL *)item;
                image = [_url absoluteString];
                needImage = FALSE;
                if(callback) {
                    // all providers finished?
                    if (!needUrl && !needImage && !needText) {
                        callback(nil, url, image, text);
                    }
                }
            }];
        }

        if (textProvider) {
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                text = (NSString *)item;
                needText = FALSE;
                if(callback) {
                    // all providers finished?
                    if (!needUrl && !needImage && !needText) {
                        callback(nil, url, image, text);
                    }
                }
            }];
        }

        if (callback) {
            if (!urlProvider && !imageProvider && !textProvider) {
                callback([NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil], nil, nil, nil);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(exception, nil, nil, nil);
        }
    }
}

@end
