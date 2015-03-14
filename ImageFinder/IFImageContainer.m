//
//  IFImageContainer.m
//  ImageFinder
//
//  Created by Alexandro on 13/03/15.
//  Copyright (c) 2015 Alexandro. All rights reserved.
//

#import "IFImageContainer.h"

@implementation IFImageContainer

- (id)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)memoryWarning:(NSNotification*)note {
    if (self.fullImage) [self setFullImage:nil];
}

- (void) loadFullPic {
    
    if (self.fullImage) return;
    
    NSURL *url = [NSURL URLWithString:self.fullPicUrl];
    /*
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSError *error;
    NSURLResponse *response;
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
     */
    NSData *data = [NSData dataWithContentsOfURL:url];
    UIImage *img = [UIImage imageWithData:data];
    
    if (img) {
        [self setFullImage:img];
    } else {
        [self setFullImage:[self.tbImage copy]];
    }
}

@end
