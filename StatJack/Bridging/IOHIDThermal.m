#import "IOHIDThermal.h"
#import <CoreFoundation/CoreFoundation.h>

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient    *IOHIDServiceClientRef;
typedef struct __IOHIDEvent            *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef matching);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service,
                                                 int64_t type,
                                                 int32_t options,
                                                 uint64_t fields);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kHIDPage_AppleVendor       0xff00
#define kHIDUsage_Temperature      0x0005
#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventFieldTemperatureLevel ((kIOHIDEventTypeTemperature) << 16)

NSArray<NSNumber *> *StatJackReadTemperatureSensors(void) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) {
        return @[];
    }

    NSDictionary *matching = @{
        @"PrimaryUsagePage": @(kHIDPage_AppleVendor),
        @"PrimaryUsage":     @(kHIDUsage_Temperature)
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)matching);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) {
        CFRelease(client);
        return @[];
    }

    NSMutableArray<NSNumber *> *temps = [NSMutableArray array];
    NSArray *bridged = (__bridge NSArray *)services;
    for (id obj in bridged) {
        IOHIDServiceClientRef service = (__bridge IOHIDServiceClientRef)obj;
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (event) {
            double celsius = IOHIDEventGetFloatValue(event, (int32_t)kIOHIDEventFieldTemperatureLevel);
            if (celsius > 0 && celsius < 200) {
                [temps addObject:@(celsius)];
            }
            CFRelease(event);
        }
    }

    CFRelease(services);
    CFRelease(client);
    return [temps copy];
}
