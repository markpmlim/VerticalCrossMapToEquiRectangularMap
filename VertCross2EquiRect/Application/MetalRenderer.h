/*
 MetalRenderer.h
 VertCross2EquiRect
 
 Created by Mark Lim Pak Mun on 12/07/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

#import <MetalKit/MetalKit.h>

/// Platform-independent renderer class.
@interface MetalRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;

@property (readonly) id<MTLTexture> _Nonnull renderTargetTexture;
@end
