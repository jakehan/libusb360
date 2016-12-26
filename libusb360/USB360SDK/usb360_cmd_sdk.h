#ifndef USB360_CMD_SDK_H
#define USB360_CMD_SDK_H

extern int usb360_cmdsdk_sendStreamStart(void *pvUsb);
extern int usb360_cmdsdk_sendStreamStop(void *pvUsb);
extern int usb360_cmdsdk_sendGetDeviceInfo(void *pvUsb, char *pcName, char *pcSn, char *pcFW);
extern int usb360_cmdsdk_sendStreamStop(void *pvUsb);
extern int usb360_cmdsdk_sendGetStreamInfo(void *pvUsb, char *pcInfo);
extern int usb360_cmdsdk_sendUpdate(void *pvUsb, char *pcFileName);

// 如果pctime=null，则sdk自己获取时间
extern int usb360_cmdsdk_sendSetTime(void *pvUsb, char *pcTime); // 2016-11-16 13:00:00

extern int usb360_cmdsdk_sendSetIQ(void *pvUsb, int iISO, int iAWB, int iEV, int iST);
extern int usb360_cmdsdk_sendGetIQ(void *pvUsb, char *pcInfo);

#endif // USB360_CMD_SDK_H
