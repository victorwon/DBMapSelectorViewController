//
//  DBMapSelectorManager.m
//  DBMapSelectorViewControllerExample
//
//  Created by Denis Bogatyrev on 27.03.15.
//  Copyright (c) 2015 Denis Bogatyrev. All rights reserved.
//

#import "DBMapSelectorGestureRecognizer.h"

#import "DBMapSelectorAnnotation.h"
#import "DBMapSelectorOverlay.h"
#import "DBMapSelectorOverlayRenderer.h"
#import "DBMapSelectorManager.h"

NSInteger const defaultRadius       = 1000;
NSInteger const defaultMinDistance  = 100;
NSInteger const defaultMaxDistance  = 10000;


@interface DBMapSelectorManager () {
    BOOL                            _isFirstTimeApplySelectorSettings;
    DBMapSelectorOverlay            *_selectorOverlay;
    DBMapSelectorOverlayRenderer    *_selectorOverlayRenderer;
    
    BOOL                            _mapViewGestureEnabled;
    MKMapPoint                      _prevMapPoint;
    CLLocationDistance              _prevRadius;
    CGRect                          _radiusTouchRect;
    UIView                          *_radiusTouchView;
    
    UILongPressGestureRecognizer    *_longPressGestureRecognizer;
}

@end

@implementation DBMapSelectorManager

- (instancetype)initWithMapView:(MKMapView *)mapView {
    self = [super init];
    if (self) {
        _isFirstTimeApplySelectorSettings = YES;
        _mapView = mapView;
        _pinColor = MKPinAnnotationColorGreen;
        [self prepareForFirstUse];
    }
    return self;
}

- (void)prepareForFirstUse {
    [self selectorSetDefaults];
    
    _selectorOverlay = [[DBMapSelectorOverlay alloc] initWithCenterCoordinate:_circleCoordinate radius:_circleRadius];
    
#ifdef DEBUG
    _radiusTouchView = [[UIView alloc] initWithFrame:CGRectZero];
    _radiusTouchView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:.5f];
    _radiusTouchView.userInteractionEnabled = NO;
    //[self.mapView addSubview:_radiusTouchView];
#endif
    
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognizer:)];
    
    _mapViewGestureEnabled = YES;
    [self.mapView addGestureRecognizer:[self selectorGestureRecognizer]];
    
}

#pragma mark Defaults

- (void)selectorSetDefaults {
    self.editingType = DBMapSelectorEditingTypeFull;
    self.circleRadius = defaultRadius;
    self.circleRadiusMin = defaultMinDistance;
    self.circleRadiusMax = defaultMaxDistance;
    self.hidden = NO;
    self.fillInside = YES;
    self.shouldShowRadiusText = YES;
    self.fillColor = [UIColor orangeColor];
    self.strokeColor = [UIColor darkGrayColor];
    self.mapRegionCoef = 2.f;
}

- (void)applySelectorSettings {
    [self updateMapRegionForMapSelector];
    [self displaySelectorAnnotationIfNeeded];
    [self recalculateRadiusTouchRect];
    if (_isFirstTimeApplySelectorSettings) {
        _isFirstTimeApplySelectorSettings = NO;
        [self.mapView removeOverlay:_selectorOverlay];
        [self.mapView addOverlay:_selectorOverlay];
    }
}

#pragma mark - GestureRecognizer

