%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 用MATLAB结合PushBear、TrackingMore API实现物流信息自动推送至微信。

% 功能：
%     定时查询，默认十五分钟查询一次。
%     根据运单号自动判断快递公司。

% 需设置：
%     PushBear key；TrackingMore API key

% Author: github.com/chouj
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%% 获取所有承运商简码 %%%%%%%%%%
try
    t = regexp(webread('https://www.trackingmore.com/help_article-16-30-cn.html'),...
'<tr><td>(.*?)</td><td>.*?</td><td>(.*?)</td></tr>','tokens');
catch
    pause(60);
    t = regexp(webread('https://www.trackingmore.com/help_article-16-30-cn.html'),...
'<tr><td>(.*?)</td><td>.*?</td><td>(.*?)</td></tr>','tokens');
end

for i=1:length(t)
    tt{i}=cell2mat(t{i}(1,1));
    tn{i}=cell2mat(t{i}(1,2));
end
clear t
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PBSendKey='{YourKey}'; % 请填入你的PushBear通道Key

TrackingmoreAPIKey='{YourKey}'; % 请填入你的TrackingMoreAPIkey

options = weboptions('RequestMethod','post',...
        'KeyName','Trackingmore-Api-Key',...
        'KeyValue',TrackingmoreAPIKey,...
        'MediaType','application/json',...
        'CharacterEncoding','utf-8',...
        'Timeout',60);

trackingNum=input('请输入单号:','s');
if isempty(trackingNum)
    trackingNum=input('请重新输入单号:','s');
end

WhatItIs=input('请输入包裹备注，比如购买的什么商品:','s');
if isempty(trackingNum)
    trackingNum=input('请重新输入:','s');
end

Body = struct( 'tracking_number',trackingNum);

%%%%%%%%%% 根据单号进行快递承运商识别 %%%%%%%%%%
% 调用TrackingMore 承运商识别 API
try
    carrier = webwrite('https://api.trackingmore.com/v2/carriers/detect',Body, options);
catch
    pause(20);
    carrier = webwrite('https://api.trackingmore.com/v2/carriers/detect',Body, options);
end

% 若未查到快递商则重新输入单号再试一次
while isempty(carrier.data)
    trackingNum=input('查询不到承运快递商，请输入正确单号：','s');
    if isempty(trackingNum)
        trackingNum=input('请重新输入单号:','s');
    end

    Body = struct( 'tracking_number',trackingNum);

    try
        carrier = webwrite('https://api.trackingmore.com/v2/carriers/detect',Body, options);
    catch
        pause(20);
        carrier = webwrite('https://api.trackingmore.com/v2/carriers/detect',Body, options);
    end
end

% 若可能快递商不止一家，则显示可能快递商列表供选。
if length(carrier.data)>1
    for i=1:length(carrier.data)
        carrier.data(i).num=i;
    end
    
    struct2table(carrier.data)

    carrierI=input('请输入快递承运商的数字编号，不在列表中请输入0:');
    while carrierI<0|carrierI>length(carrier.data)|carrierI~=round(carrierI)
        carrierI=input('编号输入有误，请重新输入快递承运商的数字编号：');
    end
else
    carrierI=1;
end

% 如若未能通过API识别出快递商，则自行根据网页查找承运商代码并输入。
if carrierI==0
    carriercode=input('承运商不在上述列表，请自行查找承运商代码（https://www.trackingmore.com/help_article-16-30-cn.html）并输入：','s');
    while isempty(find(strcmp(carriercode,tt)==1))==1
        carriercode=input('代码输入有误，请重新输入快递承运商的代码：','s');
    end
    Body=struct( 'tracking_number',trackingNum,'carrier_code',carriercode);
    carriername=tn{find(strcmp(carriercode,tt)==1)};
else
    Body=struct( 'tracking_number',trackingNum,'carrier_code',carrier.data(carrierI).code);
    carriername=tn{find(strcmp(carrier.data(carrierI).code,tt)==1)};
end
    
optionsPB = weboptions('RequestMethod','post','Timeout',60);

% 调用TrackingMore物流信息查询API
try
    info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
catch
    pause(20);
    info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
end

disp([info.data.items.status,': ',info.data.items.lastEvent]);

