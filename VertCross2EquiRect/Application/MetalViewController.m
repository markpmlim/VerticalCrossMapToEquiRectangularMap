/*
 MetalViewController.m
 VertCross2EquiRect
 
 Created by Mark Lim Pak Mun on 12/07/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

#import "MetalViewController.h"
#import "MetalRenderer.h"
#import "WriteHDR.h"

@implementation MetalViewController {
    MTKView *_view;

    MetalRenderer *_renderer;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view to use the default device.
    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();

    if (!_view.device) {
        assert(!"Metal is not supported on this device.");
        return;
    }
    _view.colorPixelFormat = MTLPixelFormatRGBA16Float;

    _renderer = [[MetalRenderer alloc] initWithMetalKitView:_view];

    if (!_renderer) {
        assert(!"Renderer failed initialization.");
        return;
    }

    // Initialize renderer with the view size.
    [_renderer mtkView:_view
drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
}

#if !(TARGET_OS_IOS || TARGET_OS_TV)
-(void) viewDidAppear {
    [_view.window makeFirstResponder:self];
}


-(void) keyDown:(NSEvent*) event {
    if( [[event characters] length] ) {
        unichar nKey = [[event characters] characterAtIndex:0];
        if (nKey == 115 || nKey == 83) {
            id<MTLTexture> mtlTexture = _renderer.renderTargetTexture;
            if (mtlTexture != nil) {
                NSSavePanel *sp = [NSSavePanel savePanel];
                sp.canCreateDirectories = YES;
                sp.nameFieldStringValue = @"image";
                NSModalResponse buttonID = [sp runModal];
                if (buttonID == NSModalResponseOK) {
                    NSString* fileName = sp.nameFieldStringValue;
                    if (![fileName containsString:@"."]) {
                        fileName = [fileName stringByAppendingPathExtension:@"hdr"];
                    }
                    NSURL* folderURL = sp.directoryURL;
                    NSURL* fileURL = [folderURL URLByAppendingPathComponent:fileName];
                    NSError *err = nil;
                    // Just a plain C function
                    BOOL ok = writeMetalTextureToURL(mtlTexture, fileURL, &err);
                    if (!ok) {
                        NSLog(@"%@", err);
                    }
                }
            }
        }
        else {
            [super keyDown:event];
        }
    }
}

#else
// KIV: iOS
#endif
@end
