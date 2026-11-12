// LiquidSiri remake for iOS 12 (v0.1): a glass "lens" bubble while Siri is on screen.
// The magnifying effect is a scaled snapshot of the screen inside a circle (no live refraction, so it is cheap).
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// ---------------------------------------------------------------- lens artwork
static UIImage *lensOverlay(CGFloat d) {
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = NO;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(d, d) format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *rc) {
        CGContextRef c = rc.CGContext;
        CGRect rect = CGRectMake(0, 0, d, d);
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:rect];

        CGContextSaveGState(c);
        [circle addClip];

        // Black cap over the top part of the bubble.
        CGFloat cap[12] = {0, 0, 0, 0.96,  0, 0, 0, 0.96,  0, 0, 0, 0.0};
        CGFloat capLoc[3] = {0.0, 0.30, 0.52};
        CGGradientRef g1 = CGGradientCreateWithColorComponents(cs, cap, capLoc, 3);
        CGContextDrawLinearGradient(c, g1, CGPointMake(0, 0), CGPointMake(0, d), 0);
        CGGradientRelease(g1);

        // Bright band where the black cap meets the glass.
        CGFloat band[12] = {1, 1, 1, 0.0,  1, 1, 1, 0.50,  1, 1, 1, 0.0};
        CGFloat bandLoc[3] = {0.34, 0.44, 0.56};
        CGGradientRef g2 = CGGradientCreateWithColorComponents(cs, band, bandLoc, 3);
        CGContextDrawLinearGradient(c, g2, CGPointMake(0, 0), CGPointMake(0, d), 0);
        CGGradientRelease(g2);

        // Glow along the bottom edge.
        CGFloat glow[8] = {1, 1, 1, 0.38, 1, 1, 1, 0.0};
        CGGradientRef g3 = CGGradientCreateWithColorComponents(cs, glow, NULL, 2);
        CGPoint gc = CGPointMake(d / 2, d * 1.02);
        CGContextDrawRadialGradient(c, g3, gc, 0, gc, d * 0.55, 0);
        CGGradientRelease(g3);
        CGContextRestoreGState(c);

        // Thin dark outer line.
        UIBezierPath *hair = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 0.25, 0.25)];
        hair.lineWidth = 0.5;
        [[UIColor colorWithWhite:0 alpha:0.3] setStroke];
        [hair stroke];

        // Bright rim, strongest at the bottom.
        CGContextSaveGState(c);
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 0.5, 0.5)];
        [ring appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 2.6, 2.6)]];
        ring.usesEvenOddFillRule = YES;
        [ring addClip];
        CGFloat rim[12] = {1, 1, 1, 0.30,  1, 1, 1, 0.10,  1, 1, 1, 0.95};
        CGFloat rimLoc[3] = {0.0, 0.5, 1.0};
        CGGradientRef g4 = CGGradientCreateWithColorComponents(cs, rim, rimLoc, 3);
        CGContextDrawLinearGradient(c, g4, CGPointMake(0, 0), CGPointMake(0, d), 0);
        CGGradientRelease(g4);
        CGContextRestoreGState(c);

        CGColorSpaceRelease(cs);
    }];
}

// ---------------------------------------------------------------- the lens view
@interface LGLensView : UIView
- (instancetype)initWithDiameter:(CGFloat)d snapshot:(UIView *)snap
                          center:(CGPoint)c screen:(CGSize)screen magnify:(CGFloat)s;
@end