% 根据包裹状态info.data.items.status判定是否推送
try % 用try...catch...end容错
    while strcmp(info.data.items.status,'pending')==0 % 只要不是pending状态就开启循环

        if sum(strcmp('lastupdatetime',who))==0 % 用lastupdatetime作为判断本次查询状态与上一循环查询状态是否一致的判据
            if strcmp(info.data.items.status,'notfound') %若是未找到包裹状态，则推送“可能尚未揽件”。
                try 
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                    'sendkey',PBSendKey,...
                    'text',[carriername,' - ',trackingNum],...
                    'desp','可能快递商尚未揽件。',...
                    optionsPB);
                catch
                    pause(30);
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                    'sendkey',PBSendKey,...
                    'text',[carriername,' - ',trackingNum],...
                    'desp','可能快递商尚未揽件。',...
                    optionsPB);
                end
                lastupdatetime=datetime('now'); % 生成最后更新时间。
            else %否则，推送最近一次物流信息info.data.items.lastEvent。
                try 
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                catch
                    pause(30);
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                end

                  lastupdatetime=datetime(info.data.items.lastUpdateTime); %将最近一次物流信息的更新时间作为lastupdatetime。
            end
        else % 若workspace已有lastupdatetime
            if strcmp(info.data.items.status,'notfound')==0 %如果包裹状态不是未找到
                if eq(lastupdatetime,datetime(info.data.items.lastUpdateTime))==0 
                %而且最近一次物流信息的时间与lastupdatetime不一致，则表明新物流信息未推送过。
                    try 
                        response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                    catch
                        pause(30);
                        response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                    end
                    lastupdatetime=datetime(info.data.items.lastUpdateTime); %更新lastupdattime
                end
            end
        end
        
        pause(900) %15分钟后再次查询
        
        try
            info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
        catch
            pause(20);
            info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
        end
        disp([info.data.items.status,': ',info.data.items.lastEvent]);
        
        if strcmp(info.data.items.status,'delivered')==1&eq(lastupdatetime,datetime(info.data.items.lastUpdateTime))==0
        % 如果包裹状态是已投递，且lastupdatetime与最近物流信息时间不一致，则推送“已投递”的新信息，并终止循环
            try 
                response = webwrite('https://pushbear.ftqq.com/sub',...
                'sendkey',PBSendKey,...
                'text',[carriername,'承运的',WhatItIs],...
                'desp',info.data.items.lastEvent,...
                optionsPB);
            catch
                pause(30);
                response = webwrite('https://pushbear.ftqq.com/sub',...
                'sendkey',PBSendKey,...
                'text',[carriername,'承运的',WhatItIs],...
                'desp',info.data.items.lastEvent,...
                optionsPB);
            end
            break
        end
    end
catch % 容错部分
    while strcmp(info.data.items.status,'pending')==0
        if sum(strcmp('lastupdatetime',who))==0
            if strcmp(info.data.items.status,'notfound')
                try 
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                    'sendkey',PBSendKey,...
                    'text',[carriername,' - ',trackingNum],...
                    'desp','可能快递商尚未揽件。',...
                    optionsPB);
                catch
                    pause(30);
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                    'sendkey',PBSendKey,...
                    'text',[carriername,' - ',trackingNum],...
                    'desp','可能快递商尚未揽件。',...
                    optionsPB);
                end
                lastupdatetime=datetime('now');
            else
                try 
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                catch
                    pause(30);
                    response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                end
                  lastupdatetime=datetime(info.data.items.lastUpdateTime);
            end
        else
            if strcmp(info.data.items.status,'notfound')==0
                if eq(lastupdatetime,datetime(info.data.items.lastUpdateTime))==0
                    try 
                        response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                    catch
                        pause(30);
                        response = webwrite('https://pushbear.ftqq.com/sub',...
                        'sendkey',PBSendKey,...
                        'text',[carriername,'承运的',WhatItIs],...
                        'desp',[info.data.items.lastEvent,' [运单号:',trackingNum,']'],...
                        optionsPB);
                    end
                    lastupdatetime=datetime(info.data.items.lastUpdateTime);
                end
            end
        end
        pause(900)
        try
            info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
        catch
            pause(20);
            info = webwrite('https://api.trackingmore.com/v2/trackings/realtime',Body, options);
        end
        disp([info.data.items.status,': ',info.data.items.lastEvent]);
        if strcmp(info.data.items.status,'delivered')==1&eq(lastupdatetime,datetime(info.data.items.lastUpdateTime))==0
            try 
                response = webwrite('https://pushbear.ftqq.com/sub',...
                'sendkey',PBSendKey,...
                'text',[carriername,'承运的',WhatItIs],...
                'desp',info.data.items.lastEvent,...
                optionsPB);
            catch
                pause(30);
                response = webwrite('https://pushbear.ftqq.com/sub',...
                'sendkey',PBSendKey,...
                'text',[carriername,'承运的',WhatItIs],...
                'desp',info.data.items.lastEvent,...
                optionsPB);
            end
            break
        end
    end
end
