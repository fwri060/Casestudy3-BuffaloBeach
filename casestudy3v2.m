clear
clc
close all

%% Load shoreline data

% Import data and extract dates
data = readtable('nzd0176.xlsx','Sheet','Intersects','VariableNamingRule','preserve');

dates = datetime(data{:,1},'InputFormat','yyyy-MM-dd HH:mm:ssXXX','TimeZone','UTC');
dates.TimeZone = '';

% Extract shoreline positions and transect names
shoreline = data{:,2:end-1};
transectNames = string(data.Properties.VariableNames(2:end-1));
nTransects = size(shoreline,2);

disp(nTransects)

%% Historical shoreline positions

% Plot shoreline position through time for all transects
figure
plot(dates,shoreline)
xlabel('Year')
ylabel('Shoreline position (m)')
title('Historical Shoreline Positions')
grid on

%% Historical shoreline change rates

% Convert dates to decimal years for linear regression
decimalYear = year(dates) + (day(dates,'dayofyear')-1)./365.25;

changeRate = NaN(1,nTransects);
R2 = NaN(1,nTransects);

% Calculate a linear shoreline trend for each transect
for i = 1:nTransects

    y = shoreline(:,i);
    valid = ~isnan(y);

    x = decimalYear(valid);
    y = y(valid);

    p = polyfit(x,y,1);
    changeRate(i) = p(1);

    predicted = polyval(p,x);

    SSres = sum((y-predicted).^2);
    SStot = sum((y-mean(y)).^2);

    R2(i) = 1-SSres/SStot;

end

% Display results
historicalResults = table(transectNames',changeRate',R2',...
    'VariableNames',{'Transect','ChangeRate_m_per_year','R_squared'});

disp(historicalResults)

%% Historical change rate plot

% Plot the shoreline change rate for each transect
figure
bar(changeRate)
yline(0,'--')
xlabel('Transect')
ylabel('Shoreline change rate (m/year)')
title('Historical Shoreline Change Rates')
xticks(1:2:nTransects)
xticklabels(0:2:nTransects-1)
xtickangle(45)
grid on

%% Selected historical shoreline trends

% Select transects representing different shoreline trends
selected = [6 19 35 41];
colours = lines(length(selected));

figure
hold on

for j = 1:length(selected)

    i = selected(j);

    y = shoreline(:,i);
    valid = ~isnan(y);

    x = decimalYear(valid);
    y = y(valid);

    p = polyfit(x,y,1);

    % Use the same colour for data and trend line
    plot(dates(valid),y,'.','Color',colours(j,:))
    plot(dates(valid),polyval(p,x),'LineWidth',2,...
        'Color',colours(j,:))

end

xlabel('Year')
ylabel('Shoreline position (m)')
title('Selected Historical Shoreline Trends')
legend('0005 data','0005 trend',...
    '0018 data','0018 trend',...
    '0034 data','0034 trend',...
    '0040 data','0040 trend',...
    'Location','best')
xlim([datetime(1999,1,1) datetime(2026,1,1)])
ylim([295 445])
grid on

%% Seasonal shoreline variability

% Remove the long-term trend from each transect
detrendedShoreline = NaN(size(shoreline));

for i = 1:nTransects

    y = shoreline(:,i);
    valid = ~isnan(y);

    p = polyfit(decimalYear(valid),y(valid),1);
    trend = polyval(p,decimalYear(valid));

    detrendedShoreline(valid,i) = y(valid) - trend;

end

% Calculate mean detrended shoreline anomaly for each month
months = month(dates);
monthlyAnomaly = NaN(12,nTransects);

for m = 1:12
    monthlyAnomaly(m,:) = mean(detrendedShoreline(months==m,:),1,'omitnan');
end

meanSeasonal = mean(monthlyAnomaly,2,'omitnan');

% Plot average seasonal pattern
figure
plot(1:12,meanSeasonal,'o-','LineWidth',2)
yline(0,'--')
xlabel('Month')
ylabel('Mean detrended shoreline anomaly (m)')
title('Seasonal Shoreline Variability')
xticks(1:12)
xticklabels({'Jan','Feb','Mar','Apr','May','Jun',...
    'Jul','Aug','Sep','Oct','Nov','Dec'})
grid on

%% Beach slope

% Import transect information and extract beach slope
transectData = readtable('nzd0176.xlsx','Sheet','Transects','VariableNamingRule','preserve');

beachSlope = transectData.beach_slope;
alongDistance = transectData.along_dist;

% Plot beach slope along the coastline
figure
plot(alongDistance,beachSlope,'o-','LineWidth',1.5)
xlabel('Distance along coast (m)')
ylabel('Beach slope')
title('Beach Slope Along the Coast')
grid on

%% Projected shoreline retreat by 2100

% Additional sea-level rise from approximately 2026 to 2100 (p50 + VLM)
SLR = [0.55 0.67 0.83] - [0.106 0.110 0.106];

% Calculate retreat using the beach slope relationship
retreat = SLR ./ beachSlope;

% Plot projected retreat along the coast
figure
plot(alongDistance,retreat(:,1),'LineWidth',1.5)
hold on
plot(alongDistance,retreat(:,2),'LineWidth',1.5)
plot(alongDistance,retreat(:,3),'LineWidth',1.5)

