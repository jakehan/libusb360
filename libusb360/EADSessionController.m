/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Provides an interface for communication with an EASession. Also the delegate for the EASession input and output stream objects.
 */

#import "EADSessionController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface EADSessionController ()

@property (nonatomic, strong) EASession *session;
@property (nonatomic, strong) NSMutableData *writeData;
@property (nonatomic, strong) NSMutableData *readData;

@property (nonatomic,strong) AVAssetWriter * assetWriter;
@property (nonatomic,strong) AVAssetWriterInput * assetWriterAudioInput;
@property (nonatomic,strong) AVAssetWriterInput * assetWriterVideoInput;

@end

NSString *EADSessionDataReceivedNotification = @"EADSessionDataReceivedNotification";

#define EAD_INPUT_BUFFER_SIZE (20 * 1024)

@implementation EADSessionController

#pragma mark Internal


-(void)configAssetWriter

{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"]; //每次启动后都保存一个新的日志文件中
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSString * storePath = [[paths objectAtIndex:0] stringByAppendingFormat:@"/%@.mp4",dateStr];
    NSError * outError = nil;
    
    unlink([storePath UTF8String]);
    
    if (storePath) {
        
        _assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:storePath] fileType:AVFileTypeMPEG4 error:&outError];
        
        if (nil != outError) {
            NSLog(@"create assetWriter fail %@",outError);
        }
        
        //指定编码格式，像素宽高等信息
        NSDictionary *compressSetting = @{
                                          AVVideoCompressionPropertiesKey:[NSDictionary dictionaryWithObjectsAndKeys:
//                                                                           [NSNumber numberWithInt: 256*1024], AVVideoAverageBitRateKey,// 256kbps
                                                                           [NSNumber numberWithInt: 30], AVVideoMaxKeyFrameIntervalKey,// write at least one keyframe every 30 frames
                                                                           nil],
                                          AVVideoCodecKey:AVVideoCodecH264,
                                          
                                          AVVideoWidthKey:@3840,
                                          
                                          AVVideoHeightKey:@1920
                                          
                                          };
        
        //初始化写入器，并制定了媒体格式
        _assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:compressSetting];
        _assetWriterVideoInput.expectsMediaDataInRealTime = NO;
        //添加写入器
        
        [_assetWriter addInput:_assetWriterVideoInput];
        
        //audio info
        
        AudioChannelLayout acl;
        
        bzero( &acl, sizeof(acl));
        
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        
        NSDictionary *audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                             
                                             [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                             
                                             [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                             
                                             [NSNumber numberWithFloat: 48000], AVSampleRateKey,
                                             
                                             [NSNumber numberWithInt: 60000], AVEncoderBitRateKey,
                                             
                                             [NSData dataWithBytes:&acl length:sizeof(acl)], AVChannelLayoutKey,
                                             
                                             nil];
        
        _assetWriterAudioInput = [AVAssetWriterInput
                            
                            assetWriterInputWithMediaType: AVMediaTypeAudio
                            
                            outputSettings: audioOutputSettings] ;
        
        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
        
        [_assetWriter addInput:_assetWriterAudioInput];
        
    }
}

-(void)addH264NAL:(NSData *)nal pts:(int)pts
{
    
    dispatch_queue_t recordingQueue = dispatch_queue_create("mediaDataInputQueue", NULL);
    dispatch_async(recordingQueue, ^{
        //Adapting the raw NAL into a CMSampleBuffer
        CMSampleBufferRef sampleBuffer = NULL;
        CMBlockBufferRef blockBuffer = NULL;
        CMFormatDescriptionRef formatDescription = NULL;
        CMItemCount numberOfSampleTimeEntries = 1;
        CMItemCount numberOfSamples = 1;
        CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_H264, 3840, 1920, nil, &formatDescription);
        
        OSStatus result = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorMalloc, NULL, [nal length], kCFAllocatorDefault, NULL, 0, [nal length], kCMBlockBufferAssureMemoryNowFlag, &blockBuffer);
        if(result != noErr)
        {
            NSLog(@"Error creating CMBlockBuffer");
            return;
        }
        result = CMBlockBufferReplaceDataBytes([nal bytes], blockBuffer, 0, [nal length]);
        if(result != noErr)
        {
            NSLog(@"Error filling CMBlockBuffer");
            return;
        }
        const size_t sampleSizes = [nal length];
        
        CMSampleTimingInfo _timingInfo;
        CMSampleTimingInfo *timingInfo = &_timingInfo;
        CMItemCount itemCount = 1, timingArrayEntriesNeededOut;
        CMSampleBufferGetSampleTimingInfoArray(sampleBuffer,
                                               itemCount,
                                               timingInfo,
                                               &timingArrayEntriesNeededOut);
        
        result = CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, YES, NULL, NULL, formatDescription, numberOfSamples, numberOfSampleTimeEntries, timingInfo, 1, &sampleSizes, &sampleBuffer);
        
        if(result != noErr)
        {
            NSLog(@"Error creating CMSampleBuffer");
        }
        if (sampleBuffer) {
            
            [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo pts:pts];
        }
        
    });
    
}