- (DBMapSelectorGestureRecognizer *)selectorGestureRecognizer {
    
    __weak typeof(self)weakSelf = self;
    DBMapSelectorGestureRecognizer *selectorGestureRecognizer = [[DBMapSelectorGestureRecognizer alloc] init];
    
    selectorGestureRecognizer.touchesBeganCallback = ^(NSSet * touches, UIEvent * event) {
        UITouch *touch = [touches anyObject];
        CGPoint touchPoint = [touch locationInView:weakSelf.mapView];
        //NSLog(@"---- %@", CGRectContainsPoint(_selectorRadiusRect, p) ? @"Y" : @"N");
        
        CLLocationCoordinate2D coord = [weakSelf.mapView convertPoint:touchPoint toCoordinateFromView:weakSelf.mapView];
        MKMapPoint mapPoint = MKMapPointForCoordinate(coord);
        
        if (CGRectContainsPoint(_radiusTouchRect, touchPoint) && _selectorOverlay.editingRadius && !weakSelf.hidden){
            if (_delegate && [_delegate respondsToSelector:@selector(mapSelectorManagerWillBeginHandlingUserInteraction:)]) {
                [_delegate mapSelectorManagerWillBeginHandlingUserInteraction:self];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.mapView.scrollEnabled = NO;
                weakSelf.mapView.userInteractionEnabled = NO;
                _mapViewGestureEnabled = NO;
            });
        } else {
            weakSelf.mapView.scrollEnabled = YES;
            weakSelf.mapView.userInteractionEnabled = YES;
        }
        _prevMapPoint = mapPoint;
        _prevRadius = weakSelf.circleRadius;
    };
    
    selectorGestureRecognizer.touchesMovedCallback = ^(NSSet * touches, UIEvent * event) {
        if(!_mapViewGestureEnabled && [event allTouches].count == 1){
            UITouch *touch = [touches anyObject];
            CGPoint touchPoint = [touch locationInView:weakSelf.mapView];
            
            CLLocationCoordinate2D coord = [weakSelf.mapView convertPoint:touchPoint toCoordinateFromView:weakSelf.mapView];
            MKMapPoint mapPoint = MKMapPointForCoordinate(coord);
            
            double meterDistance = (mapPoint.x - _prevMapPoint.x)/MKMapPointsPerMeterAtLatitude(weakSelf.mapView.centerCoordinate.latitude) + _prevRadius;
            weakSelf.circleRadius = MIN( MAX( meterDistance, weakSelf.circleRadiusMin ), weakSelf.circleRadiusMax );
        }
    };
    
    selectorGestureRecognizer.touchesEndedCallback = ^(NSSet * touches, UIEvent * event) {
        weakSelf.mapView.scrollEnabled = YES;
        weakSelf.mapView.userInteractionEnabled = YES;
        
        if (_prevRadius != weakSelf.circleRadius) {
            [weakSelf recalculateRadiusTouchRect];
            //if (((_prevRadius / weakSelf.circleRadius) >= 1.25f) || ((_prevRadius / weakSelf.circleRadius) <= .75f)) {
            [weakSelf updateMapRegionForMapSelector];
            //}
        }
        if(!_mapViewGestureEnabled) {
            if (_delegate && [_delegate respondsToSelector:@selector(mapSelectorManagerDidHandleUserInteraction:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate mapSelectorManagerDidHandleUserInteraction:self];
                });
            }
        }
        _mapViewGestureEnabled = YES;
    };
    
    return selectorGestureRecognizer;
}

- (void)longPressGestureRecognizer:(UILongPressGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] &&
        ( self.editingType == DBMapSelectorEditingTypeFull || self.editingType == DBMapSelectorEditingTypeCoordinateOnly )) {
        switch (gestureRecognizer.state) {
            case UIGestureRecognizerStateBegan: {
                CGPoint touchPoint = [gestureRecognizer locationInView:self.mapView];
                CLLocationCoordinate2D coord = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
                self.circleCoordinate = coord;
                [self displaySelectorAnnotationIfNeeded];
                break;
            }
            case UIGestureRecognizerStateEnded:
                if (NO == MKMapRectContainsRect(self.mapView.visibleMapRect, _selectorOverlay.boundingMapRect)) {
                    [self updateMapRegionForMapSelector];
                }
                break;
            default:
                break;
        }
    }
}

#pragma mark - Accessors

- (void)setCircleRadius:(CLLocationDistance)circleRadius {
    if (_circleRadius!= MAX(MIN(circleRadius, _circleRadiusMax), _circleRadiusMin)) {
        _circleRadius = MAX(MIN(circleRadius, _circleRadiusMax), _circleRadiusMin);
        _selectorOverlay.radius = _circleRadius;
        if (_delegate && [_delegate respondsToSelector:@selector(mapSelectorManager:didChangeRadius:)]) {
            [_delegate mapSelectorManager:self
                          didChangeRadius:_circleRadius];
        }
    }
}

- (void)setCircleRadiusMax:(CLLocationDistance)circleRadiusMax {
    if (_circleRadiusMax != circleRadiusMax) {
        _circleRadiusMax = circleRadiusMax;
        _circleRadiusMin = MIN(_circleRadiusMin, _circleRadiusMax);
        self.circleRadius = _circleRadius;
    }
}

