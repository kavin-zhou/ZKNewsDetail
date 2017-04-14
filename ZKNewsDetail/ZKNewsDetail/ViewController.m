//
//  ViewController.m
//  ZKNewsDetail
//
//  Created by ZK on 2017/4/14.
//  Copyright © 2017年 ZK. All rights reserved.
//

#import "ViewController.h"
#import "WebViewJavascriptBridge.h"
#import "AFNetworking.h"
#import "GRMustache.h"
#import "DataInfo.h"
#import "ImageInfo.h"
#import "YYModel.h"
#import "SDWebImageManager.h"
#import "MWPhotoBrowser.h"

#define HexColor(hexValue)   [UIColor colorWithRed:((float)(((hexValue) & 0xFF0000) >> 16))/255.0 green:((float)(((hexValue) & 0xFF00) >> 8))/255.0 blue:((float)((hexValue) & 0xFF))/255.0 alpha:1]

@interface ViewController () <UIWebViewDelegate ,MWPhotoBrowserDelegate>
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) NSString *detailID;
@property (strong, nonatomic) NSMutableArray *imagesArr;
@property (strong, nonatomic) NSMutableArray *MWPhotoArr;
@property (strong, nonatomic) WebViewJavascriptBridge *bridge;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUI];
    [self initBridge];
    [self requestNetData];
}

- (void)initUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.webView];
    _webView.backgroundColor = HexColor(0xf6f6f6);
}

- (void)initBridge {
    // 开启日志
    [WebViewJavascriptBridge enableLogging];
    
    self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView];
    [self.bridge setWebViewDelegate:self];
    
    [self.bridge registerHandler:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"JS 主动调 OC");
    }];
    
    //注册图片点击事件
    __weak typeof(self)weakSelf = self;
    [self.bridge registerHandler:@"tapImage" handler:^(id data, WVJBResponseCallback responseCallback) {
        //点击图片的index
        NSLog(@"=======%@=========", data);
        NSString *index = (NSString *)data;
        [weakSelf browseImages:index.integerValue];
    }];
    
    //oc主动调用js
    [self.bridge callHandler:@"testJavascriptHandler" data:nil responseCallback:^(id responseData) {
        NSLog(@"OC 主动调 JS");
    }];
}

//初始化图片浏览器
- (void)browseImages:(NSInteger)index {
    if (index >= self.imagesArr.count) {
        NSLog(@"图片index出错，越界");
    }
    
    self.MWPhotoArr = [NSMutableArray array];
    for (NSURL *url in self.imagesArr) {
        [self.MWPhotoArr addObject:[MWPhoto photoWithURL:url]];
    }
    
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [browser setCurrentPhotoIndex:index];
    browser.zoomPhotosToFill = NO;
    browser.alwaysShowControls = YES;
    [self.navigationController pushViewController:browser animated:YES];
}

#pragma mark - MWPhotoBrowserDelegate
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.MWPhotoArr.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index >= self.MWPhotoArr.count) {
        return nil;
    }
    return self.MWPhotoArr[index];
}

- (void)requestNetData {
    self.detailID = @"AQ72N9QG00051CA1";
    //AQ4RPLHG00964LQ9
    
    NSMutableString *urlStr = [NSMutableString stringWithString:@"http://c.m.163.com/nc/article/newsId/full.html"];
    [urlStr replaceOccurrencesOfString:@"newsId" withString:_detailID options:NSCaseInsensitiveSearch range:[urlStr rangeOfString:@"newsId"]];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    __weak typeof(self)weakSelf = self;
    [manager GET:urlStr parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        DataInfo *model = [DataInfo yy_modelWithJSON:[responseObject objectForKey:self.detailID]];
        NSLog(@"请求成功");
        [weakSelf handleData:model];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull   error) {
        NSLog(@"%@",error);  //这里打印错误信息
    }];
}

