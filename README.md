# 用MATLAB结合PushBear、TrackingMore API实现物流信息自动推送。

###### powered by [MATLAB](https://www.mathworks.com/products/matlab.html)/[Pushbear](https://pushbear.ftqq.com/admin/)/[TrackingMore (收费API)](https://www.trackingmore.com)

## 简介

- 定时查询，默认十五分钟查询一次。
- 支持根据运单号自动判断快递公司。
- try...catch...end模块容错。
- 亦可更改部分代码实现自动推送至Telegram。

## 设置方法

#### 推送准备

##### Pushbear准备

创建通道，MATLAB脚本中要用到通道的sendkey。

#### TrackingMore API准备

付费API，付费账户可拿到API key。

## 后记

Inspired by [少数派：利用 IFTTT Maker DIY 你的 Applet](https://sspai.com/post/39243)
