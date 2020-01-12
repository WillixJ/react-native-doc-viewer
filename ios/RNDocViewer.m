//
//  RNDocViewer.m
//  RNDocViewer
//
//  Created by Philipp Hecht on 10/03/17.
//  Copyright (c) 2017 Philipp Hecht. All rights reserved.
//
#import "RNDocViewer.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "QLCustomPreviewItem.h"
#import "ERGBtn.h"

@implementation RNDocViewer
CGFloat prog;
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"RNDownloaderProgress", @"DoneButtonEvent", @"CancelEvent", @"OKEvent"];
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(testModule:(NSString *)name location:(NSString *)location)
{
    RCTLogInfo(@"TEST Module %@ at %@", name, location);
}

RCT_EXPORT_METHOD(statusProgress:(NSArray *)array callback:(RCTResponseSenderBlock)callback)
{
   callback(@[[NSNull null], @(prog)]);
}

/**
 * openDoc
 * open Base64 String
 * Parameters: NSArray
 */
RCT_EXPORT_METHOD(openDoc:(NSArray *)array callback:(RCTResponseSenderBlock)callback)
{

    __weak RNDocViewer* weakSelf = self;
    //Download Progress
    NSDictionary* dict_download = [array objectAtIndex:0];
    NSString* urlStrdownload = dict_download[@"url"];
    [self hitServerForUrl:urlStrdownload];
    dispatch_queue_t asyncQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(asyncQueue, ^{
        NSDictionary* dict = [array objectAtIndex:0];
        NSString* urlStr = dict[@"url"];
        NSString* fileNameOptional = dict[@"fileName"];
        NSString* fileType = dict[@"fileType"];
        NSURL* url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSData* dat = [NSData dataWithContentsOfURL:url];
        RCTLogInfo(@"Url %@", url);
        RCTLogInfo(@"FileNameOptional %@", fileNameOptional);
        NSArray* parts = [urlStr componentsSeparatedByString:@"/"];
        NSArray* fileNameParts = [[parts lastObject] componentsSeparatedByString:@"?"];    // to remove any query string on url
        NSString* fileNameExported = [fileNameParts firstObject];
        NSString* fileExt = [fileNameExported pathExtension];
        //Custom Filename
        NSString* fileName = @"";

        if ([fileNameOptional length] > 0 && [fileType length] > 0) {    // both fileNameOptional and fileType are given
            fileExt = fileType;
            NSString* extOnFileNameOptional = [fileNameOptional pathExtension];   // ext from fileNameOptional
            if ([extOnFileNameOptional length] > 0) {   // if ext on fileNameOptional is found, just delete it
                fileName = [fileNameOptional stringByDeletingPathExtension];
            } else {
                fileName = fileNameOptional;
            }
        } else if ([fileNameOptional length] > 0) {    // fileType is not given
            NSString* extOnFileNameOptional = [fileNameOptional pathExtension];   // ext from fileNameOptional
            if ([fileExt length] > 0) {   // ext from url is found
                if ([extOnFileNameOptional length] > 0) {   // if ext on fileNameOptional is found, just delete it
                    fileName = [fileNameOptional stringByDeletingPathExtension];
                } else {
                    fileName = fileNameOptional;
                }
            } else {    // ext is missing from url
                if ([extOnFileNameOptional length] > 0) {
                    fileName = [fileNameOptional stringByDeletingPathExtension];
                    fileExt = extOnFileNameOptional;
                }    // else fileExt is empty string
            }
        }
        if ([fileExt length] > 0) {
            fileName = [NSString stringWithFormat:@"%@%c%@", fileName , '.', fileExt];
        }

        //From the www
        if ([urlStr containsString:@"http"] || [urlStr containsString:@"https"]) {
            if (dat == nil) {
                if (callback) {
                    callback(@[[NSNull null], @"Doc Url not found"]);
                }
                return;
            }

            NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
            NSURL* tmpFileUrl = [[NSURL alloc] initFileURLWithPath:path];
            [dat writeToURL:tmpFileUrl atomically:YES];
            weakSelf.fileUrl = tmpFileUrl;
        } else {
            NSURL* tmpFileUrl = [[NSURL alloc] initFileURLWithPath:urlStr];
            weakSelf.fileUrl = tmpFileUrl;
            weakSelf.optionalFileName = fileNameOptional;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            QLPreviewController* cntr = [[QLPreviewController alloc] init];
            cntr.delegate = weakSelf;
            cntr.dataSource = weakSelf;
        
            if (callback) {
                callback(@[[NSNull null], array]);
            }
            UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            while (root.presentedViewController) {
                root = [root presentedViewController];
            }
                      
            [root presentViewController:cntr animated:YES completion:^{
            
                //ERG: Sharing override in Quicklook
                    NSLog(@"Doc preview presented");
                
                //Delay:
                double delayInSeconds = 0.3;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

                    if ([cntr.childViewControllers count] > 0) {
                        
                        NSLog(@"We got root");
                        
                        //Get current buttons
                        UINavigationController *nav = (UINavigationController*) cntr.childViewControllers[0];
                        UIBarButtonItem *origDoneButton = nav.navigationBar.items[0].leftBarButtonItem;
                        //UIBarButtonItem *origShareButton = nav.navigationBar.items[0].rightBarButtonItem;
                        
                        //New actions
                        //NSDictionary* dict = [array objectAtIndex:0];
                        
                        //New buttons
                        UIBarButtonItem *newDone = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:origDoneButton.target action:origDoneButton.action];
                        
                        ERGBtn *newShare = [[ERGBtn alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sharePressed:)];
                        newShare.property = array;
                        //Add new Done and Share button
                        nav.navigationBar.items[0].leftBarButtonItem = newDone;
                        nav.navigationBar.items[0].rightBarButtonItem = newShare;
                    }
                    else{
                        NSLog(@"Root is empty");
                    }
                    
            
                
                // end Delay
                });
            // end override - Completion function
            }];
        });

    });
}


