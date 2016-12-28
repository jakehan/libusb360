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

static NSThread *listenerThread;

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

- (void)addObserverForAccessory
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
    
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

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
        
        returnValue = usb360_api_setStreamCallBack(usbHandler,streamCallBackUSB360,nil);
        if (returnValue != 0) {
            NSLog(@"usb360_api_setStreamCallBack Error %d",returnValue);
        }
    }
}

//- (int)sendCMDUSB360:(int)cmd content:(NSString *)cmdContent length:(int)cmdLen callback:(int*)callbackFunc parameter:(void*)param
//{
//    int returnValue = usb360_api_sendCmd(usbHandler, cmd, (unsigned char*)[cmdContent UTF8String], cmdLen,callbackFunc,param);
//    
//    return returnValue;
//}

- (int)destroyUSB360
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    if (nil == usbHandler) {
        NSLog(@"usbHandler already released\n");
    }
    int iRet = usb360_api_destroy(usbHandler);
    NSLog(@"iRet %d\n",iRet);

    return iRet;
}

- (void)_accessoryDidConnect:(NSNotification *)notification {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    EAAccessory *connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    NSLog(@"name %@,manufacturer %@",[connectedAccessory name],[connectedAccessory manufacturer]);
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo = @{ USB360EAAccessoryKey: ((nil == [[notification userInfo] objectForKey:EAAccessoryKey]) ? @"USB360EAAccessoryKey" :[[notification userInfo] objectForKey:EAAccessoryKey]), USB360EAAccessorySelectedKey: ((nil == [[notification userInfo] objectForKey:EAAccessorySelectedKey])?@"EAAccessorySelectedKey":[[notification userInfo] objectForKey:EAAccessorySelectedKey])};
    [notificationCenter postNotificationName:USB360EAAccessoryDidConnectNotification object:nil userInfo:userInfo];
    
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    
    NSLog(@"name %@,manufacturer %@",[disconnectedAccessory name],[disconnectedAccessory manufacturer]);
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo = @{ USB360EAAccessoryKey: ((nil == [[notification userInfo] objectForKey:EAAccessoryKey]) ? @"USB360EAAccessoryKey" :[[notification userInfo] objectForKey:EAAccessoryKey]), USB360EAAccessorySelectedKey: ((nil == [[notification userInfo] objectForKey:EAAccessorySelectedKey])?@"EAAccessorySelectedKey":[[notification userInfo] objectForKey:EAAccessorySelectedKey])};
    [notificationCenter postNotificationName:USB360EAAccessoryDidDisconnectNotification object:nil userInfo:userInfo];
}

int streamCallBackUSB360(void *par, int iCh, unsigned char *pucData, int iDataLen, unsigned int uiPtsMs)
{
    printf("streamCallBackUSB360 called\n");
    
    return 0;
}

int receiveUSB360(void *pOint, unsigned char **pucBuffer, int iLen, int iTimeOut)
{
    NSLog(@"receiveUSB360\n");
    EADSessionController *thiz = (__bridge EADSessionController *)pOint;
    
    if (NULL == *pucBuffer)
    {
        *pucBuffer = (unsigned char *)malloc(sizeof(iLen));
        if (NULL == *pucBuffer) {
            NSLog(@"Alloc Fail For pucBuffer\n");
            
            return -1;
        }
    }
    
    return [thiz readData:*pucBuffer Length:iLen timeout:iTimeOut];
    
//    return [thiz readData:*pucBuffer Length:iLen timeout:iTimeOut];
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
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return self.dataLength;
}

-(int)setLensParam:(NSString *)aLen
{
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
    
//    listenerThread = [[NSThread alloc] initWithTarget:self
//                                             selector:@selector(listenerThread)
//                                               object:nil];
//    [listenerThread start];
    
    return returnValue;
}

- (int)startStreamingVideo
{
    return usb360_cmdsdk_sendStreamStart(usbHandler);
}

