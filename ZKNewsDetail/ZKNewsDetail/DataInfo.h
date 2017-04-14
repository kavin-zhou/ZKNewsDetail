//
//  ViewController.m
//  ZKNewsDetail
//
//  Created by ZK on 2017/4/14.
//  Copyright © 2017年 ZK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YYModel.h"

@interface DataInfo : NSObject <YYModel>

@property (strong, nonatomic) NSString *body;
@property (strong, nonatomic) NSMutableArray *img;
@property (strong, nonatomic) NSString *source;
@property (strong, nonatomic) NSString *ptime;
@property (strong, nonatomic) NSString *title;

@end