- (void)setCircleRadiusMin:(CLLocationDistance)circleRadiusMin {
    if (_circleRadiusMin != circleRadiusMin) {
        _circleRadiusMin = circleRadiusMin;
        _circleRadiusMax = MAX(_circleRadiusMax, _circleRadiusMin);
        self.circleRadius = _circleRadius;
    }
}

- (void)setCircleRadiusFillOutside:(CLLocationDistance)circleRadiusFillOutside {
        _circleRadiusFillOutside = circleRadiusFillOutside;
        _selectorOverlay.radiusFillOutside = _circleRadiusFillOutside;
}

- (void)setCircleCoordinate:(CLLocationCoordinate2D)circleCoordinate {
    if ((_circleCoordinate.latitude != circleCoordinate.latitude) || (_circleCoordinate.longitude != circleCoordinate.longitude)) {
        _circleCoordinate = circleCoordinate;
        [self.mapView removeOverlay:_selectorOverlay];
        _selectorOverlay.coordinate = _circleCoordinate;
        if (_hidden == NO) {
            [self.mapView addOverlay:_selectorOverlay];
        }
        [self recalculateRadiusTouchRect];
        if (_delegate && [_delegate respondsToSelector:@selector(mapSelectorManager:didChangeCoordinate:)]) {
            [_delegate mapSelectorManager:self
                      didChangeCoordinate:_circleCoordinate];
        }
    }
}

- (void)setFillColor:(UIColor *)fillColor {
    if (_fillColor != fillColor) {
        _fillColor = fillColor;
        _selectorOverlayRenderer.fillColor = fillColor;
        [_selectorOverlayRenderer invalidatePath];
    }
}

- (void)setStrokeColor:(UIColor *)strokeColor {
    if (_strokeColor != strokeColor) {
        _strokeColor = strokeColor;
        _selectorOverlayRenderer.strokeColor = strokeColor;
        [_selectorOverlayRenderer invalidatePath];
    }
}

- (void)setEditingType:(DBMapSelectorEditingType)editingType {
    if (_editingType != editingType) {
        _editingType = editingType;
        
        _selectorOverlay.editingCoordinate = (_editingType == DBMapSelectorEditingTypeCoordinateOnly || _editingType == DBMapSelectorEditingTypeFull);
        _selectorOverlay.editingRadius = (_editingType == DBMapSelectorEditingTypeRadiusOnly || _editingType == DBMapSelectorEditingTypeFull);
        [self displaySelectorAnnotationIfNeeded];
    }
}

- (void)setHidden:(BOOL)hidden {
    if (_hidden != hidden) {
        _hidden = hidden;
        
        [self displaySelectorAnnotationIfNeeded];
        if (_hidden) {
            [self.mapView removeOverlay:_selectorOverlay];
        } else {
            [self.mapView addOverlay:_selectorOverlay];
        }
        [self recalculateRadiusTouchRect];
    }
}

- (void)setFillInside:(BOOL)fillInside {
    if (_fillInside != fillInside) {
        _fillInside = fillInside;
        _selectorOverlay.fillInside = fillInside;
    }
}

- (void)setShouldShowRadiusText:(BOOL)shouldShowRadiusText {
    _selectorOverlay.shouldShowRadiusText = shouldShowRadiusText;
}

- (void)setShouldLongPressGesture:(BOOL)shouldLongPressGesture {
    if (_shouldLongPressGesture != shouldLongPressGesture) {
        _shouldLongPressGesture = shouldLongPressGesture;
        if (_shouldLongPressGesture) {
            [self.mapView addGestureRecognizer:_longPressGestureRecognizer];
        } else {
            [self.mapView removeGestureRecognizer:_longPressGestureRecognizer];
        }
    }
}

#pragma mark - Additional

- (void)recalculateRadiusTouchRect {
    MKMapRect selectorMapRect = _selectorOverlay.boundingMapRect;
    MKMapPoint selectorRadiusPoint = MKMapPointMake(MKMapRectGetMaxX(selectorMapRect), MKMapRectGetMidY(selectorMapRect));
    MKCoordinateRegion coordinateRegion = MKCoordinateRegionMakeWithDistance(MKCoordinateForMapPoint(selectorRadiusPoint), _circleRadius *.3f, _circleRadius *.3f);
    BOOL needDisplay = MKMapRectContainsPoint(self.mapView.visibleMapRect, selectorRadiusPoint) && (_hidden == NO);
    _radiusTouchRect = needDisplay ? [self.mapView convertRegion:coordinateRegion toRectToView:self.mapView] : CGRectZero;
#ifdef DEBUG
    _radiusTouchView.frame = _radiusTouchRect;
    _radiusTouchView.hidden = !needDisplay;
#endif
}