- (void) writeSampleBuffer:(CMSampleBufferRef)buffer ofType:(NSString *)mediaType pts:(int)pts
{
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
//    CMTime presentationTime = CMTimeMake(pts,30);
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(buffer);
    
    if (CMSampleBufferDataIsReady(buffer))
    {
        NSLog(@"assetWriter status %ld\n",(long)self.assetWriter.status);
        
        if ( self.assetWriter.status == AVAssetWriterStatusUnknown ) {
            
            if ([self.assetWriter startWriting]) {
                [self.assetWriter startSessionAtSourceTime:presentationTime];
            } else {
                NSLog(@"Error writing initial buffer");
            }
        }
        
        if ( self.assetWriter.status == AVAssetWriterStatusWriting ) {
            
            if (mediaType == AVMediaTypeVideo) {
                if (_assetWriterVideoInput.readyForMoreMediaData) {
                    
                    NSLog(@"Write MP4 Is Ready\n");

                    if (buffer) {
                        
                        if (![_assetWriterVideoInput appendSampleBuffer:buffer]) {
                            NSLog(@"Error writing video buffer");
                        }
                    }
                }
            }
            else if (mediaType == AVMediaTypeAudio) {
                if (_assetWriterAudioInput.readyForMoreMediaData) {
                    
                    if (![_assetWriterAudioInput appendSampleBuffer:buffer]) {
                        NSLog(@"Error writing audio buffer");
                    }
                }
            }
        }
    }
}

- (void)writeRecordMP4File:(unsigned char*)contentByte len:(int)aLen
{
    NSLog(@"%@",NSStringFromSelector(_cmd));

    NSMutableArray *VideoListArray;
    NSMutableData * sampleData = [[NSMutableData alloc] init];
    
    int count_i=-1;
    int start =0;
    int before =0;
    int last =0;
    
    Byte tmpByte;
    
    for(int i=0;i<aLen;i++){
        
        if((contentByte[i+0] == 0x00 && contentByte[i+1] == 0x00 && contentByte[i+2]== 0x00 && contentByte[i+3] == 0x01 && contentByte[i+4] == 0x41)|| (contentByte[i+0] == 0x00 &&contentByte[i+1] == 0x00 && contentByte[i+2]== 0x00 && contentByte[i+3] == 0x01 && contentByte[i+4] == 0x65)){
            
            before = i;
            count_i++;
            i=i+4;
            
            if (0 == count_i) {
                
                start=i+1;
            }
            else
            {
                last = start;
                start = i+1;
                [VideoListArray addObject:[[NSMutableData alloc] init]];
                
                for (int j =last; j<before; j++) {
                    tmpByte=contentByte[j];
                    [[VideoListArray objectAtIndex:count_i-1] appendBytes:&tmpByte length:sizeof(tmpByte)];
                }
            }
        }
        while(i == aLen-1) {
            [VideoListArray addObject:[[NSMutableData alloc] init]];
            for (int j=start; j<aLen; j++) {
                
                tmpByte=contentByte[j];
                [[VideoListArray objectAtIndex:count_i] appendBytes:&tmpByte length:sizeof(tmpByte)];
            }
            break;
        }
    }
    
    NSLog(@"VideoListArray %@",VideoListArray);
    //读取H264文件
    for (int j=0; j<[VideoListArray count]; j++) {
        
        [sampleData appendData:[VideoListArray objectAtIndex:j]];
        [self addH264NAL:sampleData pts:0];
        [sampleData setLength:0];
    }
}

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
//#define EAD_INPUT_BUFFER_SIZE 128
//#define EAD_INPUT_BUFFER_SIZE (20 * 1024)

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

