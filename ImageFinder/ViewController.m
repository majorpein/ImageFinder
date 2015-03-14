//
//  ViewController.m
//  ImageFinder
//
//  Created by Alexandro on 13/03/15.
//  Copyright (c) 2015 Alexandro. All rights reserved.
//

#import "ViewController.h"
#import "IFImageContainer.h"

@interface ViewController ()

@property (nonatomic) IBOutlet UISearchBar *searchBar;
@property (nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic) NSMutableArray *images;
@property (nonatomic) NSString *baseUrl;
@property (nonatomic) BOOL hideStatusBar;
@property (nonatomic) UIImageView *fullImgView;
@property (nonatomic) int widthOfItem;
@property (nonatomic) int startOfRequest;
@property (nonatomic) myRequestState state;
@property (nonatomic) UIActivityIndicatorView *indicator;
@property (nonatomic) dispatch_source_t timerSource;
@property (nonatomic) BOOL timerIsTicking;

@end

@implementation ViewController

//hides status bar
- (BOOL)prefersStatusBarHidden {
    return self.hideStatusBar;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.hideStatusBar = NO;
    self.baseUrl = @"http://ajax.googleapis.com/ajax/services/search/images?v=1.0";
    self.images = [[NSMutableArray alloc] init];
    self.fullImgView = [[UIImageView alloc] init];
    [self.fullImgView setUserInteractionEnabled:YES];
    self.state = myRequestStateDefault;
    
    self.indicator = [[UIActivityIndicatorView alloc] init];
    self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    
    [self updateScreenToSize:self.view.frame.size];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.timerSource, dispatch_walltime(NULL, 0), myRequestInterval * NSEC_PER_SEC, 2 * myRequestInterval * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timerSource, ^{
        if (self.timerIsTicking) {
            [self scheduledRequest];
        }
    });
    dispatch_resume(self.timerSource);
}

- (void)scheduledRequest {
    
    BOOL shouldLoadImages = NO;
    
    switch (self.state) {
        case myRequestStateSearching: {
            shouldLoadImages = YES;
            break;
        }
        case myRequestStateDefault: {
            self.startOfRequest = 0;
            shouldLoadImages = YES;
            break;
        }
        case myRequestStateNoInternetConnection: {
            shouldLoadImages = YES;
            break;
        }
        default:
            break;
    }
    
    int maxOffset = self.collectionView.contentSize.height - self.collectionView.bounds.size.height;
    if (shouldLoadImages && maxOffset - self.collectionView.contentOffset.y < mySrollViewOffset) {
        NSString *query = [self.searchBar.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([self getImagesForQuery:query Start:self.startOfRequest]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.indicator stopAnimating];
                [self.indicator removeFromSuperview];
                self.startOfRequest+=8;
                self.state = myRequestStateSearching;
            });
        } else if (self.state != myRequestStateNoInternetConnection) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.startOfRequest = 0;
                self.state = myRequestStateFoundEverything;
                [self.collectionView reloadData];
            });
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) updateScreenToSize:(CGSize)size {
    
    CGRect fr = CGRectMake(0, 0, size.width, size.height);
    [self.fullImgView setFrame:fr];
    
    [self.indicator setCenter:CGPointMake(size.width/2, self.collectionView.frame.origin.y+50)];
    
    self.widthOfItem = (size.width-(myItemsQTY+1)*myOffset)/myItemsQTY;
    [self.collectionView reloadData];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [self updateScreenToSize:size];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (void) handleLoadingDataError:(NSError *)error {
    if (error.code == -1009) {
        if (self.state != myRequestStateNoInternetConnection) {
            self.state = myRequestStateNoInternetConnection;
        } else {
            return;
        }
    } else {
        self.timerIsTicking = NO;
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [alert dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [alert addAction:ok];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - finding images

- (UIImage *) getImageFromURL:(NSString *)urlString {
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSError *error;
    NSURLResponse *response;
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    return [UIImage imageWithData:data];
}

- (BOOL) getImagesForQuery:(NSString *)query Start:(NSInteger)start {
    
    
    //NSLog(@"Q: %@, s: %ld", query, start);
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@&start=%ld&q=%@&rsz=8", self.baseUrl, start, query]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSError *error;
    NSURLResponse *response;
    
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (data == nil) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            [self handleLoadingDataError:error];
        });
        return NO;
    }
    id dataDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    //NSLog(@"%@", dataDic);
    if ([dataDic isKindOfClass:[NSDictionary class]] && [dataDic count]) {
        id respData = [dataDic objectForKey:@"responseData"];
        if ([respData isKindOfClass:[NSDictionary class]] && [respData count]) {
            id results = [respData objectForKey:@"results"];
            if ([results isKindOfClass:[NSArray class]] && [results count]) {
                for (NSDictionary *imageDic in results) {
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        
                        UIImage *img = [self getImageFromURL:[imageDic objectForKey:@"tbUrl"]];
                        //NSLog(@"Img: %@ for Q: %@", img, query);
                        if (img) {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                
                                IFImageContainer *imgCont = [[IFImageContainer alloc] init];
                                [imgCont setTbImage:[img copy]];
                                [imgCont setFullPicUrl:[imageDic objectForKey:@"unescapedUrl"]];
                                
                                NSString *escapedQuery = [self.searchBar.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                if ([escapedQuery isEqualToString:query]) {
                                    [self.images addObject:imgCont];
                                    [self.collectionView reloadData];
                                }
                                
                            });
                        }
                    });
                }
            }
        } else {
            return NO;
        }
    }
    return YES;
}

