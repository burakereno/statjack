#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Reads CPU/SoC temperature sensors via the private IOHIDEventSystemClient
/// API. Works on Apple Silicon (M1/M2/M3). Returns an array of °C values
/// from every matching sensor — caller can average / max / pick.
NSArray<NSNumber *> *StatJackReadTemperatureSensors(void);

NS_ASSUME_NONNULL_END
