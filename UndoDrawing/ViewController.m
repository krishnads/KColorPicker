//
//  ViewController.m
//  UndoDrawing
//
//  Created by min on 11/18/14.
//  Copyright (c) 2014 codeall. All rights reserved.
//

#import "ViewController.h"
#import "DKVerticalColorPicker.h"
#import "ImageVC.h"


@interface ViewController () <DKVerticalColorPickerDelegate>
{
    CGPoint lastPoint;
    CGFloat opacity;
    CGFloat brush;
    CGFloat red, green, blue;
    UIImage *previousImage;
    UIImage *rawImage;
}

@property (weak, nonatomic) IBOutlet UIImageView *tempImage;
@property (weak, nonatomic) IBOutlet UIImageView *mainImage;
@property (nonatomic, strong) NSMutableArray *stack;
@property (nonatomic, strong) NSMutableArray *contextArray;

@property (nonatomic, strong) NSMutableArray *pointsArray;
@property (strong, nonatomic) IBOutlet UIView *movingView;
@property (strong, nonatomic) IBOutlet UIView *movingWidthView;
@property (nonatomic, strong) UIColor *selectedColor;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    brush = 4; opacity = 1.0; red = 0.5; green = blue =  0.4;
//    previousImage = self.tempImage.image;
    _stack = [NSMutableArray array];
    _contextArray = [NSMutableArray array];

    rawImage = [UIImage imageNamed:@"0.png"];
    previousImage = [UIImage imageNamed:@"0.png"];
    
    self.movingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    self.movingWidthView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    self.movingWidthView.center = self.movingView.center;
    self.movingWidthView.backgroundColor = self.selectedColor;
    [self.movingView addSubview:self.movingWidthView];
    self.movingView.layer.cornerRadius = 25;
    self.movingView.layer.borderWidth = 0;
    self.movingView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.movingView.layer.masksToBounds = YES;
    
    self.movingWidthView.layer.cornerRadius = 20;
    self.movingWidthView.layer.borderWidth = 4;
    self.movingWidthView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.movingWidthView.layer.masksToBounds = YES;
    
    self.movingView.backgroundColor = self.selectedColor;
    [self.movingView setHidden:YES];
    [self.view addSubview:self.movingView];
    self.selectedColor = [UIColor redColor];
    
}

- (void)viewWillAppear:(BOOL)animated {
    self.title = @"Image Edit";
    //[self.navigationController setNavigationBarHidden:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)btnClicked:(id)sender {
    if ([self.undoManager canUndo]) {
        [self.undoManager undo];
    }
}

- (IBAction)redoBtnClicked:(id)sender {
    if ([self.undoManager canRedo]) {
        [self.undoManager redo];
    }
}

- (IBAction)resetAction:(id)sender {
    [self setImage:previousImage fromImage:self.tempImage.image];
}

- (IBAction)saveAction:(id)sender {
    [self performSegueWithIdentifier:@"NAVIGATE_TO_IMAGE" sender:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    _pointsArray = [NSMutableArray array];
    [_pointsArray addObject:NSStringFromCGPoint(lastPoint)];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.tempImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, brush);
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), self.selectedColor.CGColor);
    CGContextMoveToPoint(context, lastPoint.x, lastPoint.y);
    CGContextAddLineToPoint(context, lastPoint.x, lastPoint.y);
    CGContextStrokePath(context);
    self.tempImage.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.tempImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextMoveToPoint(context, lastPoint.x, lastPoint.y);
    CGContextAddLineToPoint(context, currentPoint.x, currentPoint.y);
    
    //Now set our brush size and opacity and brush stroke color:
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, brush );
    CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), self.selectedColor.CGColor);
    CGContextSetBlendMode(context,kCGBlendModeNormal);
    CGContextStrokePath(context);
    
    self.tempImage.image = UIGraphicsGetImageFromCurrentImageContext();
    [self.tempImage setAlpha:opacity];
    UIGraphicsEndImageContext();
    
    lastPoint = currentPoint;
    [self.pointsArray addObject:NSStringFromCGPoint(lastPoint)];
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    //handle single tap, make _pointsArray has two identical points, draw a line between them
    if (_pointsArray.count == 1) {
        [_pointsArray addObject:NSStringFromCGPoint(lastPoint)];
    }

    [self.stack addObject:_pointsArray];
    NSLog(@"color -> %@ \nwidth->%f", self.selectedColor.description, brush);
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    [dic setObject:self.selectedColor forKey:@"color"];
    [dic setObject:[NSNumber numberWithFloat:brush] forKey:@"width"];
    [self.contextArray addObject:dic];
    
    [self.undoManager registerUndoWithTarget: self
                                    selector: @selector(popDrawing)
                                      object: nil];

}

