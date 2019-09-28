#import "DateTimePicker.h"
#import "Extensions.h"
#import "ModalPickerViewController.h"
#import "TransparentCoverVerticalAnimator.h"

@interface DateTimePicker() // (Private)


// Configures the UIDatePicker with the NSMutableDictionary options
- (void)configureDatePicker:(NSMutableDictionary *)optionsOrNil datePicker:(UIDatePicker *)datePicker;


@property (readwrite, assign) BOOL isVisible;
@property (strong) NSString* callbackId;

@end


@implementation DateTimePicker


@synthesize isVisible, callbackId;


#pragma mark - Public Methods


- (void)pluginInitialize {
    [self initPickerView:self.webView.superview];
}

- (void)show:(CDVInvokedUrlCommand*)command
{
    if (isVisible) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ILLEGAL_ACCESS_EXCEPTION messageAsString:@"A date/time picker dialog is already showing."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    self.callbackId = command.callbackId;

    NSMutableDictionary *optionsOrNil = [command.arguments objectAtIndex:command.arguments.count - 1];

    [self configureDatePicker:optionsOrNil datePicker:self.modalPicker.datePicker];

    // Present the view with our custom transition.
    [self.viewController presentViewController:self.modalPicker animated:YES completion:nil];

    isVisible = YES;
}

- (void)hide:(CDVInvokedUrlCommand*)command
{
    if (isVisible) {
        // Hide the view with our custom transition.
        [self.modalPicker dismissViewControllerAnimated:true completion:nil];
        [self callbackCancelWithJavascript];
        isVisible = NO;
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onMemoryWarning
{
    // It could be better to close the datepicker before the system clears memory. But in reality, other non-visible plugins should be tidying themselves at this point. This could cause a fatal at runtime.
    if (isVisible) {
        return;
    }

    [super onMemoryWarning];
}


#pragma mark UIViewControllerTransitioningDelegate methods

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                  presentingController:(UIViewController *)presenting
                                                                      sourceController:(UIViewController *)source
{
    TransparentCoverVerticalAnimator *animator = [TransparentCoverVerticalAnimator new];
    animator.presenting = YES;
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    TransparentCoverVerticalAnimator *animator = [TransparentCoverVerticalAnimator new];
    return animator;
}

#pragma mark - Private Methods

- (void)initPickerView:(UIView*)theWebView
{
    ModalPickerViewController *picker = [[ModalPickerViewController alloc]
                                         initWithHeaderText:@""
                                         dismissText:@""
                                         cancelText:@""];

    picker.modalPresentationStyle = UIModalPresentationCustom;
    picker.transitioningDelegate = self;

    __weak ModalPickerViewController* weakPicker = picker;

    picker.headerBackgroundColor = [UIColor colorWithRed:0.92f green:0.92f blue:0.92f alpha:0.95f];

    picker.dismissedHandler = ^(id sender) {
        [self callbackSuccessWithJavascript:weakPicker.datePicker.date];
        isVisible = NO;
    };

    picker.cancelHandler = ^(id sender) {
        [self callbackCancelWithJavascript];
        isVisible = NO;
    };

    self.modalPicker = picker;
}

- (void)configureDatePicker:(NSMutableDictionary *)optionsOrNil datePicker:(UIDatePicker *)datePicker;
{
    long long ticks = [[optionsOrNil objectForKey:@"ticks"] longLongValue];

    // Locale
    NSString *localeString = [optionsOrNil objectForKeyNotNull:@"locale"] ?: @"";
    if (localeString.length == 0)
    {
        localeString = @"EN";
    }
    datePicker.locale = [[NSLocale alloc] initWithLocaleIdentifier:localeString];

    // OK
    NSString *okTextString = [optionsOrNil objectForKeyNotNull:@"okText"] ?: @"";
    if (okTextString.length == 0)
    {
        okTextString = @"Done";
    }
    self.modalPicker.dismissText = okTextString;

    // Cancel
    NSString *cancelTextString = [optionsOrNil objectForKeyNotNull:@"cancelText"] ?: @"";
    if (cancelTextString.length == 0)
    {
        cancelTextString = @"Cancel";
    }
    self.modalPicker.cancelText = cancelTextString;

    // Allow old/future dates
    BOOL allowOldDates = ([[optionsOrNil objectForKeyNotNull:@"allowOldDates"] ?: [NSNumber numberWithInt:1] intValue]) == 1 ? YES : NO;
    BOOL allowFutureDates = ([[optionsOrNil objectForKeyNotNull:@"allowFutureDates"] ?: [NSNumber numberWithInt:1] intValue]) == 1 ? YES : NO;

    // Min/max dates
    long long nowTicks = ((long long)[[NSDate date] timeIntervalSince1970]) * DDBIntervalFactor;
    long long minDateTicks = [[optionsOrNil objectForKeyNotNull:@"minDateTicks"] ?: [NSNumber numberWithLong:(allowOldDates ? DDBMinDate : nowTicks)] longLongValue];
    long long maxDateTicks = [[optionsOrNil objectForKeyNotNull:@"maxDateTicks"] ?: [NSNumber numberWithLong:(allowFutureDates ? DDBMaxDate : nowTicks)] longLongValue];
    if (minDateTicks > maxDateTicks)
    {
        minDateTicks = DDBMinDate;
    }
    datePicker.minimumDate = [NSDate dateWithTimeIntervalSince1970:(minDateTicks / DDBIntervalFactor)];
    datePicker.maximumDate = [NSDate dateWithTimeIntervalSince1970:(maxDateTicks / DDBIntervalFactor)];

    // Mode
    NSString *mode = [optionsOrNil objectForKey:@"mode"];
    if ([mode isEqualToString:@"date"])
    {
        datePicker.datePickerMode = UIDatePickerModeDate;
    }
    else if ([mode isEqualToString:@"time"])
    {
        datePicker.datePickerMode = UIDatePickerModeTime;
    }
    else
    {
        datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    }

    // Minute interval
    NSInteger minuteInterval = [[optionsOrNil objectForKeyNotNull:@"minuteInterval"] ?: [NSNumber numberWithInt:1] intValue];
    datePicker.minuteInterval = minuteInterval;

    // Set to something else first, to force an update.
    datePicker.date = [NSDate dateWithTimeIntervalSince1970:0];
    datePicker.date = [[[NSDate alloc] initWithTimeIntervalSince1970:(ticks / DDBIntervalFactor)] roundToMinuteInterval:minuteInterval];
}

// Sends the date to the plugin javascript handler.
- (void)callbackSuccessWithJavascript:(NSDate *)date
{
    long long ticks = ((long long)[date timeIntervalSince1970]) * DDBIntervalFactor;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setObject:[NSNumber numberWithLongLong:ticks] forKey:@"ticks"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

// Sends a cancellation notification to the plugin javascript handler.
- (void)callbackCancelWithJavascript
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [result setObject:[NSNumber numberWithBool:YES] forKey:@"cancelled"];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

@end
