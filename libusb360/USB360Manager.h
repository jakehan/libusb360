//
//  USB360Manager.h
//  libusb360
//
//  Created by hanbobiao on 16/11/3.
//  Copyright © 2016年 My Company. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString *const USB360EAAccessoryDidConnectNotification = @"USB360EAAccessoryDidConnectNotification";
NSString *const USB360EAAccessoryDidDisconnectNotification = @"USB360EAAccessoryDidDisconnectNotification";
NSString *const USB360EAAccessoryKey = @"USB360EAAccessoryKey"; // EAAccessory
NSString *const USB360EAAccessorySelectedKey = @"USB360EAAccessorySelectedKey"; // EAAccessory

typedef enum {
    ExposureShutterSpeedMode = 0,
    ExposureISOMode = 1,
    ExposureEvbiasMode
}USB360ExposureModeType;

typedef enum {
    CameraVideoMode = 0,
    CameraPhotoMode = 1,
}USB360CameraModeType;

typedef enum {
    WhiteBalanceAutoMode = 0,
    WhiteBalanceIncandescentLampMode = 1,
    WhiteBalanceCloudlessDayMode = 4,
    WhiteBalanceCloudyMode = 5,
    WhiteBalanceFlashLampMode = 8,
    WhiteBalanceFluorescentLampMode = 9,
    WhiteBalanceUnderWaterMode = 13,
    WhiteBalanceOutdoorsMode = 14
}USB360WhiteBalanceModeType;

@interface USB360Manager : NSObject

@property (nonatomic,retain) id delegate;

+ (USB360Manager *)sharedManager;

-(NSString*)requestDeviceInfo;
-(NSString*)requestStreamInfo;
-(NSString*)getLensParam;
-(int)setLensParam:(NSString *)aLen;
-(int)obtainStream;
-(int)releaseStream;
- (int)setExposureMode:(USB360ExposureModeType)mode parameter:(USB360CameraModeType)parameter;
- (int)setWhiteBalanceMode:(USB360WhiteBalanceModeType)mode parameter:(USB360CameraModeType)parameter;

//「0：Video；1:Photo」
- (int)getCameraMode;

- (int)getCameraElectricityPercent;
- (int)requestFWUpgrate:(NSString*)file;

//获取系统时间设置给Camera，格式为（2016/01/28 19:00:00）
- (int)setTime;

- (int)setCameraName:(NSString*)name;
- (int)setTimeOfAutoPowerOff:(int)time;

//「0:OK，其他:Fail」
- (int)requestCameraPowerOff;

-(int)destroy;

//get video/audio stream delegate function
- (void)receiveFrame:(int)channel data:(char*)data length:(int)lenght pts:(long)pts;

@end
