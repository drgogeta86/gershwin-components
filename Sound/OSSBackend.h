/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * OSS Backend (Stub for FreeBSD support)
 *
 * This is a placeholder for future FreeBSD OSS (Open Sound System) support.
 * OSS uses /dev/mixer and /dev/dsp for audio control.
 */

#import "SoundBackend.h"

@interface OSSBackend : NSObject <SoundBackend>
{
    id<SoundBackendDelegate> delegate;
    
    // Cached data
    NSMutableArray *cachedOutputDevices;
    NSMutableArray *cachedInputDevices;
    AudioDevice *defaultOutput;
    AudioDevice *defaultInput;
    
    // Alert sounds
    NSMutableArray *cachedAlertSounds;
    AlertSound *currentAlert;
    float cachedAlertVolume;
    
    // Settings
    BOOL playUIEffects;
    BOOL playVolumeChangeFeedback;
    
    // Mixer device
    int mixerFd;
    NSString *mixerDevice;
}

@property (assign) id<SoundBackendDelegate> delegate;

@end