/**
 * BinaryinUrl
 * open Url with a Binary String
 * Parameters: NSArray
 */
RCT_EXPORT_METHOD(openDocBinaryinUrl:(NSArray *)array callback:(RCTResponseSenderBlock)callback)
{
    __weak RNDocViewer* weakSelf = self;
    NSDictionary* dict_download = [array objectAtIndex:0];
    NSString* urlStrdownload = dict_download[@"url"];
    [self hitServerForUrl:urlStrdownload];
    dispatch_queue_t asyncQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(asyncQueue, ^{
        NSDictionary* dict = [array objectAtIndex:0];
        NSString* url = dict[@"url"];
        NSString* filename = dict[@"fileName"];
        NSString* filetype = dict[@"fileType"];
        //NSArray* splitUrl = [url componentsSeparatedByString: @"/"];
        //NSString* binaryString = [splitUrl lastObject];
        //Parse the Binary from URL
        //NSData* byteArrayString = [binaryString dataUsingEncoding:NSUTF8StringEncoding];
         //NSLog(@"%@", byteArrayString);
        NSURL* urlbinary = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSData* dat = [NSData dataWithContentsOfURL:urlbinary];
        if (dat == nil) {
            if (callback) {
                callback(@[[NSNull null], @"DATA nil"]);
            }
            return;
        }
        NSString* fileName = [NSString stringWithFormat:@"%@%@%@", filename, @".", filetype];
        NSString* fileExt = [fileName pathExtension];
        if([fileExt length] == 0){
            fileName = [NSString stringWithFormat:@"%@%@", fileName, @".pdf"];
        }
        NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
        NSURL* tmpFileUrl = [[NSURL alloc] initFileURLWithPath:path];

        [dat writeToURL:tmpFileUrl atomically:YES];
        weakSelf.fileUrl = tmpFileUrl;

        dispatch_async(dispatch_get_main_queue(), ^{
            QLPreviewController* cntr = [[QLPreviewController alloc] init];
            cntr.delegate = weakSelf;
            cntr.dataSource = weakSelf;
            if (callback) {
                callback(@[[NSNull null], @"Data"]);
            }
            UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            while (root.presentedViewController) {
                root = [root presentedViewController];
            }
            [root presentViewController:cntr animated:YES completion:nil];
        });

    });
}