- (void)handleData:(DataInfo *)data {
    if (!data) {
        NSLog(@"返回数据错误");
        return;
    }
    
    NSMutableString *allTitleStr = [self handleNewsTitle:data];
    NSMutableString *bodyStr = [self handleImageInNews:data];
    
    NSString *str5 = [allTitleStr stringByAppendingString:bodyStr];
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"NewsHtml" ofType:@"html"];
    NSMutableString *appHtml = [NSMutableString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    [appHtml replaceOccurrencesOfString:@"<p>mainnews</p>" withString:str5 options:NSCaseInsensitiveSearch range:[appHtml rangeOfString:@"<p>mainnews</p>"]];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [self.webView loadHTMLString:appHtml baseURL:baseURL];
}

//处理新闻body中的图片
- (NSMutableString *)handleImageInNews:(DataInfo *)data {
    NSMutableString *bodyStr = [data.body mutableCopy];
    
    [data.img enumerateObjectsUsingBlock:^(ImageInfo *info, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [bodyStr rangeOfString:info.ref];
        NSArray *sizes = [info.pixel componentsSeparatedByString:@"*"];
        CGFloat width = [sizes[0] floatValue];
        CGFloat height = [sizes[1] floatValue];
        
        height = [UIScreen mainScreen].bounds.size.width * height / width;
        
        //占位图
        NSString *loadingImg = [[NSBundle mainBundle] pathForResource:@"loading" ofType:@"png"];
        NSString *imageStr = [NSString stringWithFormat:@"<p style = 'text-align:center'><img onclick = 'didTappedImage(%lu);' src = %@ id = '%@' width = '%.0f' height = '%.0f' style='width: 100%%;' /></p><p style='text-align:center;'>%@</p>", (unsigned long)idx, loadingImg, info.src, [UIScreen mainScreen].bounds.size.width, height, info.alt];
        [bodyStr replaceOccurrencesOfString:info.ref withString:imageStr options:NSCaseInsensitiveSearch range:range];
    }];
    
    [self getImageFromDownloaderOrDiskByImageUrlArray:data.img];
    
    return bodyStr;
}

//处理title的拼接显示
- (NSMutableString *)handleNewsTitle:(DataInfo *)data {
    NSString *htmlTitleStr = @"<h2 class = 'thicker'>{{title}}</h2><h3>{{source}} {{ptime}}</h3>";
    return [[GRMustacheTemplate renderObject:@{@"title" : data.title, @"source" : data.source, @"ptime" : data.ptime} fromString:htmlTitleStr error:NULL] mutableCopy];
}

- (void)getImageFromDownloaderOrDiskByImageUrlArray:(NSArray *)imageArray {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    self.imagesArr = [NSMutableArray array];
    __weak typeof(self)weakSelf = self;
    for (ImageInfo *info in imageArray) {
        NSURL *imageUrl = [NSURL URLWithString:info.src];
        [self.imagesArr addObject:imageUrl];
        [imageManager diskImageExistsForURL:imageUrl completion:^(BOOL isInCache) {
            isInCache ? [weakSelf handleExistCache:imageUrl] : [weakSelf handleNotExistCache:imageUrl];
        }];
    }
}

//已经有图片缓存
- (void)handleExistCache:(NSURL *)imageUrl {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    NSString *cacheKey = [imageManager cacheKeyForURL:imageUrl];
    NSString *imagePath = [imageManager.imageCache defaultCachePathForKey:cacheKey];
    
    NSString *sendData = [NSString stringWithFormat:@"replaceimage%@,%@", imageUrl.absoluteString, imagePath];
    [self.bridge callHandler:@"replaceImage" data:sendData responseCallback:^(id responseData) {
        NSLog(@"%@", responseData);
    }];
}

//本地没有图片缓存
- (void)handleNotExistCache:(NSURL *)imageUrl {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    __weak typeof(self)weakSelf = self;
    
    [imageManager downloadImageWithURL:imageUrl options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        if (image && finished) {
            NSLog(@"下载成功");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf handleExistCache:imageUrl];
            });
        } else {
            NSLog(@"图片下载失败");
        }
    }];
}

@end
