//
//  USB360Manager.m
//  libusb360
//
//  Created by hanbobiao on 16/11/3.
//  Copyright © 2016年 My Company. All rights reserved.
//

#import "USB360Manager.h"
#import <ExternalAccessory/ExternalAccessory.h>
#import "EADSessionController.h"
#import "usb360.h"
//#import "USB360SDK/usb360.h"
//#import "USB360SDK/usb360_cmd_sdk.h"

#define EVERY_READ_LENGTH (1024) //每次从文件读取的长度



NSString *const USB360EAAccessoryDidConnectNotification = @"USB360EAAccessoryDidConnectNotification";
NSString *const USB360EAAccessoryDidDisconnectNotification = @"USB360EAAccessoryDidDisconnectNotification";
NSString *const USB360EAAccessoryKey = @"USB360EAAccessoryKey"; // EAAccessory
NSString *const USB360EAAccessorySelectedKey = @"USB360EAAccessorySelectedKey"; // EAAccessory

@interface USB360Manager()
{
    FILE *file;//pcm源文件
    Byte *pcmDataBuffer;//pcm的读文件数据区
    
    void *usbHandler;
}

@property (nonatomic,copy) NSString *dataLength;
@property (nonatomic,copy) NSString *usb360CameraName;
@property (nonatomic, strong) NSMutableArray *accessoryList;
@property (nonatomic, strong) EAAccessory *selectedAccessory;
@property (nonatomic, strong) EADSessionController *eaSessionController;
@property (nonatomic, strong) NSArray *supportedProtocolsStrings;

@end

@implementation USB360Manager


+ (USB360Manager *)sharedManager
{
    static USB360Manager *sessionManager = nil;
    if (sessionManager == nil) {
        NSLog(@"%@",NSStringFromSelector(_cmd));
        NSLog(@"Init Once\n");
        sessionManager = [[USB360Manager alloc] init];

        [sessionManager addObserverForAccessory];
        
        //注册读取、发送数据回调函数
//        usb360_api_addReceiveEndPoint(void *pvusb, void* point, int (*receive)(void *pOint, unsigned char **pucBuffer, int iLen, int iTimeOut) )
//        usb360_api_addSendEndPoint   (void *pvusb, void* point, int (*send)   (void *pOint, unsigned char  *pucBuffer, int iLen, int iTimeOut))
        
    }
    
    return sessionManager;
}

#pragma mark ****************** Interface functions ******************

- (void)initEASession
{
    _eaSessionController = [EADSessionController sharedController];
    _accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    NSLog(@"accessoryList %@",_accessoryList);
    
    if ([_accessoryList count] == 0) {
        NSLog(@"Not Get Accessory List %@",_accessoryList);
    } else {
        NSLog(@"Get Accessory List %@",_accessoryList);
        self.selectedAccessory = [_accessoryList objectAtIndex:0];
    }
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    self.supportedProtocolsStrings = [mainBundle objectForInfoDictionaryKey:@"UISupportedExternalAccessoryProtocols"];
    
    [self initSelectedAccessoryProtocol];
}




- (void)initUSB360Handler
{
    if (usbHandler == nil) {
        usbHandler = usb360_api_new();
        int returnValue = [self addSendPoint];
        if (returnValue != 0) {
            NSLog(@"usb360_api_addSendEndPoint Error %d",returnValue);
        }
        
        returnValue = [self addReceivePoint];
        if (returnValue != 0) {
            NSLog(@"usb360_api_addReceiveEndPoint Error %d",returnValue);
        }
        
        returnValue = usb360_api_setStreamCallBack(usbHandler,streamCallBackUSB360,(__bridge void *)(self).eaSessionController);
        if (returnValue != 0) {
            NSLog(@"usb360_api_setStreamCallBack Error %d",returnValue);
        }
    }
}

- (int)destroyUSB360
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));

    int iRet = usb360_api_destroy(usbHandler);
    NSLog(@"iRet %d\n",iRet);

    return iRet;
}



-(NSString*)requestDeviceInfo
{
    if (nil == usbHandler) {
        return @"Not Init USB Handler";
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    int ret = 0;
    char acName[64] = {0};
    char acSn[64]   = {0};
    char acFw[64]   = {0};
    
    ret = usb360_cmdsdk_sendGetDeviceInfo(usbHandler,acName,acSn,acFw);
    NSLog(@"return value ret:%d usbHandler %p",ret,usbHandler);
    
    NSString *deviceInfo = [NSString stringWithUTF8String:acName];
    NSString *snInfo = [NSString stringWithUTF8String:acSn];
    NSString *fwInfo = [NSString stringWithUTF8String:acFw];
    deviceInfo = [[deviceInfo stringByAppendingString:snInfo] stringByAppendingString:fwInfo];
    
    return deviceInfo;
}

-(NSString*)requestStreamInfo
{
    if (nil == usbHandler) {
        return @"Not Init USB Handler";
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));

    int ret = 0;
    char acInfo[512] = {0};

    ret = usb360_cmdsdk_sendGetStreamInfo(usbHandler, acInfo);
    
    NSString *deviceInfo = [NSString stringWithUTF8String:acInfo];

    return deviceInfo;
}