- (int)readData:(unsigned char**)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs
{
    if (aLen < 0) {
        return -3;
    }
    
    int iOffset = 0;

    @autoreleasepool {
        
        NSDate *iStartTime = [NSDate date];
        
//        NSLog(@"offset: %d readLen: %d", iOffset,aLen);

//        while ((aLen - iOffset) > 0)
        while (1)
        {
            if ([[_session inputStream] hasBytesAvailable])
            {
                NSInteger bytesRead = 0;
                
                if ((aLen - iOffset) >= EAD_INPUT_BUFFER_SIZE)
                {
                    bytesRead = [[_session inputStream] read:*pucBuffer + iOffset maxLength:EAD_INPUT_BUFFER_SIZE];
                }
                else
                {
                    bytesRead = [[_session inputStream] read:*pucBuffer + iOffset maxLength:(aLen - iOffset)];

                }
 
                iOffset += bytesRead;
//                NSLog(@" update offset: %d", iOffset);
                
                if (iOffset == aLen)
                {
                    if (aLen <= 32) {
//                        NSLog(@"bytes read finished\n");

//                        NSLog(@" update offset: %@", [NSData dataWithBytes:pucBuffer length:aLen]);
                    }
                    else
                    {
                        //write mp4 record file
//                        [self writeRecordMP4File:*pucBuffer len:aLen];
                        
//                        NSLog(@"video bytes read finished %d bytes %@\n",aLen,[NSData dataWithBytes:*pucBuffer length:32]);
//                        NSLog(@"video bytes read finished %d\n",aLen);

                    }
                    break;
                }
            }
            else
            {
                sleep(0.3);
            }
            
            int iEndTime = [[NSDate date] timeIntervalSinceDate:iStartTime];
            iEndTime *= 1000;
            
            if (iEndTime > iTimeoutMs)
            {
//                NSLog(@"read data timeout\n");
                iOffset = -2;
                break;
            }
        }
    }
    
    return iOffset;
}

/*
 {
 if (aLen < 0) {
 return -3;
 }
 
 int iOffset = 0;
 
 static int numCount = 0;
 
 @autoreleasepool {
 NSDate *iStartTime = [NSDate date];
 
 //    if (NULL == pucBuffer) {
 //        NSLog(@"pucBuffer alloc \n");
 //
 //        pucBuffer = (unsigned char*)malloc(aLen);
 //        memset(pucBuffer, 0, aLen);
 //    }
 
 //    unsigned char *sourceBuffer = (unsigned char*)malloc(aLen);
 //    memset(sourceBuffer, 0, aLen);
 
 //        unsigned char buf[EAD_INPUT_BUFFER_SIZE];
 //
 //        if (_readAppendData != nil) {
 //            //        [_readAppendData release];
 //            _readAppendData = nil;
 //        }
 
 while (1)
 {
 numCount++;
 
 if ([[_session inputStream] hasBytesAvailable])
 {
 NSLog(@"offset: %d readLen: %d,numCount %d", iOffset,aLen,numCount);
 
 int maxLen = EAD_INPUT_BUFFER_SIZE;
 
 if (aLen < EAD_INPUT_BUFFER_SIZE)
 {
 maxLen = aLen;
 }
 
 NSInteger bytesRead = [[_session inputStream] read:(pucBuffer + iOffset) maxLength:maxLen];
 
 //                if (_readAppendData == nil) {
 //                    _readAppendData = [[NSMutableData alloc] init];
 //                }
 //
 //                [_readAppendData appendBytes:(void *)buf length:bytesRead];
 
 iOffset += bytesRead;
 NSLog(@" update offset: %d", iOffset);
 
 if (iOffset <= aLen)
 {
 //                NSData *data = [NSData dataWithBytes:acInfo length:aLen];
 //                memcpy(pucBuffer, sourceBuffer, aLen);
 //                    pucBuffer = (unsigned char*)[_readAppendData bytes];
 //
 //                    if (aLen < EAD_INPUT_BUFFER_SIZE) {
 //                        pucBuffer = buf;
 //                    }
 
 NSLog(@"bytes read finished\n");
 //                    NSLog(@"bytes length: %d,actual length %lu", aLen,(unsigned long)[_readAppendData length]);
 //                NSLog(@"bytes in hex: %@", [data description]);
 //
 //                NSString *sendString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 //
 //                if (NULL == sendString) {
 //                    sendString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
 //
 //                    if(NULL == sendString)
 //                    {
 //                        NSLog(@"Convert NSData To NSString Fail\n");
 //                    }
 //                }
 //
 //                NSLog(@"data received %@",sendString);
 
 break;
 }
 }
 else
 {
 sleep(0.3);
 //                pucBuffer = (unsigned char*)[_readAppendData bytes];
 //
 //                if (aLen < EAD_INPUT_BUFFER_SIZE) {
 //                    pucBuffer = buf;
 //                }
 //                break;
 }
 
 int iEndTime = [[NSDate date] timeIntervalSinceDate:iStartTime];
 iEndTime *= 1000;
 
 if (iEndTime > iTimeoutMs)
 {
 NSLog(@"read data timeout\n");
 iOffset = -2;
 break;
 }
 }
 
 NSLog(@"numCount %d\n",numCount);
 
 }
 
 return iOffset;
 }
 */