- (int)stopStreamingVideo
{
    return usb360_cmdsdk_sendStreamStop(usbHandler);
}

- (void)listenerThread
{ @autoreleasepool
    {
        NSLog(@"ListenerThread: Started");
        
        // We can't run the run loop unless it has an associated input source or a timer.
        // So we'll just create a timer that will never fire - unless the server runs for a decades.
        [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow]
                                         target:self
                                       selector:@selector(readOriginalData)
                                       userInfo:nil
                                        repeats:YES];
        
        NSLog(@"ListenerThread: Stopped");
    }
}

- (void)readOriginalData
{
    while (1) {
        int len = 1024;
        unsigned char *stream = (unsigned char *)malloc(sizeof(len));
        memset(stream, 0, len);
        [self fillAudioBuffer:stream Length:len];
        
        [[NSRunLoop currentRunLoop] run];
    }

}

- (void)fillAudioBuffer:(unsigned char *)stream Length:(int)len
{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    documentsPath = [documentsPath stringByAppendingPathComponent:@"AP515_sw_wav_-6dBFS.wav"];
    
    file  = fopen([documentsPath UTF8String], "rb");
    fseek(file, 0, SEEK_SET);
    pcmDataBuffer = malloc(EVERY_READ_LENGTH);

    size_t readLength = fread(pcmDataBuffer, 1, len, file);
    
    if (readLength == 0) {
        NSLog(@"Read Audio Data Finished!");
    }
    
    for(int i=0;i<readLength;i++)
    {
        stream[i] = pcmDataBuffer[i];
    }
    
    [self onReadFrame:(__bridge void *)(self) channel:1 data:(char *)stream length:(int)readLength pts:0];
}



-(int)releaseStream
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    [self startStreamingVideo];
    
    return true;

}

- (int)setExposureMode:(USB360ExposureModeType)mode parameter:(USB360CameraModeType)parameter
{
    //parameter: [video/photo] 
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return true;
}

- (int)setWhiteBalanceMode:(USB360WhiteBalanceModeType)mode parameter:(USB360CameraModeType)parameter
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return true;
}

- (int)getCameraMode
{
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return 0;
}

- (int)getCameraElectricityPercent
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return 9;
}

- (int)requestFWUpgrate:(NSString*)fwFile
{
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
    NSLog(@"%@",NSStringFromSelector(_cmd));
    int ret = 0;
    ret = usb360_cmdsdk_sendSetTime(usbHandler, NULL);
    
    return ret;
}

- (int)setCameraName:(NSString*)name
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    NSLog(@"%@",name);
    
    self.usb360CameraName = [name copy];
    
    return true;
}

- (int)setCameraIQ:(int)iISO awb:(int)iAWB ev:(int)iEV st:(int)iST
{
    return usb360_cmdsdk_sendSetIQ(usbHandler, iISO, iAWB, iEV, iST);
}

- (int)getCameraIO
{
    int ret = 0;
    char acInfo[512] = {0};
    
    ret = usb360_cmdsdk_sendGetIQ(usbHandler, acInfo);
    NSString *iqParamter = [NSString stringWithUTF8String:acInfo];
    NSLog(@"iqParamter %@",iqParamter);
    
    return ret;
}

- (int)setTimeOfAutoPowerOff:(int)time
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    NSLog(@"%d",time);
    
    return true;
}

- (int)requestCameraPowerOff
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    return 0;
}

-(int)destroy
{
    NSLog(@"%@",NSStringFromSelector(_cmd));

    return usb360_api_destroy(usbHandler);
}

- (void)receiveFrame:(int)channel data:(char*)data length:(int)lenght pts:(long)pts
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

#pragma callback functions

-(void)onReadFrame:(void*)par channel:(int)channel data:(char*)data length:(int)lenght pts:(long)ptsMS
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    [[(__bridge USB360Manager*)par delegate] receiveFrame:channel data:data length:lenght pts:ptsMS];
}



@end
