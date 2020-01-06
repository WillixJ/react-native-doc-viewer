//  ERGActivityVC.h
//  RNDocViewer
//
//  Created by Wilco J.
//  Copyright © 2020 ERG. All rights reserved.
#import <UIKit/UIKit.h>

@interface ERGActivityViewController : UIActivityViewController

- (BOOL)shouldExcludeActivityType:(UIActivity *)activity;

@end
