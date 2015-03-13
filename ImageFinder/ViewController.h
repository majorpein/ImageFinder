//
//  ViewController.h
//  ImageFinder
//
//  Created by Alexandro on 13/03/15.
//  Copyright (c) 2015 Alexandro. All rights reserved.
//

#import <UIKit/UIKit.h>

#define myItemsQTY 3
#define myOffset 10
#define myStatusBarHeight 20
#define myRequestInterval 0.5
#define mySrollViewOffset 200

typedef enum {
    myRequestStateDefault,
    myRequestStateSearching,
    myRequestStateFoundEverything,
    myRequestStateStopped,
    myRequestStateNoInternetConnection
} myRequestState;

@interface ViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>


@end

