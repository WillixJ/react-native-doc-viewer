//  ERGActivityVC.m
//  RNDocViewer
//
//  Created by Wilco J.
//  Copyright © 2020 ERG. All rights reserved.
#import "ERGActivityVC.h"

@interface ERGActivityViewController ()

@end

@implementation ERGActivityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)_shouldExcludeActivityType:(UIActivity *)activity
{
    if ([[activity activityType] isEqualToString:@"us.zoom.videomeetings.Extension"] ||
        [[activity activityType] isEqualToString:@"net.ifao.cytric.cytricPhotoShareExtension"]) {
        return YES;
    }
    return [super _shouldExcludeActivityType:activity];
}

- (BOOL)shouldExcludeActivityType:(UIActivity *)activity
{
    assert(false);  // shouldExcludeActivityType requires overriding.
    return false;
}

@end
