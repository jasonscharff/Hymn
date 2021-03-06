//
//  QRCodeScannerViewController.m
//  Hymn
//
//  Created by Jason Scharff on 2/20/16.
//  Copyright © 2016 Jason Scharff. All rights reserved.
//

#import "QRCodeScannerViewController.h"

#import "Constants.h"

#import "RESTSessionManager+Space.h"


@import AVFoundation;

@interface QRCodeScannerViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) UIView *videoPreviewView;

@property (nonnull, strong) NSDictionary *observingNotifications;

@property (nonatomic) BOOL didJoinSpace;

@end

@implementation QRCodeScannerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self registerForNotifications];
  [self configureNavBar];
}

-(void)viewWillAppear:(BOOL)animated {
  self.title = @"Scan a QR code.";
  [self startReading];
}

-(void)configureNavBar {
  UIBarButtonItem *flipButton = [[UIBarButtonItem alloc]
                                 initWithTitle:@"Cancel"
                                 style:UIBarButtonItemStylePlain
                                 target:self
                                 action:@selector(dismissView:)];
  
  [flipButton setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                      [UIFont fontWithName:@"AvenirNext-Regular" size:18.0], NSFontAttributeName,
                                      [UIColor blackColor], NSForegroundColorAttributeName,
                                      nil] forState:UIControlStateNormal];
  
  self.navigationItem.leftBarButtonItem = flipButton;
}

-(void)startReading {
  NSError *error;
  AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
  if (!input) {
    NSLog(@"%@", [error localizedDescription]);
    NSLog(@"Chances are this is is being done in the simulator, don't do that.");
    return;
  }
  self.videoPreviewView = [[UIView alloc]initWithFrame:self.view.frame];
  [self.view addSubview:self.videoPreviewView];
  _captureSession = [[AVCaptureSession alloc] init];
  [_captureSession addInput:input];
  AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
  [_captureSession addOutput:captureMetadataOutput];
  dispatch_queue_t dispatchQueue;
  dispatchQueue = dispatch_queue_create("myQueue", NULL);
  [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
  [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
  _videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
  [_videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
  [_videoPreviewLayer setFrame:self.view.layer.bounds];
  [self.videoPreviewView.layer addSublayer:_videoPreviewLayer];
  [_captureSession startRunning];
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
  if (metadataObjects != nil && [metadataObjects count] > 0) {
    AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
    if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
      NSString *string = metadataObj.stringValue;
      [[RESTSessionManager sharedSessionManager]joinSpaceWithIdentifier:string];
      [_captureSession stopRunning];
      
      UILabel *accessCodeLabel = [UILabel new];
      accessCodeLabel.font = [UIFont fontWithName:@"AvenirNext-Regular" size:30];
      accessCodeLabel.text = string;
      accessCodeLabel.textColor = [UIColor whiteColor];
      
      accessCodeLabel.layer.shadowOpacity = 1.0;
      accessCodeLabel.layer.shadowRadius = 0.0;
      accessCodeLabel.layer.shadowColor = [UIColor blackColor].CGColor;
      accessCodeLabel.layer.shadowOffset = CGSizeMake(-1.0, -2.0);
      accessCodeLabel.translatesAutoresizingMaskIntoConstraints = NO;
      
      NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:accessCodeLabel
                                                                attribute:NSLayoutAttributeCenterX
                                                                relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                                attribute:NSLayoutAttributeCenterX
                                                                multiplier:1
                                                                constant:0];
      
      NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:accessCodeLabel
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:self.view
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1
                                                                 constant:0];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.view addSubview:accessCodeLabel];
        [self.view addConstraint:centerX];
        [self.view addConstraint:centerY];
        [self.view layoutIfNeeded];
        centerY.constant = (self.view.frame.size.height / 2 + accessCodeLabel.frame.size.height/2) * -1;
        [UIView animateWithDuration:1.5 animations:^{
          [self.view layoutIfNeeded];
          accessCodeLabel.transform = CGAffineTransformScale(accessCodeLabel.transform, 0.35, 0.35);
        } completion:^(BOOL finished) {
          [self dismissSelfToNextView:self.didJoinSpace];
        }];
      });
    }
  }
}

-(void)dismissSelfToNextView: (BOOL)continueToNextView{
  [_captureSession stopRunning];
  _captureSession = nil;
  _videoPreviewView = nil;
  if(!continueToNextView) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
  else {
     [self dismissViewControllerAnimated:YES completion:nil];
  }
}

-(void)dismissView : (UIBarButtonItem *)barButtonItem {
  [self dismissSelfToNextView:NO];
}

- (void)registerForNotifications {
  self.observingNotifications = @{HAS_JOINED_SPACE : @"hasJoinedSpace:",
                                  INVALID_SPACE_NAME_NOTIFICATION : @"invalidSpaceName:"};
  
  [self.observingNotifications enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:NSSelectorFromString(obj)
                                                 name:key
                                               object:nil];
    
  }];
}

- (void)unregisterForNotifications {
  for (NSString *key in self.observingNotifications) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:key
                                                  object:nil];
  }
}

-(void)dealloc {
  [self unregisterForNotifications];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)hasJoinedSpace : (NSNotification *)notification {
  self.didJoinSpace = YES;
}

-(void)invalidSpaceName : (NSNotification *)notification {
  self.didJoinSpace = NO;
  self.previousVC.shouldBeginWithInvalidSpaceMessage = YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