@implementation LGLensView
- (instancetype)initWithDiameter:(CGFloat)d snapshot:(UIView *)snap
                          center:(CGPoint)c screen:(CGSize)screen magnify:(CGFloat)s {
    self = [super initWithFrame:CGRectMake(0, 0, d, d)];
    if (!self) return nil;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.35;
    self.layer.shadowRadius = 14;
    self.layer.shadowOffset = CGSizeMake(0, 8);
    self.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;

    UIView *clip = [[UIView alloc] initWithFrame:self.bounds];
    clip.layer.cornerRadius = d / 2.0;
    clip.clipsToBounds = YES;
    clip.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    [self addSubview:clip];

    if (snap) {
        // Scale the screen snapshot about the lens center so what is behind the lens looks magnified.
        snap.bounds = CGRectMake(0, 0, screen.width, screen.height);
        snap.layer.anchorPoint = CGPointMake(c.x / screen.width, c.y / screen.height);
        snap.layer.position = CGPointMake(d / 2.0, d / 2.0);
        snap.transform = CGAffineTransformMakeScale(s, s);
        [clip addSubview:snap];
    }

    UIView *tint = [[UIView alloc] initWithFrame:self.bounds];
    tint.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    [clip addSubview:tint];

    UIImageView *art = [[UIImageView alloc] initWithImage:lensOverlay(d)];
    art.frame = self.bounds;
    [clip addSubview:art];
    return self;
}
@end

// A window that never takes touches.
@interface LGPassWindow : UIWindow @end
@implementation LGPassWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
@end

// ---------------------------------------------------------------- show / hide
static LGPassWindow *gWin;
static LGLensView *gLens;
static NSTimer *gWatch;
static __weak UIWindow *gAssistantWin;

static void hideLens(void) {
    [gWatch invalidate];
    gWatch = nil;
    LGPassWindow *w = gWin;
    LGLensView *l = gLens;
    gWin = nil;
    gLens = nil;
    if (!w) return;
    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        l.transform = CGAffineTransformMakeScale(0.2, 0.2);
        l.alpha = 0;
    } completion:^(BOOL finished) {
        w.hidden = YES;
    }];
}

static void showLens(void) {
    if (gWin) return;
    CGRect scr = [UIScreen mainScreen].bounds;
    UIView *snap = [[UIScreen mainScreen] snapshotViewAfterScreenUpdates:YES];  // our lens is not on screen yet

    gWin = [[LGPassWindow alloc] initWithFrame:scr];
    gWin.windowLevel = UIWindowLevelAlert + 100;
    gWin.backgroundColor = [UIColor clearColor];
    gWin.rootViewController = [[UIViewController alloc] init];
    gWin.rootViewController.view.backgroundColor = [UIColor clearColor];

    CGFloat d = 128.0;
    CGPoint c = CGPointMake(scr.size.width / 2.0, 76.0);
    gLens = [[LGLensView alloc] initWithDiameter:d snapshot:snap center:c screen:scr.size magnify:1.5];
    gLens.center = CGPointMake(c.x, -d / 2.0);          // starts above the screen
    gLens.transform = CGAffineTransformMakeScale(0.3, 0.3);
    gLens.alpha = 0;
    [gWin.rootViewController.view addSubview:gLens];
    gWin.hidden = NO;

    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.6
                        options:0 animations:^{
        gLens.center = c;
        gLens.transform = CGAffineTransformIdentity;
        gLens.alpha = 1;
    } completion:nil];

    // Safety net: remove the bubble if the Siri window goes away without telling us.
    [gWatch invalidate];
    gWatch = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        UIWindow *a = gAssistantWin;
        if (!a || a.hidden) hideLens();
    }];
}

static NSInteger gToken = 0;

static void scheduleLens(void) {
    NSInteger t = ++gToken;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *a = gAssistantWin;
        if (t == gToken && a && !a.hidden) showLens();
    });
}

static BOOL isAssistantWindow(UIWindow *w) {
    NSString *n = NSStringFromClass([w class]);
    return [n containsString:@"Assistant"] || [n containsString:@"Siri"];
}

%hook UIWindow
- (void)setHidden:(BOOL)h {
    %orig;
    if (!isAssistantWindow(self)) return;
    if (!h) {
        gAssistantWin = self;
        scheduleLens();
    } else {
        gToken++;
        hideLens();
    }
}
- (void)makeKeyAndVisible {
    %orig;
    if (isAssistantWindow(self)) {
        gAssistantWin = self;
        scheduleLens();
    }
}
%end
