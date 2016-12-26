#ifndef USB360_ERRCODE_H
#define USB360_ERRCODE_H


#define USB360_ERRCODE_OK                          0

#define USB360_ERRCODE_PROTOCOL_VERSION            -8000     // 不兼容的协议版本号
#define USB360_ERRCODE_SEND                        -8001     // send Err
#define USB360_ERRCODE_RECEIVE_TIMEOUT             -8002     // 接收超时 Err
#define USB360_ERRCODE_CMD_SEQ                     -8003     // 应答序号不匹配
#define USB360_APIERR_NULL                         -8004     // 指针为空
#define USB360_APIERR_INVALIDPAR                   -8005     // 参数超出合法范围
#define USB360_APIERR_CALL                         -8006     // 调用不对，如顺序或重复调用


#endif // USB360_ERRCODE_H
