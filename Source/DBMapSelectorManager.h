//
//  DBMapSelectorManager.h
//  DBMapSelectorViewControllerExample
//
//  Created by Denis Bogatyrev on 27.03.15.
//  Copyright (c) 2015 Denis Bogatyrev. All rights reserved.
//

#import <MapKit/MapKit.h>

@class DBMapSelectorManager;

/*! @brief Determines how the selector can be edited */
typedef NS_ENUM(NSInteger, DBMapSelectorEditingType) {
    DBMapSelectorEditingTypeFull = 0,
    DBMapSelectorEditingTypeCoordinateOnly,
    DBMapSelectorEditingTypeRadiusOnly,
    DBMapSelectorEditingTypeNone,
};

@protocol DBMapSelectorManagerDelegate <NSObject>

@optional
- (void)mapSelectorManager:(DBMapSelectorManager *)mapSelectorManager didChangeCoordinate:(CLLocationCoordinate2D)coordinate;
- (void)mapSelectorManager:(DBMapSelectorManager *)mapSelectorManager didChangeRadius:(CLLocationDistance)radius;
- (void)mapSelectorManagerWillBeginHandlingUserInteraction:(DBMapSelectorManager *)mapSelectorManager;
- (void)mapSelectorManagerDidHandleUserInteraction:(DBMapSelectorManager *)mapSelectorManager;

@end

@protocol DBMapSelectorManagerDataSource <NSObject>

@optional
- (UIView *)mapSelectorManagerLeftCalloutAccessoryView;
- (UIView *)mapSelectorManagerRightCalloutAccessoryView;

@end


@class DBMapSelectorOverlay;
@interface DBMapSelectorManager : NSObject

@property (nonatomic, weak) id<DBMapSelectorManagerDelegate> delegate;
@property (nonatomic, weak) id<DBMapSelectorManagerDataSource> dataSource;
@property (nonatomic, strong, readonly) MKMapView       *mapView;

/*!
 @brief Used to specify the selector editing type
 @discussion Property can equal one of four values:
 DBMapSelectorEditingTypeFull allows to edit coordinate and radius,
 DBMapSelectorEditingTypeCoordinateOnly allows to edit cooordinate only,
 DBMapSelectorEditingTypeRadiusOnly allows to edit radius only,
 DBMapSelectorEditingTypeNone read only mode.
 */
@property (nonatomic, assign) DBMapSelectorEditingType  editingType;

/*! @brief Used to specify the selector coordinate */
@property (nonatomic, assign) CLLocationCoordinate2D    circleCoordinate;

/*! @brief Used to specify the selector radius */
@property (nonatomic, assign) CLLocationDistance        circleRadius;           // default is equal 1000 meter

/*! @brief Used to specify the minimum selector radius */
@property (nonatomic, assign) CLLocationDistance        circleRadiusMin;        // default is equal 100 meter

/*! @brief Used to specify the maximum selector radius */
@property (nonatomic, assign) CLLocationDistance        circleRadiusMax;        // default is equal 10000 meter

/*! 
 @brief Used to specify outer Radis for fill outside
 @discussion Total outer radius will be circleRadius plus this
 */
@property (nonatomic, assign) CLLocationDistance        circleRadiusFillOutside;

/*!
 @brief Used to show a callout
 @discussion title shown in the callout
 */
@property (nonatomic, strong) NSString                   *title;

/*!
 @brief Used to show a callout
 @discussion subtitle shown in the callout
 */
@property (nonatomic, strong) NSString                   *subtitle;

/*! @brief Used to hide or show selector */
@property (nonatomic, getter=isHidden) BOOL             hidden;                 // default is NO

/*! @brief Used to switching between inside or outside filling */
@property (nonatomic, getter=isFillInside) BOOL         fillInside;             // default is YES

/*! 
 @brief Used to specify the selector fill color
 @discussion Color is used to fill the circular map region
 */
@property (nonatomic, strong) UIColor                   *fillColor;

/*! 
 @brief Used to specify the selector stroke color 
 @discussion Color is used to delimit the circular map region
 */
@property (nonatomic, strong) UIColor                   *strokeColor;

/*!
 @brief PinColor
 @discussion Color of the dropped Pin
 */
@property (nonatomic) MKPinAnnotationColor              pinColor;

/*!
 @brief The magnification factor maps region after changing the selector settings
 @discussion It is recommended to set a value greater than 1.f
 */
@property (nonatomic, assign) CGFloat                   mapRegionCoef;          // default is equal 2.f

/*!
 @brief Keep the map coordinates and zoom unchanged unless the selected is not visible map.
 @discussion It is useful when requiring a stable map during user operations
 */
@property (nonatomic) BOOL                              keepMapRegionIntactUnlessInvisible; // default is NO

/*! @brief Indicates whether the radius text should be displayed or not */
@property (nonatomic) BOOL                              shouldShowRadiusText;

/*! @brief It allows to move the selector to a new location via long press gesture */
@property (nonatomic) BOOL                              shouldLongPressGesture; // default is NO

- (instancetype)initWithMapView:(MKMapView *)mapView;
- (void)applySelectorSettings;

#pragma mark - MKMapViewDelegate (forward when relevant)

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation;
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState;
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay;
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated;

@end