xlabel('Distance along coast (m)')
ylabel('Projected shoreline retreat (m)')
title('Projected Shoreline Retreat by 2100')
legend('SSP1-2.6','SSP2-4.5','SSP3-7.0','Location','best')
grid on

%% Sea-level rise uncertainty

% SSP2-4.5 uncertainty adjusted from approximately 2026 to 2100
SLR_uncertainty = [0.32 0.67 1.06] - [0.008 0.110 0.214];

% Calculate retreat across the uncertainty range
retreat_uncertainty = SLR_uncertainty ./ beachSlope;

% Plot uncertainty in projected retreat
figure
plot(alongDistance,retreat_uncertainty(:,1),'--','LineWidth',1.5)
hold on
plot(alongDistance,retreat_uncertainty(:,2),'LineWidth',2)
plot(alongDistance,retreat_uncertainty(:,3),'--','LineWidth',1.5)

xlabel('Distance along coast (m)')
ylabel('Projected shoreline retreat (m)')
title('Uncertainty in Projected Retreat - SSP2-4.5')
legend('p17','p50','p83','Location','best')
grid on

%% Current and projected shoreline

% Find the most recent available shoreline position at each transect
currentShore = NaN(nTransects,1);

for i = 1:nTransects
    valid = find(~isnan(shoreline(:,i)),1,'last');
    currentShore(i) = shoreline(valid,i);
end

% Extract land and sea coordinates for each transect
landLon = transectData.land_x;
landLat = transectData.land_y;
seaLon = transectData.sea_x;
seaLat = transectData.sea_y;

% Approximate transect length in metres
meanLat = (landLat + seaLat)/2;
dx = (seaLon-landLon).*111320.*cosd(meanLat);
dy = (seaLat-landLat).*111320;
transectLength = sqrt(dx.^2 + dy.^2);

% Position of the current shoreline along each transect
currentFraction = currentShore ./ transectLength;

currentLon = landLon + currentFraction.*(seaLon-landLon);
currentLat = landLat + currentFraction.*(seaLat-landLat);

% Apply SSP2-4.5 p50 retreat towards land
projectedShore = currentShore - retreat(:,2);
projectedFraction = projectedShore ./ transectLength;

projectedLon = landLon + projectedFraction.*(seaLon-landLon);
projectedLat = landLat + projectedFraction.*(seaLat-landLat);

% Convert shoreline coordinates to local distances in metres
refLon = mean(currentLon);
refLat = mean(currentLat);

currentX = (currentLon-refLon).*111320.*cosd(refLat);
currentY = (currentLat-refLat).*111320;

projectedX = (projectedLon-refLon).*111320.*cosd(refLat);
projectedY = (projectedLat-refLat).*111320;

% Plot northern section of the coastline
north = 1:11;

figure
plot(currentX(north),currentY(north),'o-','LineWidth',1.5)
hold on
plot(projectedX(north),projectedY(north),'o-','LineWidth',1.5)

% Highlight transect 0006, which has the greatest projected retreat
plot([currentX(7) projectedX(7)],...
     [currentY(7) projectedY(7)],...
     'w-o','MarkerSize',8,'LineWidth',2)

xlabel('East-west distance (m)')
ylabel('North-south distance (m)')
title('Projected 2100 Shoreline - Northern Buffalo Beach')
legend('Current shoreline', '2100 SSP2-4.5', ...
    'Maximum retreat (~37 m)', 'Location', 'southeast');
grid on
axis equal

%% Summary of key results

% Historical shoreline change
fprintf('\n--- Historical Shoreline Change ---\n')
fprintf('Mean change rate: %.2f m/year\n',mean(changeRate,'omitnan'))
fprintf('Greatest erosion rate: %.2f m/year\n',min(changeRate))
fprintf('Greatest accretion rate: %.2f m/year\n',max(changeRate))

% Projected retreat under each sea-level rise scenario
fprintf('\n--- Projected Retreat by 2100 ---\n')
fprintf('Maximum retreat SSP1-2.6: %.1f m\n',max(retreat(:,1)))
fprintf('Maximum retreat SSP2-4.5: %.1f m\n',max(retreat(:,2)))
fprintf('Maximum retreat SSP3-7.0: %.1f m\n',max(retreat(:,3)))

% Identify the location of maximum projected retreat
[maxRetreat,maxIndex] = max(retreat(:,2));

fprintf('\n--- Maximum Retreat Location ---\n')
fprintf('Transect: %d\n',maxIndex-1)
fprintf('Distance along coast: %.0f m\n',alongDistance(maxIndex))
fprintf('Maximum retreat: %.1f m\n',maxRetreat)

% Uncertainty at the maximum retreat location
fprintf('\n--- SSP2-4.5 Uncertainty ---\n')
fprintf('p17 retreat: %.1f m\n',retreat_uncertainty(maxIndex,1))
fprintf('p50 retreat: %.1f m\n',retreat_uncertainty(maxIndex,2))
fprintf('p83 retreat: %.1f m\n',retreat_uncertainty(maxIndex,3))