- (int)writeData:(unsigned char*)pucBuffer Length:(int)aLen timeout:(int)iTimeoutMs
{
    int iOffset = 0;
    NSDate *iStartTime = [NSDate date];
    
    while (1)
    {
        if (([[_session outputStream] hasSpaceAvailable]) && (iOffset < aLen))
        {
            NSInteger bytesWritten = [[_session outputStream] write:(pucBuffer + iOffset) maxLength:aLen];
            
            NSLog(@"bytesWritten %ld iOffset %d",(long)bytesWritten,iOffset);

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
        else if (iOffset == aLen)
        {
            NSLog(@"iOffset >= aLen %d iOffset %d",aLen,iOffset);

            break;
        }
        else
        {
            sleep(0.3);
        }
        
        int iEndTime = [[NSDate date] timeIntervalSinceDate:iStartTime];
        iEndTime *= 1000;
        if (iEndTime > iTimeoutMs)
        {
            NSLog(@"iTimeoutMs %d iOffset %d",iEndTime,iOffset);

            iOffset = -2;
            break;
        }
    }
    
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
        [self configAssetWriter];
        
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

- (void)writeMp4:(int)dataType data:(unsigned char*)data len:(int)length pts:(int)pts
{
    if(NULL == _mp4Data)
    {
        _mp4Data = [[NSMutableData alloc] initWithCapacity:0];
    }
    
    //video:10,11 audio:20
    if (10 == dataType || 11 == dataType) {
//        NSLog(@"video bytes %@\n",[NSData dataWithBytes:data length:8]);

//        [self writeRecordMP4File:data len:length];
//        NSData *sampleData = [NSData dataWithBytes:data length:length];
//        [self addH264NAL:sampleData pts:pts];
        
        int minusValue = 0;
        if ((data[10] & 0x1f) == 0x07) {
            minusValue = 6;
        }
        else
        {
            minusValue = 24;
        }
        
//        uint32_t nalSize = (uint32_t)(length - minusValue);
//        uint8_t *pNalSize = (uint8_t*)(&nalSize);
//        data[minusValue] = *(pNalSize + 3);
//        data[minusValue + 1] = *(pNalSize + 2);
//        data[minusValue + 2] = *(pNalSize + 1);
//        data[minusValue + 3] = *(pNalSize);
        
        [_mp4Data appendBytes:data + minusValue length:(length - minusValue)];

    }
    else if (20 == dataType)
    {
        //do nothing
    }
}

- (void)startWriteMP4
{
    if ( NULL == _mp4Data || 0 == [_mp4Data length]) {
        NSLog(@"date is null,not write mp4\n");

        return;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH-mm-ss"]; //每次启动后都保存一个新的日志文件中
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSString * storePath = [[paths objectAtIndex:0] stringByAppendingFormat:@"/%@.h264",dateStr];
    
    if (_mp4Data != nil && [_mp4Data length] > 0) {
        BOOL success = [_mp4Data writeToFile:storePath atomically:YES];
        if (noErr != success) {
            NSLog(@"write mp4 file fail\n");
        }
        
        self.mp4Data = nil;
    }
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
//            [self _readData];
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"NSStreamEventHasSpaceAvailable");
//            [self _writeData];
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