/**
 * openDocb64
 * open Base64 String
 * Parameters: NSArray
 */
RCT_EXPORT_METHOD(openDocb64:(NSArray *)array callback:(RCTResponseSenderBlock)callback)
{

    __weak RNDocViewer* weakSelf = self;
    dispatch_queue_t asyncQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(asyncQueue, ^{
        NSDictionary* dict = [array objectAtIndex:0];
        NSString* base64String = dict[@"base64"];
        NSString* filename = dict[@"fileName"];
        NSString* filetype = dict[@"fileType"];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"data:application/octet-stream;base64,%@",base64String]];
        NSData* dat = [NSData dataWithContentsOfURL:url];
        if (dat == nil) {
            if (callback) {
                callback(@[[NSNull null], @"DATA nil"]);
            }
            return;
        }
        NSString* fileName = [NSString stringWithFormat:@"%@%@%@", filename, @".", filetype];
        NSString* fileExt = [fileName pathExtension];
        if([fileExt length] == 0){
            fileName = [NSString stringWithFormat:@"%@%@", fileName, @".pdf"];
        }
        NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent: fileName];
        NSURL* tmpFileUrl = [[NSURL alloc] initFileURLWithPath:path];

        [dat writeToURL:tmpFileUrl atomically:YES];
        weakSelf.fileUrl = tmpFileUrl;

        dispatch_async(dispatch_get_main_queue(), ^{
            QLPreviewController* cntr = [[QLPreviewController alloc] init];
            cntr.delegate = weakSelf;
            cntr.dataSource = weakSelf;
            if (callback) {
                callback(@[[NSNull null], @"Data"]);
            }
            UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            while (root.presentedViewController) {
                root = [root presentedViewController];
            }
            [root presentViewController:cntr animated:YES completion:nil];
        });

    });
}


//Movie Files mp4
RCT_EXPORT_METHOD(playMovie:(NSString *)file callback:(RCTResponseSenderBlock)callback)
{
    //NSDictionary* dict = [array objectAtIndex:0];
    NSString *_uri = file;
    
    
    NSURL *fileURL = nil;
    if ([_uri containsString:@"http"] || [_uri containsString:@"https"]) {
        fileURL = [NSURL URLWithString:_uri];
    }else{
        NSString* mediaFilePath = [[NSBundle mainBundle] pathForResource:_uri ofType:nil];
        NSAssert(mediaFilePath, @"Media not found: %@", _uri);
        fileURL = [NSURL fileURLWithPath:mediaFilePath];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        
        AVPlayerViewController *movieViewController = [[AVPlayerViewController alloc] init];
        
        movieViewController.player = [AVPlayer playerWithURL:fileURL];
        
        [movieViewController.player play];
        
        movieViewController = movieViewController;
        
        UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        UIView *view = [ctrl view];
        
        view.window.windowLevel = UIWindowLevelStatusBar;
        if (callback) {
            callback(@[[NSNull null], @"true"]);
        }
        
        [ctrl presentViewController:movieViewController animated:TRUE completion: nil];
        
    });
}
//Dismiss QuickViewController
- (void)previewControllerDidDismiss:(QLPreviewController *)controller {
    [self DoneButtonClicked];
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
    return 1;
}

- (id <QLPreviewItem>) previewController: (QLPreviewController *) controller previewItemAtIndex: (NSInteger) index
{
    if(self.optionalFileName) {
        QLCustomPreviewItem *previewItem = [[QLCustomPreviewItem alloc] initWithURL:self.fileUrl optionalFileName:self.optionalFileName];
        return previewItem;
    }
    return self;
}

