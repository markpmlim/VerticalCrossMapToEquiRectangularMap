/*
 MetalRenderer.m
 VertCross2EquiRect

 Created by Mark Lim Pak Mun on 12/07/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

*/

@import simd;
@import ModelIO;
@import MetalKit;
#import <TargetConditionals.h>

#import "MetalRenderer.h"
#import "AAPLMathUtilities.h"
#import "MTKTextureLoader+HDR.h"

typedef NS_OPTIONS(NSUInteger, ImageSize) {
    QtrK    = 256,
    HalfK   = 512,
    OneK    = 1024,
    TwoK    = 2048,
    ThreeK  = 3072,
    FourK   = 4096,
};

/// Main class that performs the rendering.
@implementation MetalRenderer {
    id<MTLDevice> _device;
    MTKView* _mtkView;

    id<MTLCommandQueue> _commandQueue;

    id<MTLRenderPipelineState> _renderPipelineState;
    id<MTLRenderPipelineState> _renderToTexturePipelineState;
    MTLRenderPassDescriptor* _renderPassDescriptor;

    MTLRenderPassDescriptor* _offScreenRenderPassDescriptor;

    id<MTLTexture> _verticalCrossTexture;
    id<MTLTexture> _renderTargetTexture;
    CGSize _renderTargetSize;
    MTLPixelFormat _renderTargetPixelFormat;
    id<MTLDepthStencilState> _depthState;
}

/// Initialize the renderer with the MetalKit view that references the Metal device you render with.
/// You also use the MetalKit view to set the pixel format and other properties of the drawable.
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        _mtkView = mtkView;
       _commandQueue = [_device newCommandQueue];

        _mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        // Configure a combined depth and stencil descriptor that enables the creation
        // of an immutable depth and stencil state object.
        MTLDepthStencilDescriptor *depthStencilDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthState = [_device newDepthStencilStateWithDescriptor:depthStencilDesc];

        NSString* name = @"VerticalCross.hdr";
        //NSString* name = @"stpeters_cross.hdr";
        //NSString* name = @"uffizi_cross.hdr";
        _verticalCrossTexture = [self loadTextureWithContentsOfFile:name
                                                              isHDR:YES];
        // Set the render target's pixel format and size here
        // We are rendering an equirectangular texture.
        _renderTargetSize = CGSizeMake(TwoK, OneK);
        _renderTargetPixelFormat = _verticalCrossTexture.pixelFormat;
 
        [self buildPipelineStates];
        [self renderToTexture:_renderTargetTexture
           usingSourceTexture:_verticalCrossTexture
                         size:_renderTargetSize];
        
    }

    return self;
}

-(id<MTLTexture>) loadTextureWithContentsOfFile:(NSString *)name
                                          isHDR:(BOOL)isHDR {
    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    id<MTLTexture> mtlTexture;
    if (isHDR == YES) {
        NSError *error = nil;
         mtlTexture = [textureLoader newTextureFromRadianceFile:name
                                                          error:&error];
        if (error != nil) {
            NSLog(@"Can't load hdr file:%@", error);
            exit(1);
        }
    }
    else {
        
    }
    return mtlTexture;
}

- (void) buildPipelineStates {
    id<MTLLibrary> library = [_device newDefaultLibrary];
    // Load the vertex function from the library
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertexShader"];

    // Load the fragment function from the library
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragmentShader"];

    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = @"Drawable Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = _mtkView.depthStencilPixelFormat;
    // The attributes of the vertices are generated on the fly.
    pipelineDescriptor.vertexDescriptor = nil;

    NSError *error = nil;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                             error:&error];
    if (!_renderPipelineState) {
        NSLog(@"Failed to create create render pipeline state, error %@", error);
    }

    // Set up a texture for rendering to and sampling from
    MTLTextureDescriptor *texDescriptor = [MTLTextureDescriptor new];
    texDescriptor.textureType = MTLTextureType2D;
    texDescriptor.width = _renderTargetSize.width;
    texDescriptor.height = _renderTargetSize.height;
    // Ensure the pixel format of the resulting texture is the same as its source.
    texDescriptor.pixelFormat = _renderTargetPixelFormat;
    texDescriptor.usage =   MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    
    _renderTargetTexture = [_device newTextureWithDescriptor:texDescriptor];
    
    pipelineDescriptor.label = @"Offscreen Render Pipeline";
    pipelineDescriptor.sampleCount = 1;
    pipelineDescriptor.vertexFunction =  [library newFunctionWithName:@"vertexShader"];
    pipelineDescriptor.fragmentFunction =  [library newFunctionWithName:@"vertCross2ERPShader"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = _renderTargetPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    pipelineDescriptor.vertexDescriptor = nil;
    _renderToTexturePipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                            error:&error];

    // If we are going to save a generated texture, then an offscreen render is necessary.
    _offScreenRenderPassDescriptor = [MTLRenderPassDescriptor new];
    //_offScreenRenderPassDescriptor.colorAttachments[0].texture = _renderTargetTexture;
    _offScreenRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _offScreenRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    _offScreenRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

}

- (void) renderToTexture:(id<MTLTexture>)destTexture
      usingSourceTexture:(id<MTLTexture>)srcTexture
                    size:(CGSize)size {

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    _offScreenRenderPassDescriptor.colorAttachments[0].texture = destTexture;

    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {

        MTLCommandBufferStatus status = buffer.status;
        if (status == MTLCommandBufferStatusError) {
            NSError *error = buffer.error;
            NSLog(@"Command Buffer Error %@", error);
            return;
        }
        if (status == MTLCommandBufferStatusCompleted) {
            NSLog(@"Rendering to the texture was successfully completed");
            // We can do something within this block of code.
        #if (TARGET_OS_IOS || TARGET_OS_TV)
            CFTimeInterval executionDuration = buffer.GPUEndTime - buffer.GPUStartTime;
            NSLog(@"Execution Time to render: %f s", executionDuration);
        #endif
        }
    }];

    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:_offScreenRenderPassDescriptor];

    renderEncoder.label = @"Offscreen Render Pass";
    [renderEncoder setRenderPipelineState:_renderToTexturePipelineState];
    // These 2 statements are important
    MTLViewport viewPort = {0, 0,
                            size.width, size.height,
                            0, 1};
    [renderEncoder setViewport:viewPort];
    [renderEncoder setFragmentTexture:srcTexture
                              atIndex:0];

    // The attributes of the vertices are generated on the fly.
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:3];
    [renderEncoder endEncoding];
    [commandBuffer commit];

    // Calling waitUntilCompleted blocks the CPU thread until the
    //  render-into-a-texture operation is complete on the GPU.
    //[commandBuffer waitUntilCompleted];
}

- (void) mtkView:(nonnull MTKView *)view
drawableSizeWillChange:(CGSize)size {

    float aspect = size.width / (float)size.height;
}



/// Called whenever the view needs to render.
- (void) drawInMTKView:(nonnull MTKView *)view {

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Command Buffer";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if (view.currentDrawable != nil) {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder setRenderPipelineState:_renderPipelineState];
        [renderEncoder setFragmentTexture:_renderTargetTexture
                                  atIndex:0];

        // The attributes of the vertices are generated on the fly.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:3];

        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

@end