- (void)pushDrawing:(NSDictionary *)allDic
{
    
    [self.stack addObject: (NSArray *)[allDic objectForKey:@"points"]];
    [self.contextArray addObject:(NSDictionary *)[allDic objectForKey:@"context"]];
    
    [self redrawLastLine:(NSArray *)[allDic objectForKey:@"points"]];

    [self.undoManager registerUndoWithTarget: self
                                    selector: @selector(popDrawing)
                                      object: nil];
}

- (void)popDrawing
{
    NSArray *array = [self.stack lastObject];
    [self.stack removeLastObject];
    NSDictionary *contextDic = [_contextArray lastObject];
    
    NSDictionary *allDic = @{
                             @"points" : array,
                             @"context" : contextDic
                             };
    [self.contextArray removeLastObject];
    [self redrawLinePathsInStack];
    [self.undoManager registerUndoWithTarget: self
                                    selector: @selector(pushDrawing:)
                                      object: allDic];
}

- (void)redrawLastLine:(NSArray*)array
{
    UIGraphicsBeginImageContext(self.view.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.tempImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetBlendMode(context,kCGBlendModeNormal);
    
    for(int i = 0; i < array.count - 1; i++)
    {
        NSDictionary *contextDic = [self.contextArray lastObject];
        float lineWidth = [[contextDic objectForKey:@"width"] floatValue];
        UIColor *lineColor = (UIColor *)[contextDic objectForKey:@"color"] ;
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), lineColor.CGColor);

        NSString *pointStr = [array objectAtIndex:i];
        NSString *pointStr1 = [array objectAtIndex:i+1];
        
        CGPoint point = CGPointFromString(pointStr);
        CGPoint point1 = CGPointFromString(pointStr1);
        
        CGContextMoveToPoint(context, point.x, point.y);
        CGContextAddLineToPoint(context, point1.x, point1.y);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
    }

    
    self.tempImage.image = UIGraphicsGetImageFromCurrentImageContext();
    [self.tempImage setAlpha:opacity];
    UIGraphicsEndImageContext();
}

- (void)redrawLinePathsInStack
{
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [rawImage drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CGContextSetLineCap(context, kCGLineCapRound);

    CGContextSetBlendMode(context,kCGBlendModeNormal);
    
    int count = 0;
    for (NSArray *array in self.stack)
    {
        NSDictionary *contextDic = [self.contextArray objectAtIndex:count];
        float lineWidth = [[contextDic objectForKey:@"width"] floatValue];
        UIColor *lineColor = (UIColor *)[contextDic objectForKey:@"color"] ;
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetStrokeColorWithColor(UIGraphicsGetCurrentContext(), lineColor.CGColor);
        
        for(int i = 0; i < array.count - 1; i++)
        {
            NSString *pointStr = [array objectAtIndex:i];
            NSString *pointStr1 = [array objectAtIndex:i+1];
            
            CGPoint point = CGPointFromString(pointStr);
            CGPoint point1 = CGPointFromString(pointStr1);
            
            CGContextMoveToPoint(context, point.x, point.y);
            CGContextAddLineToPoint(context, point1.x, point1.y);
            CGContextStrokePath(UIGraphicsGetCurrentContext());
        }
        count ++;
    }
    
    self.tempImage.image = UIGraphicsGetImageFromCurrentImageContext();
    [self.tempImage setAlpha:opacity];
    UIGraphicsEndImageContext();
}

- (void)setImage:(UIImage*)currentImage fromImage:(UIImage*)preImage
{
    // Prepare undo-redo
    [[self.undoManager prepareWithInvocationTarget:self] setImage:preImage fromImage:currentImage];
    //self.mainImage.image = currentImage;
    self.tempImage.image = currentImage;
    //prev = currentImage;
}


#pragma mark color picker delegate

- (void)colorPicked:(UIColor *)color withXAxis:(float)x andYAxis:(float)y {
    if (self.movingView.isHidden) {
        [self.movingView setHidden:NO];
    }
    
    self.selectedColor = color;
    //[self.drawerView setSelectedColor:color];
    self.movingView.backgroundColor = color;
    
    //NSLog(@"touch distance ->%f", y);
    if (x <= 0) {
        float distanceFromPicker = (-1) * x;
        //[self.drawerView setFontWidth:distanceFromPicker / 10];
        float brushWidth = distanceFromPicker / 10;
        if (brushWidth > 1) {
            brush = distanceFromPicker / 10;
        }
        else {
            brushWidth = 1;
        }
        self.movingView.center = CGPointMake(300 - distanceFromPicker, y);
        self.movingWidthView.layer.borderWidth = 15 - (distanceFromPicker / 20);
    }
}

- (void)endDraging {
    [self.movingView setHidden:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    ImageVC *imgVC = [segue destinationViewController];
    imgVC.image = self.tempImage.image;
}

@end