#pragma mark - QLPreviewItem protocol

- (NSURL*)previewItemURL
{
    return self.fileUrl;
}


//Download Task example
- (void)hitServerForUrl:(NSString*)urlString {
    NSURL *requestUrl = [NSURL URLWithString:urlString];
    
    NSURLSessionConfiguration *defaultConfigurationObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration:defaultConfigurationObject delegate:self delegateQueue: nil];
    
    NSURLSessionDownloadTask *fileDownloadTask = [defaultSession downloadTaskWithURL:requestUrl];
    
    [fileDownloadTask resume];
    
}


- (void)DoneButtonClicked {
    [self sendEventWithName:@"DoneButtonEvent" body:@{ @"close": @true}];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error != nil) {
        NSData *resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
        self.downloadResumeData = resumeData;
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    dispatch_sync(dispatch_get_main_queue(), ^{
        //float progressValue = totalBytesWritten/totalBytesExpectedToWrite;
        prog = (float)totalBytesWritten/totalBytesExpectedToWrite;
        //NSLog(@"downloaded %d%%", (int)(100.0*prog));
        
        NSNumber *progress = @([@(totalBytesWritten) floatValue]/[@(totalBytesExpectedToWrite) floatValue] * 100.0);
        [self sendEventWithName:@"RNDownloaderProgress" body:@{ @"totalBytesWritten": @(totalBytesWritten),
                                                                @"totalBytesExpectedToWrite": @(totalBytesExpectedToWrite),
                                                                @"progress": progress }];

    });
}


RCT_EXPORT_METHOD(showAlert:(NSString *)msg) {
    
    // We'll show UIAlerView to know listener successful.
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:msg delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
    });
    
    
}

#pragma mark - UIAlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 0) {
        // Sent event tap on Cancel
        [self sendEventWithName:@"CancelEvent" body:@"Tap on Cancel"];
        
    } else if (buttonIndex == 1) {
        // Sent event tap on Ok
        [self sendEventWithName:@"OKEvent" body:@"Tap on OK"];
    }
}


#pragma mark - ERG sharePressed

- (void)sharePressed:(ERGBtn*)sender
{
    NSDictionary* dict_download = [sender.property objectAtIndex:0];
    NSString* urlStrdownload = dict_download[@"url"];
    //NSString* filename = dict_download[@"fileName"];
    //NSString* filetype = dict_download[@"fileType"];
    
    NSLog(@"Share pressed %@", urlStrdownload);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *URL = [[NSURL alloc] initFileURLWithPath:urlStrdownload];
        NSArray *activityItems = @[URL];
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        
        activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypePostToTwitter, UIActivityTypePostToWeibo];
        
        [activityVC setCompletionHandler:^(NSString *activityType, BOOL completed) {
            NSLog(@"completed dialog - activity: %@ - finished flag: %d", activityType, completed);
        }];
        
        UIViewController* root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
        
        while (root.presentedViewController) {
            root = [root presentedViewController];
        }
        [root presentViewController:activityVC animated:YES completion:nil];
    });
}

/*- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
 
 NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
 NSURL *documentsDirectoryURL = [NSURL fileURLWithPath:documentsPath];
 NSURL *documentURL = [documentsDirectoryURL URLByAppendingPathComponent:[downloadTask.response suggestedFilename]];
 NSError *error;
 
 NSString *filePath = [documentsPath stringByAppendingPathComponent:[downloadTask.response suggestedFilename]];
 NSLog(@"file path : %@", filePath);
 if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
 //Remove the old file from directory
 }
 
 [[NSFileManager defaultManager] moveItemAtURL:location
 toURL:documentURL
 error:&error];
 if (error){
 //Handle error here
 }
 }*/

@end
