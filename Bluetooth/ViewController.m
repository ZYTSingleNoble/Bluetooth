//
//  ViewController.m
//  Bluetooth
//
//  Created by zhangyt on 16-1-4.
//  Copyright (c) 2016年 LZT. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

//必须要由UUID来唯一标示对应的service和characteristic

#define kServiceUUID @"5C476471-1109-4EBE-A826-45B4F9D74FB9"

#define kCharacteristicHeartRateUUID @"82C7AC0F-6113-4EC9-92D1-5EEF44571398"

#define kCharacteristicBodyLocationUUID @"537B5FD6-1889-4041-9C35-F6949D1CA034"

@interface ViewController ()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *manager;

@property (nonatomic, strong) NSMutableData *data;

@property (nonatomic,strong) CBPeripheral *peripheral;

@property (nonatomic,strong) CBCharacteristic *characteristic;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化蓝牙 central manager
    
    _manager = [[CBCentralManager alloc]initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) options:nil];
    [_manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerRestoredStateScanOptionsKey:@(YES)}];
  
}

//当Central Manager被初始化，我们要检查它的状态，以检查运行这个App的设备是不是支持BLE。实现以下的代理方法
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state) {
            
        case CBCentralManagerStatePoweredOn:
            
            // Scans for any peripheral
            //方法是用于告诉Central Manager，要开始寻找一个指定的服务了。如果你将第一个参数设置为nil，Central Manager就会开始寻找所有的服务。
            [self.manager scanForPeripheralsWithServices:nil
                                                 options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
            break;
        default:
            NSLog(@"Central Manager did change state");
            break;
    }
}

//这个调用通知Central Manager代理（在这个例子中就是view controller），一个附带着广播数据和信号质量(RSSI-Received Signal Strength Indicator)的周边被发现。这是一个很酷的参数，知道了信号质量，你可以用它去判断远近。任何广播、扫描的响应数据保存在advertisementData 中，可以通过CBAdvertisementData 来访问它。现在，你可以停止扫描，而去连接周边了
- (void)    centralManager:(CBCentralManager *)central
     didDiscoverPeripheral:(CBPeripheral *)peripheral
         advertisementData:(NSDictionary *)advertisementData
                      RSSI:(NSNumber *)RSSI {
    // Stops scanning for peripheral
//    [self.manager stopScan];
    NSMutableArray * allP = [NSMutableArray array];
    if (self.peripheral != peripheral) {
        [allP addObject:peripheral];
        for (CBService *service in peripheral.services) {
            
        }
//        peripheral.services
        self.peripheral = peripheral;
        NSLog(@"Connecting to peripheral %@", peripheral);
        // Connects to the discovered peripheral
        //链接到设备
        [self.manager connectPeripheral:peripheral options:nil];
    }
}

//基于连接的结果，代理（这个例子中是view controller）会接收centralManager:didFailToConnectPeripheral:error:或者centralManager:didConnectPeripheral:。如果成功了，你可以问广播服务的那个周边。
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // Clears the data that we may already have
    [self.data setLength:0];
    
    // Sets the peripheral delegate
    [self.peripheral setDelegate:self];
    
    // Asks the peripheral to discover the service
    //开始扫描服务，从包含指定服务中
    [self.peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
    
}
//链接失败调用
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
}

//周边开始用一个回调通知它的代理。在上一个方法中，我请求周边去寻找服务，周边代理接收-peripheral:didDiscoverServices:。如果没有Error，可以请求周边去寻找它的服务所列出的特征，像以下这么做
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering service:%@", [error localizedDescription]);
//        [self cleanup];
        return;
    }
    for (CBService *service in aPeripheral.services) {
        NSLog(@"Service found with UUID: %@",service.UUID);
        // Discovers the characteristics for a given service
        //发现指定服务，开始扫描特征
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            [self.peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kCharacteristicBodyLocationUUID]] forService:service];
        }
    }
}

//如果一个特征被发现，周边代理会接收-peripheral:didDiscoverCharacteristicsForService:error:。现在，一旦特征的值被更新，用-setNotifyValue:forCharacteristic:，周边被请求通知它的代理。
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering characteristic:%@", [error localizedDescription]);
//        [self cleanup];
        return;
    }
    if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicBodyLocationUUID]]) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                self.characteristic = characteristic;
                
                self.data = [characteristic.value mutableCopy];
            }
        }
    }
}

//如果一个特征的值被更新，然后周边代理接收-peripheral:didUpdateNotificationStateForCharacteristic:error:。你可以用-readValueForCharacteristic:读取新的值
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state:%@", error.localizedDescription);
    }
    // Exits if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicBodyLocationUUID]]) {
        return;
    }
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
        [peripheral readValueForCharacteristic:characteristic];
    } else {
        // Notification has stopped
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@. Disconnecting", characteristic);
        [self.manager cancelPeripheralConnection:self.peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
//        self.error_b = BluetoothError_System;
//        [self error];
        return;
    }
   //    NSLog(@"收到的数据：%@",characteristic.value);
//    [self decodeData:characteristic.value];
}

- (void)writeData:(NSData*)data {
//    NSData *d2 = [[PBABluetoothDecode sharedManager] HexStringToNSData:@"0x02"];
    NSData *d2 = [[NSString string] dataUsingEncoding:NSUTF8StringEncoding];
    if (!self.peripheral) {
        [self.peripheral writeValue:data forCharacteristic:_characteristic type:CBCharacteristicWriteWithoutResponse];
    }
}


@end
