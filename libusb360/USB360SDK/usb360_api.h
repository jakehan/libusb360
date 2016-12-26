#ifndef USB360_API_H
#define USB360_API_H

#define MAX_SEND_ENDPOINT     2
#define MAX_RECEIVE_ENDPOINT  2

#define USB360_VERSION "0.0.2 build 2016.11.11 10:53"
extern void *usb360_api_new(void);
extern int usb360_api_addReceiveEndPoint(void *pvusb, void* point, int (*receive)(void *pOint, unsigned char **pucBuffer, int iLen, int iTimeOut) );
extern int usb360_api_addSendEndPoint   (void *pvusb, void* point, int (*send)   (void *pOint, unsigned char  *pucBuffer, int iLen, int iTimeOut));
extern int usb360_api_setStreamCallBack(void *pvusb, 
                                        int (*streamCallBack)(void *par, int iCh, unsigned char *pucData, int iDataLen, unsigned int uiPtsMs),
                                        void *streamCallBackPar);

extern int usb360_api_sendCmd           (void *pvusb, int iCmd, unsigned char *pucCmd, int iCmdLen, 
                                         int (*processAnswer)(void *pvpar, int iErrCode, char *pvAnswerPayLoad, int iPayLoadLen), 
                                        void *processAnswerPar);


extern int usb360_api_sendSessionData  (void *pvusb, int iSessionId, unsigned char *pucData, int iDataLen);

extern int usb360_api_complete(void *pvusb);

extern int usb360_api_destroy(void *pvusb);

#endif // USB360_API_H