#pragma mark - search bar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {

    [searchBar resignFirstResponder];
}


- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    //NSLog(@"SearchBarText: %@, changedText: %@", self.searchBar.text, searchText);
    
    self.state = myRequestStateStopped;
    [self.images removeAllObjects];
    [self.collectionView reloadData];
    if ([searchText isEqualToString:@""]) {
        self.timerIsTicking = NO;
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    } else {
        self.timerIsTicking = YES;
        self.state = myRequestStateDefault;
        [self.indicator setCenter:CGPointMake(self.view.bounds.size.width/2, self.collectionView.frame.origin.y+50)];
        [self.indicator startAnimating];
        [self.view addSubview:self.indicator];
    }
    /*
    if ([searchText isEqualToString:@""] && self.timer != nil) {
        [self.timer invalidate];
        self.timer = nil;
    } else {
        self.state = myRequestStateDefault;
        [self.indicator setCenter:CGPointMake(self.view.bounds.size.width/2, self.collectionView.frame.origin.y+50)];
        [self.indicator startAnimating];
        [self.view addSubview:self.indicator];
        if (self.timer == nil) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:myRequestInterval target:self selector:@selector(scheduledRequest:) userInfo:nil repeats:YES];
        }
    }
     */
}

#pragma mark - collection view data source

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"imageCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor whiteColor];
    
    [[cell subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    if (indexPath.row < [self.images count]) {
        IFImageContainer *imgCont = [self.images objectAtIndex:indexPath.row];
        UIImageView *img = [[UIImageView alloc] initWithImage:imgCont.tbImage];
        [img setFrame:cell.bounds];
        [img setContentMode:UIViewContentModeScaleAspectFit];
        [cell addSubview:img];
    } else {
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
        indicator.center = CGPointMake(cell.bounds.size.width/2, cell.bounds.size.height/2);
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [indicator startAnimating];
        [cell addSubview:indicator];
    }
    
    return cell;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {

    
    return [self.images count]==0 || self.state==myRequestStateFoundEverything? [self.images count]:[self.images count]+1;
}

#pragma mark - collection view delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    [self.searchBar resignFirstResponder];
    
    IFImageContainer *imgCont = [self.images objectAtIndex:indexPath.row];
    [imgCont setSelected:YES];
    
    [self.fullImgView setBackgroundColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
    [self.fullImgView setImage:imgCont.tbImage];
    [self.fullImgView setContentMode:UIViewContentModeScaleAspectFit];
    [self.view addSubview:self.fullImgView];
    
    self.hideStatusBar = YES;
    [self setNeedsStatusBarAppearanceUpdate];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    tap.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:tap];
    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] init];
    indicator.center = self.fullImgView.center;
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [indicator startAnimating];
    [self.fullImgView addSubview:indicator];
    
    CGRect fullImgFrame = self.fullImgView.frame;
    CGRect tempFr = [collectionView cellForItemAtIndexPath:indexPath].frame;
    CGRect fr = CGRectMake(tempFr.origin.x, tempFr.origin.y+collectionView.frame.origin.y-self.collectionView.contentOffset.y, tempFr.size.width, tempFr.size.height);
    [self.fullImgView setFrame:fr];
    
    [self.view.layer removeAllAnimations];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^(void){
        
        [self.fullImgView setFrame:fullImgFrame];
        [self.fullImgView setBackgroundColor:[UIColor blackColor]];
    } completion:^(BOOL finished){
        
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [imgCont loadFullPic];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            if (imgCont.selected) {
                [self.fullImgView setImage:imgCont.fullImage];
            }
            
            [indicator stopAnimating];
            [indicator removeFromSuperview];
        });
    });
}

#pragma mark - collection view flowLayout delegate

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    return CGSizeMake(self.widthOfItem, self.widthOfItem);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(myOffset, myOffset, myOffset, myOffset);
}

#pragma mark - gestures

- (void) tapRecognized:(UITapGestureRecognizer *)myTap {
    
    self.hideStatusBar = NO;
    [self setNeedsStatusBarAppearanceUpdate];
    
    CGRect fr;
    for (IFImageContainer *imgCont in self.images) {
        if (imgCont.selected) {
            NSUInteger index = [self.images indexOfObject:imgCont];
            CGRect tempFr = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]].frame;
            fr = CGRectMake(tempFr.origin.x, tempFr.origin.y+self.collectionView.frame.origin.y+myStatusBarHeight-self.collectionView.contentOffset.y, tempFr.size.width, tempFr.size.height);
            [imgCont setSelected:NO];
        }
    }
    
    CGRect fullImgFrame = self.fullImgView.frame;
    
    [self.view.layer removeAllAnimations];
    [[self.fullImgView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^(void){
        
            [self.fullImgView setFrame:fr];
            [self.fullImgView setBackgroundColor:[UIColor colorWithWhite:1.0f alpha:0.0f]];
        } completion:^(BOOL finished){
            [self.fullImgView setImage:nil];
            [self.fullImgView removeFromSuperview];
            [self.fullImgView setFrame:fullImgFrame];
        }];
    
    [self.view removeGestureRecognizer:myTap];
    //NSLog(@"tap");
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

@end
