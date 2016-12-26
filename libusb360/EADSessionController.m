/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Provides an interface for communication with an EASession. Also the delegate for the EASession input and output stream objects.
 */

#import "EADSessionController.h"
@interface EADSessionController ()

@property (nonatomic, strong) EASession *session;
@property (nonatomic, strong) NSMutableData *writeData;
@property (nonatomic, strong) NSMutableData *readData;

@end

NSString *EADSessionDataReceivedNotification = @"EADSessionDataReceivedNotification";

@implementation EADSessionController

#pragma mark Internal

// low level write method - write data to the accessory while there is space available and data to write
- (void)_writeData {
    while (([[_session outputStream] hasSpaceAvailable]) && ([_writeData length] > 0))
    {
        NSInteger bytesWritten = [[_session outputStream] write:[_writeData bytes] maxLength:[_writeData length]];
        if (bytesWritten == -1)
        {
            NSLog(@"write error");
            break;
        }
        else if (bytesWritten > 0)
        {
            [_writeData replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
            NSLog(@"bytesWritten %ld", (long)bytesWritten);

        }
    }
}

// low level read method - read data while there is data and space available in the input buffer
- (void)_readData {
#define EAD_INPUT_BUFFER_SIZE 128
//#define EAD_INPUT_BUFFER_SIZE (18 * 1024)

    uint8_t buf[EAD_INPUT_BUFFER_SIZE];
    while ([[_session inputStream] hasBytesAvailable])
    {
        NSInteger bytesRead = [[_session inputStream] read:buf maxLength:EAD_INPUT_BUFFER_SIZE];
        if (_readData == nil) {
            _readData = [[NSMutableData alloc] init];
        }
        [_readData appendBytes:(void *)buf length:bytesRead];
        NSLog(@"read %ld bytes from input stream", (long)bytesRead);
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:EADSessionDataReceivedNotification object:self userInfo:nil];
}

- (int)readData:(unsigned char*)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs
{
    int iOffset = 0;
    
    NSDate *iStartTime = [NSDate date];
    
    while (1)
    {
        if ([[_session inputStream] hasBytesAvailable])
        {
            NSInteger bytesRead = [[_session inputStream] read:(pucBuffer + iOffset) maxLength:aLen];
            
            iOffset += bytesRead;
            
            if (iOffset == aLen)
            {
                NSData *data = [NSData dataWithBytes:pucBuffer length:aLen];
                NSLog(@"bytes in hex: %@", [data description]);
                
                NSString *sendString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                if (NULL == sendString) {
                    sendString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    
                    if(NULL != sendString)
                    {
                        int dec = [sendString intValue];
                        NSLog(@"HEX = %X", dec);
                    }
                    else
                    {
                        NSLog(@"Convert NSData To NSString Fail\n");
                    }
                }
                
                NSLog(@"data received %@",sendString);

                break;
            }
        }
        else
        {
            sleep(10);
        }
        
        int iEndTime = [[NSDate date] timeIntervalSinceDate:iStartTime];
        if (iEndTime > iTimeoutMs)
        {
            iOffset = -2;
            break;
        }
    }
//    while ([[_session inputStream] hasBytesAvailable])
//    {
//        NSInteger bytesRead = [[_session inputStream] read:(pucBuffer + iOffset) maxLength:aLen];
//        
//        iOffset += bytesRead;
//        
//        if (iOffset == aLen)
//        {
//            break;
//        }
//        NSLog(@"read %ld bytes from input stream", (long)bytesRead);
//    }
    
    return iOffset;
}

- (int)writeData:(unsigned char*)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs
{
    int iOffset = 0;
    NSDate *iStartTime = [NSDate date];
    
    while (1)
    {
        if (([[_session outputStream] hasSpaceAvailable]) && (iOffset < aLen))
        {
            NSInteger bytesWritten = [[_session outputStream] write:(pucBuffer + iOffset) maxLength:aLen];
            
            if (bytesWritten == -1)
            {
                NSLog(@"write error");
                break;
            }
            else if (bytesWritten > 0)
            {
                iOffset += bytesWritten;
            }
        }
        else
        {
            sleep(10);
        }
        
        int iEndTime = [[NSDate date] timeIntervalSinceDate:iStartTime];
        if (iEndTime > iTimeoutMs)
        {
            iOffset = -2;
            break;
        }
    }
    
//    while (([[_session outputStream] hasSpaceAvailable]) && (iOffset < aLen))
//    {
//        NSInteger bytesWritten = [[_session outputStream] write:(pucBuffer + iOffset) maxLength:aLen];
//        
//        if (bytesWritten == -1)
//        {
//            NSLog(@"write error");
//            break;
//        }
//        else if (bytesWritten > 0)
//        {
//            iOffset += bytesWritten;
//        }
//    }
    
    return iOffset;
}

#pragma mark Public Methods

+ (EADSessionController *)sharedController
{
    static EADSessionController *sessionController = nil;
    if (sessionController == nil) {
        sessionController = [[EADSessionController alloc] init];
    }

    return sessionController;
}

- (void)dealloc
{
    [self closeSession];
    [self setupControllerForAccessory:nil withProtocolString:nil];
}

// initialize the accessory with the protocolString
- (void)setupControllerForAccessory:(EAAccessory *)accessory withProtocolString:(NSString *)protocolString
{
    NSLog(@"setupControllerForAccessory entered protocolString is %@", protocolString);
    _accessory = accessory;
    _protocolString = [protocolString copy];
}

// open a session with the accessory and set up the input and output stream on the default run loop
- (BOOL)openSession
{
    NSLog(@"%@",NSStringFromSelector(_cmd));

    [_accessory setDelegate:self];
    _session = [[EASession alloc] initWithAccessory:_accessory forProtocol:_protocolString];

    if (_session)
    {
        [[_session inputStream] setDelegate:self];
        [[_session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session inputStream] open];

        [[_session outputStream] setDelegate:self];
        [[_session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[_session outputStream] open];
    }
    else
    {
        NSLog(@"creating session failed");
    }

    return (_session != nil);
}

// close the session with the accessory.
- (void)closeSession
{
    [[_session inputStream] close];
    [[_session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_session inputStream] setDelegate:nil];
    [[_session outputStream] close];
    [[_session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [[_session outputStream] setDelegate:nil];

    _session = nil;

    _writeData = nil;
    _readData = nil;
}

// high level write data method
- (void)writeData:(NSData *)data
{
    if (_writeData == nil) {
        _writeData = [[NSMutableData alloc] init];
    }

    [_writeData appendData:data];
    [self _writeData];
}

// high level read method 
- (NSData *)readData:(NSUInteger)bytesToRead
{
    NSData *data = nil;
    if ([_readData length] >= bytesToRead) {
        NSRange range = NSMakeRange(0, bytesToRead);
        data = [_readData subdataWithRange:range];
        [_readData replaceBytesInRange:range withBytes:NULL length:0];
    }
    return data;
}

// get number of bytes read into local buffer
- (NSUInteger)readBytesAvailable
{
    return [_readData length];
}

#pragma mark EAAccessoryDelegate
- (void)accessoryDidDisconnect:(EAAccessory *)accessory
{
    // do something ...
}

#pragma mark NSStreamDelegateEventExtensions

// asynchronous NSStream handleEvent method
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    NSLog(@"%lu",(unsigned long)eventCode);
    
    switch (eventCode) {
        case NSStreamEventNone:
            NSLog(@"NSStreamEventNone");
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"NSStreamEventOpenCompleted");
            break;
        case NSStreamEventHasBytesAvailable:
            NSLog(@"NSStreamEventHasBytesAvailable");
            [self _readData];
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"NSStreamEventHasSpaceAvailable");
            [self _writeData];
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"NSStreamEventErrorOccurred");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"NSStreamEventEndEncountered");
            break;
        default:
            break;
    }
}

@end