- (void)updateMapRegionForMapSelector {
    MKCoordinateRegion selectorRegion = MKCoordinateRegionForMapRect(_selectorOverlay.boundingMapRect);
    if (_mapRegionCoef <= 0) { // when <=0 keep map zoom unchanged and move map only if not visible. 
        if(!MKMapRectContainsPoint(self.mapView.visibleMapRect, MKMapPointForCoordinate(selectorRegion.center)))
            self.mapView.centerCoordinate = selectorRegion.center;
        return;
    }
    MKCoordinateRegion region;
    region.center = selectorRegion.center;
    region.span = MKCoordinateSpanMake(selectorRegion.span.latitudeDelta * _mapRegionCoef, selectorRegion.span.longitudeDelta * _mapRegionCoef);
    [self.mapView setRegion:region animated:YES];
}

- (void)displaySelectorAnnotationIfNeeded {
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation isKindOfClass:[DBMapSelectorAnnotation class]]) {
            [self.mapView removeAnnotation:annotation];
        }
    }
    
    if (_hidden == NO && ((_editingType == DBMapSelectorEditingTypeFull) || (_editingType == DBMapSelectorEditingTypeCoordinateOnly))) {
        DBMapSelectorAnnotation *selectorAnnotation = [[DBMapSelectorAnnotation alloc] initWithTitle:_title andSubTitle:_subtitle];
        selectorAnnotation.coordinate = _circleCoordinate;
        [self.mapView addAnnotation:selectorAnnotation];
    }
}

#pragma mark - MKMapView Delegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[DBMapSelectorAnnotation class]]) {
        static NSString *selectorIdentifier = @"DBMapSelectorAnnotationView";
        MKPinAnnotationView *selectorAnnotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:selectorIdentifier];
        if (selectorAnnotationView) {
            selectorAnnotationView.annotation = annotation;
        } else {
            
            selectorAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:selectorIdentifier];
        }
        selectorAnnotationView.pinColor = _pinColor;
        selectorAnnotationView.draggable = YES;
        if ([self.dataSource respondsToSelector:@selector(mapSelectorManagerLeftCalloutAccessoryView)]) {
            selectorAnnotationView.leftCalloutAccessoryView = [self.dataSource mapSelectorManagerLeftCalloutAccessoryView];
        }
        if ([self.dataSource respondsToSelector:@selector(mapSelectorManagerRightCalloutAccessoryView)]) {
            selectorAnnotationView.rightCalloutAccessoryView = [self.dataSource mapSelectorManagerRightCalloutAccessoryView];
        }
        
        selectorAnnotationView.canShowCallout = ([annotation title] != nil && [annotation title].length>0);
        selectorAnnotationView.selected = YES;
        return selectorAnnotationView;
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    if (newState == MKAnnotationViewDragStateStarting) {
        _mapViewGestureEnabled = YES;
    }
    if (newState == MKAnnotationViewDragStateEnding) {
        self.circleCoordinate = annotationView.annotation.coordinate;
        if (NO == MKMapRectContainsRect(mapView.visibleMapRect, _selectorOverlay.boundingMapRect)) {
            [self performSelector:@selector(updateMapRegionForMapSelector)
                       withObject:nil
                       afterDelay:.3f];
        }
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    MKOverlayRenderer *overlayRenderer;
    if ([overlay isKindOfClass:[DBMapSelectorOverlay class]]) {
        _selectorOverlayRenderer = [[DBMapSelectorOverlayRenderer alloc] initWithSelectorOverlay:(DBMapSelectorOverlay *)overlay];
        _selectorOverlayRenderer.fillColor = _fillColor;
        _selectorOverlayRenderer.strokeColor = _strokeColor;
        overlayRenderer = _selectorOverlayRenderer;
    } else if ([overlay isKindOfClass:[MKTileOverlay class]]) {
        overlayRenderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
    }
    return overlayRenderer;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [self recalculateRadiusTouchRect];
}

@end
