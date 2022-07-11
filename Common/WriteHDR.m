/*

 WriteHDR.h
 VerticalCross2EquiRect
 
 Modification of code from Apple's PostProcessingPipeline project.
 */

#import "AAPLMathUtilities.h"

#import <AppKit/AppKit.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#import "stb_image_write.h"

#import <simd/simd.h>




// -- Writes a 2D Metal Texture

BOOL writeMetalTextureToURL(id<MTLTexture> __nonnull mtlTexture,
                            NSURL * __nonnull fileURL,
                            NSError * __nullable * __nullable error) {
    // --------------
    // Validate output path
    if (![fileURL.absoluteString containsString:@"."]) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"No file extension provided."}];
        }
        return NO;
    }

    NSArray * subStrings = [fileURL.absoluteString componentsSeparatedByString:@"."];

    if ([subStrings[1] compare:@"hdr"] != NSOrderedSame) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Only (.hdr) files are supported."}];
        }
        return NO;
    }

    const char *filePath = [fileURL fileSystemRepresentation];

    // NSLog(@"%s", filePath);

    // Check validity of MTLTexture object
    if (mtlTexture.pixelFormat != MTLPixelFormatRGBA16Float) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Wrong pixel format: can't save this file"}];
        }
        return NO;
    }

    // Create an instance of Core Image
    CIImage* ciImage = [CIImage imageWithMTLTexture:mtlTexture
                                            options:nil];

    // We need to flip the image vertically
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0,
                                                                   ciImage.extent.size.height);
    transform = CGAffineTransformScale(transform, 1.0, -1.0);
    ciImage = [ciImage imageByApplyingTransform:transform];

    // Create an instance of CGImage from the CIImage object
    CIContext* ciContext = [CIContext contextWithMTLDevice:mtlTexture.device];
    //NSLog(@"%@", ciContext);
    CGImageRef cgImage = [ciContext createCGImage:ciImage
                                         fromRect:ciImage.extent
                                           format:kCIFormatRGBAh
                                       colorSpace:nil];
    //NSLog(@"%@", cgImage);

    // We need a pointer to its bitmap data.
    NSBitmapImageRep* bir = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];

    // bitmapFormat should be 4 indicating FP format.
    //NSLog(@"%lu", (unsigned long)bir.bitmapFormat);
    uint16 *srcData = (uint16 *)bir.bitmapData;
    size_t width = bir.pixelsWide;
    size_t height = bir.pixelsHigh;
    //NSLog(@"image width:%lu image height:%lu", width, height);
    // It seems the raw data of the CGImage object is made up of pixels,
    //  which have 4 components, each component being 16 bits giving
    //  a total size of 64 bits per pixel.
    //NSLog(@"%lu %lu %lu", bir.samplesPerPixel, bir.bitsPerSample, bir.bitsPerPixel);

    if (srcData == NULL) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Unable to access image's data."}];
        }
        return NO;
    }

    // Pixel format of the source data is RGBAh (16-bit float/half float)
    const size_t kSrcChannelCount = 4;
    const size_t kBitsPerByte = 8;
    const size_t kExpectedBitsPerPixel = sizeof(uint16_t) * kSrcChannelCount * kBitsPerByte;

    const size_t kPixelCount = width * height;
    const size_t kDstChannelCount = 3;
    const size_t kDstSize = kPixelCount * sizeof(float) * kDstChannelCount;

    float* dstData = (float *)malloc(kDstSize);

    for (size_t pixelIdx = 0; pixelIdx < kPixelCount; ++pixelIdx) {
        const uint16_t * currSrc = srcData + (pixelIdx * kSrcChannelCount);
        float* currDst = dstData + (pixelIdx * kDstChannelCount);

        currDst[0] = float32_from_float16(currSrc[0]);
        currDst[1] = float32_from_float16(currSrc[1]);
        currDst[2] = float32_from_float16(currSrc[2]);
    }

    // Call the external header library
    int err = stbi_write_hdr(filePath,
                             (int)width, (int)height,
                             3,
                             dstData);
    // Remember to clean things up
    free(dstData);
    CGImageRelease(cgImage);            // Don't forget release it.

    if (err == 0) {
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:@"File write failure."
                                                code:0xdeadbeef
                                            userInfo:@{NSLocalizedDescriptionKey : @"Unable to write hdr file."}];
        }
        return NO;
    }
    return YES;
}