-(NSString*)getLensParam
{
    if (nil == usbHandler) {
        return @"Not Init USB Handler";
    }

    NSLog(@"%@",NSStringFromSelector(_cmd));

    return self.dataLength;
}

-(int)setLensParam:(NSString *)aLen
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }

    NSLog(@"%@ %@",NSStringFromSelector(_cmd),aLen);
    
    int ret = 0;
    
    ret = usb360_cmdusr_sendSetLens(usbHandler, (char*)[aLen UTF8String]);
    
    if(0 == ret)
    {
        self.dataLength = [aLen copy];
    }
    
    return ret;
}

-(int)obtainStream
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    int returnValue = [self startStreamingVideo];
    
    return returnValue;
}

-(int)releaseStream
{
    if (nil == usbHandler) {
        NSLog(@"USB360ErrorCodeNoInitUSBHander\n");
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    [self stopStreamingVideo];
    
    [_eaSessionController startWriteMP4];
    
    return true;

}


- (int)setExposureMode:(USB360ExposureModeType)mode parameter:(USB360CameraModeType)parameter
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    //parameter: [video/photo] 
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return true;
}

- (int)setWhiteBalanceMode:(USB360WhiteBalanceModeType)mode parameter:(USB360CameraModeType)parameter
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return true;
}

- (int)getCameraMode
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return 0;
}

- (int)getCameraElectricityPercent
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return 9;
}

- (int)requestFWUpgrate:(NSString*)fwFile
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    NSLog(@"upgrate fw\n");

    int ret = 0;
    ret = usb360_cmdsdk_sendUpdate(usbHandler, (char *)[fwFile UTF8String]);
    
    if (0 != ret) {
        NSLog(@"usb360_cmdsdk_sendUpdate Fail\n");
    }
    
    return ret;
}

- (int)setTime
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    int ret = 0;
    ret = usb360_cmdsdk_sendSetTime(usbHandler, NULL);
    
    return ret;
}

- (int)setCameraName:(NSString*)name
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    NSLog(@"%@",name);
    
    self.usb360CameraName = [name copy];
    
    return true;
}

- (int)setCameraIQ:(int)iISO awb:(int)iAWB ev:(int)iEV st:(int)iST
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    return usb360_cmdsdk_sendSetIQ(usbHandler, iISO, iAWB, iEV, iST);
}

- (int)getCameraIO
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    int ret = 0;
    char acInfo[512] = {0};
    
    ret = usb360_cmdsdk_sendGetIQ(usbHandler, acInfo);
    NSString *iqParamter = [NSString stringWithUTF8String:acInfo];
    NSLog(@"iqParamter %@",iqParamter);
    
    return ret;
}

- (int)setTimeOfAutoPowerOff:(int)time
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    NSLog(@"%d",time);
    
    return true;
}

- (int)requestCameraPowerOff
{
    if (nil == usbHandler) {
        return USB360ErrorCodeNoInitUSBHander;
    }
    
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return 0;
}

#pragma mark ****************** Utility functions ******************

- (void)_accessoryDidConnect:(NSNotification *)notification {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    EAAccessory *connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    NSLog(@"name %@,manufacturer %@",[connectedAccessory name],[connectedAccessory manufacturer]);
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo = @{ USB360EAAccessoryKey: ((nil == [[notification userInfo] objectForKey:EAAccessoryKey]) ? @"USB360EAAccessoryKey1" :[[notification userInfo] objectForKey:EAAccessoryKey]), USB360EAAccessorySelectedKey: ((nil == [[notification userInfo] objectForKey:EAAccessorySelectedKey])?@"EAAccessorySelectedKey1":[[notification userInfo] objectForKey:EAAccessorySelectedKey])};
    [notificationCenter postNotificationName:USB360EAAccessoryDidConnectNotification object:nil userInfo:userInfo];
    
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    NSLog(@"name %@,manufacturer %@",[disconnectedAccessory name],[disconnectedAccessory manufacturer]);
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo = @{ USB360EAAccessoryKey: ((nil == [[notification userInfo] objectForKey:EAAccessoryKey]) ? @"USB360EAAccessoryKey1" :[[notification userInfo] objectForKey:EAAccessoryKey]), USB360EAAccessorySelectedKey: ((nil == [[notification userInfo] objectForKey:EAAccessorySelectedKey])?@"EAAccessorySelectedKey1":[[notification userInfo] objectForKey:EAAccessorySelectedKey])};
    [notificationCenter postNotificationName:USB360EAAccessoryDidDisconnectNotification object:nil userInfo:userInfo];
}

