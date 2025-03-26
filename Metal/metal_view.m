// Thanks to @slime73!
// https://gist.github.com/slime73/12284a8299be857d2581

#include "metal_view.h"

@implementation FenetresMetalView

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

// Indicate the view wants to draw using a backing layer instead of drawRect.
- (BOOL)wantsUpdateLayer
{
    return YES;
}

// When the wantsLayer property is set to YES, this method will be invoked to
// return a layer instance.
- (CALayer *)makeBackingLayer
{
    return [self.class.layerClass layer];
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.wantsLayer = YES; // Automatically calls makeBackingLayer
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.layer.opaque = YES;

        [self updateDrawableSize];
    }

    return self;
}

- (void)updateDrawableSize
{
    NSSize size  = self.bounds.size;
    NSSize backing_size = [self convertSizeToBacking:size];

    CAMetalLayer *layer = (CAMetalLayer *)self.layer;
    layer.contentsScale = backing_size.height / size.height;
    layer.drawableSize = NSSizeToCGSize(backing_size);
}

@end