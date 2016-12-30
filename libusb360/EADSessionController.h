/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Provides an interface for communication with an EASession. Also the delegate for the EASession input and output stream objects.
 */

@import Foundation;
@import ExternalAccessory;

extern NSString *EADSessionDataReceivedNotification;

// NOTE: EADSessionController is not threadsafe, calling methods from different threads will lead to unpredictable results
@interface EADSessionController : NSObject <EAAccessoryDelegate, NSStreamDelegate>
@property (nonatomic, strong) NSMutableData *mp4Data;

+ (EADSessionController *)sharedController;

- (void)setupControllerForAccessory:(EAAccessory *)accessory withProtocolString:(NSString *)protocolString;

- (BOOL)openSession;
- (void)closeSession;
- (void)writeMp4:(int)dataType data:(unsigned char*)data len:(int)length pts:(int)pts;
- (void)startWriteMP4;

- (void)writeData:(NSData *)data;

- (NSUInteger)readBytesAvailable;
- (NSData *)readData:(NSUInteger)bytesToRead;
- (int)readData:(unsigned char**)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs;
- (int)writeData:(unsigned char*)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs;

@property (nonatomic, readonly) EAAccessory *accessory;
@property (nonatomic, readonly) NSString *protocolString;

@end
