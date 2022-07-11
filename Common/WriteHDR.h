/*
 WriteHDR.h
 EquiRect2Crossmaps

 */


#import <simd/simd.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

/// Enable writing of ".hdr" files.
BOOL writeMetalTextureToURL(id<MTLTexture> __nonnull mtlTexture,
                            NSURL * __nonnull fileURL,
                            NSError * __nullable * __nullable error);
