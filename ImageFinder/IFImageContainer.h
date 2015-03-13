//
//  IFImageContainer.h
//  ImageFinder
//
//  Created by Alexandro on 13/03/15.
//  Copyright (c) 2015 Alexandro. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface IFImageContainer : NSObject

@property (nonatomic) UIImage *tbImage;
@property (nonatomic) NSString *fullPicUrl;
@property (nonatomic) NSString *tbPicUrl;
@property (nonatomic) UIImage *fullImage;
@property (nonatomic) BOOL selected;

- (void) loadFullPic;

@end
