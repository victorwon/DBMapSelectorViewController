//
//  DBMapSelectorAnnotation.m
//  DBMapSelectorViewControllerExample
//
//  Created by Denis Bogatyrev on 27.03.15.
//  Copyright (c) 2015 Denis Bogatyrev. All rights reserved.
//

#import "DBMapSelectorAnnotation.h"

@implementation DBMapSelectorAnnotation

@synthesize coordinate = _coordinate;
@synthesize title = _title;
@synthesize subtitle = _subtitle;

- (id)initWithTitle:(NSString *)title andSubTitle:(NSString *)subtitle {
    self = [self init];
    if (self) {
        _title = title;
        _subtitle = subtitle;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    _coordinate = coordinate;
}

@end