- (void)addObserverForAccessory
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

- (int)startStreamingVideo
{
    return usb360_cmdsdk_sendStreamStart(usbHandler);
}

- (int)stopStreamingVideo
{
    return usb360_cmdsdk_sendStreamStop(usbHandler);
}

- (int)addReceivePoint
{
    int iRet = 0;
    
    iRet = usb360_api_addReceiveEndPoint(usbHandler, (__bridge void *)([EADSessionController sharedController]), receiveUSB360);
    
    return iRet;
}

- (int)addSendPoint
{
    int iRet = 0;
    
    iRet = usb360_api_addSendEndPoint(usbHandler, (__bridge void *)([EADSessionController sharedController]), sendUSB360);
    
    return iRet;
}


- (void)initSelectedAccessoryProtocol
{
    NSArray *protocolStrings = [_selectedAccessory protocolStrings];
    NSLog(@"selectedAccessory protocolStrings %@ %@", protocolStrings,self.supportedProtocolsStrings);
    
    for(NSString *protocolString in protocolStrings)
    {
        if (_selectedAccessory)
        {
            BOOL  matchFound = FALSE;
            for ( NSString *item in self.supportedProtocolsStrings)
            {
                if ([item compare: protocolString] == NSOrderedSame)
                {
                    matchFound = TRUE;
                    //                    NSLog(@"match found - protocolString %@", protocolString);
                    //                    [_eaSessionController setupControllerForAccessory:_selectedAccessory withProtocolString:item];
                    break;
                }
            }
            
            if (matchFound == FALSE)
            {
                NSLog(@"Not Found Match Protocol String\n");
                _selectedAccessory = nil;
            }
            else
            {
                [_eaSessionController setupControllerForAccessory:_selectedAccessory
                                               withProtocolString:protocolString];
                
                NSLog(@"Found Match Protocol String  %@\n", protocolString);
                [_eaSessionController openSession];
            }
        }
        
        _selectedAccessory = nil;
    }
}

#pragma mark ****************** callback functions ******************

- (void)receiveFrame:(int)channel data:(char*)data length:(int)lenght pts:(long)pts
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

-(void)onReadFrame:(void*)par channel:(int)channel data:(char*)data length:(int)lenght pts:(long)ptsMS
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    [[(__bridge USB360Manager*)par delegate] receiveFrame:channel data:data length:lenght pts:ptsMS];
}

int streamCallBackUSB360(void *par, int iCh, unsigned char *pucData, int iDataLen, unsigned int uiPtsMs)
{
    EADSessionController *thiz = (__bridge EADSessionController *)par;
    [thiz writeMp4:iCh data:pucData len:iDataLen pts:uiPtsMs];
    
    printf("streamCallBackUSB360 called iCh %d, iDataLen %d pts %d\n",iCh,iDataLen,uiPtsMs);
    
    return 0;
}

int receiveUSB360(void *pOint, unsigned char **pucBuffer, int iLen, int iTimeOut)
{
//    NSLog(@"receiveUSB360\n");
    EADSessionController *thiz = (__bridge EADSessionController *)pOint;
    
    if (NULL == *pucBuffer)
    {
//        NSLog(@"Alloc For pucBuffer\n");

        *pucBuffer = (unsigned char *)malloc(iLen);
        memset(*pucBuffer, 0, iLen);
        
        if (NULL == *pucBuffer) {
            NSLog(@"Alloc Fail For pucBuffer\n");
            
            return -1;
        }
    }
    
    return [thiz readData:pucBuffer Length:iLen timeout:iTimeOut];
}

int sendUSB360(void *pOint, unsigned char *pucBuffer, int iLen, int iTimeOut)
{
    NSLog(@"sendUSB360\n");
    
    EADSessionController *thiz = (__bridge EADSessionController *)pOint;
    
    if (NULL == pucBuffer)
    {
        return -1;
    }
    
    NSData *data = [NSData dataWithBytes:pucBuffer length:iLen];
    if (NULL == data) {
        iTimeOut = -1;
        return -1;
    }
    
    return [thiz writeData:pucBuffer Length:iLen timeout:iTimeOut];
}


@end
