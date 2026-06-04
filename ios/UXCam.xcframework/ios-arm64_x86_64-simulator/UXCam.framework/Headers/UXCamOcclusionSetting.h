//
//  UXCamOcclusionSetting.h
//  UXCam
//
//  Created by Ankit Karna on 22/01/2022.
//  Copyright © 2022 UXCam Inc. All rights reserved.
//

#ifndef UXCamOcclusionSetting_h
#define UXCamOcclusionSetting_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UXOcclusionType) {
    UXOcclusionTypeOccludeAllTextFields = 1,
    UXOcclusionTypeOverlay = 2,
    UXOcclusionTypeBlur = 3,
    UXOcclusionTypeUnknown = 4,
    UXOcclusionTypeAITextOcclusion = 5
};


typedef NS_ENUM(NSInteger, UXOcclusionCategory) {
    UXOcclusionCategoryTextOnly,
    UXOcclusionCategoryScreen
};

@protocol UXCamOcclusionSetting <NSObject>

@property (readonly) UXOcclusionType type;
@property (readonly) UXOcclusionCategory category;

@optional
/// Occlusion name for timeline metadata (e.g. "blur", "overlay"). Return nil to omit metadata.
@property (readonly, nullable) NSString *metadataName;
/// Occlusion properties for timeline metadata (e.g. {"br": 50}). Return nil to omit.
@property (readonly, nullable) NSDictionary<NSString *, id> *metadataProperties;

@end

@protocol UXGestureRecordable <NSObject>

@property (nonatomic) BOOL hideGestures;

@end


#endif /* UXCamOcclusionSetting_h */
