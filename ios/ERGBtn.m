//  ERGBtn.m
//  RNDocViewer
//
//  Created by Wilco J.
//  Copyright © 2020 ERG. All rights reserved.
#import "ERGBtn.h"
#import <objc/runtime.h>

@implementation ERGBtn{
    NSArray *Property;
}

static char UIB_PROPERTY_KEY;

@dynamic property;

-(void)setProperty:(NSObject *)property
{
    objc_setAssociatedObject(self, &UIB_PROPERTY_KEY, property, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSObject*)property
{
    return (NSObject*)objc_getAssociatedObject(self, &UIB_PROPERTY_KEY);
}

@end
