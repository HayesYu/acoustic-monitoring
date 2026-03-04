% Grid search for best K-feature subsets (5-fold CV, robust linear)
% Input: merged_features.mat with table T (Signal, features, Power, Speed)
% Output: CSVs ranking all K-feature combos for Power and Speed by CV RMSE.

clear; clc;
rng default

%% -------- Parameters --------
chooseKPower = 3;    % 选多少个特征用于 Power
chooseKSpeed = 3;    % 选多少个特征用于 Speed
Kprune = 16;         % 先按相关性预筛保留<=Kprune个候选
colThr = 0.90;       % 去共线阈值（相关>此阈值的候选不同时保留）
topKReport = 10;     % 命令行打印前多少组
maxCombos = 5000;    % 组合数过大时随机抽样上限（防止组合爆炸）

%% Load merged table
if ~exist('T','var')
    load merged_features.mat  % loads T
end

% All candidate feature names (only those that exist in T will be used)
allCand = ["Duration_s","RMS","PeakToPeak","Crest","Skewness","Kurtosis", ...
           "ZeroCrossRate_Hz","MainFreq_Hz","PeakAmp","SpectralCentroid_Hz", ...
           "Bandwidth_Hz","TotalEnergy", ...
           "SpectralEntropy","BandE_0k_5k","BandE_5k_10k","BandE_10k_20k","BandE_20k_40k","BandE_40k_64k","HighLowBandRatio"]; % 若已在特征脚本里添加

% Keep only existing columns in T
cand = intersect(allCand, string(T.Properties.VariableNames), 'stable');

%% ---------- POWER ----------
fprintf('\n=== POWER: select %d features ===\n', chooseKPower);
trainP = T(~isnan(T.Power), :);
[yP, candP, XcandP] = preparePool(trainP, 'Power', cand, Kprune, colThr);
rankP = rankCombos(XcandP, yP, candP, chooseKPower, maxCombos);  % table sorted by RMSE
if ~isempty(rankP)
    disp(rankP(1:min(topKReport,height(rankP)), :))
    outP = sprintf('top_combos_power_k%d.csv', chooseKPower);
    writetable(rankP, outP);
    fprintf('Saved: %s\n', outP);
else
    warning('No combos evaluated for Power (candidate count < %d).', chooseKPower);
end

%% ---------- SPEED ----------
fprintf('\n=== SPEED: select %d features ===\n', chooseKSpeed);
trainV = T(~isnan(T.Speed), :);
[yV, candV, XcandV] = preparePool(trainV, 'Speed', cand, Kprune, colThr);
rankV = rankCombos(XcandV, yV, candV, chooseKSpeed, maxCombos);
if ~isempty(rankV)
    disp(rankV(1:min(topKReport,height(rankV)), :))
    outV = sprintf('top_combos_speed_k%d.csv', chooseKSpeed);
    writetable(rankV, outV);
    fprintf('Saved: %s\n', outV);
else
    warning('No combos evaluated for Speed (candidate count < %d).', chooseKSpeed);
end

save top_combo_results.mat rankP rankV

%% ================== helper functions ==================
function [y, names2, X2] = preparePool(TrainTbl, target, cand, Kprune, colThr)
    % Build candidate matrix, shrink by correlation and de-collinearization
    y = TrainTbl.(target);
    Xall = TrainTbl{:, cand};

    % drop columns with zero variance or too many NaNs
    v = var(Xall, 0, 1, 'omitnan');
    keep = isfinite(v) & v > 0;
    Xall = Xall(:, keep); names = cand(keep);

    % remove rows with NaN in y or any X
    ok = isfinite(y) & all(isfinite(Xall),2);
    y = y(ok); Xall = Xall(ok,:);

    if isempty(y) || isempty(Xall)
        names2 = strings(0,1); X2 = zeros(0,0); return;
    end

    % correlation ranking
    r = abs(corr(Xall, y));
    [~, order] = sort(r, 'descend');
    order = order(1:min(Kprune, numel(order)));
    names1 = names(order); X1 = Xall(:, order);

    % de-collinearity
    keepIdx = [];
    for i = 1:numel(order)
        idx = i;
        if isempty(keepIdx)
            keepIdx = idx;
        else
            cmax = max(abs(corr(X1(:, keepIdx), X1(:, idx))));
            if cmax < colThr
                keepIdx = [keepIdx idx]; %#ok<AGROW>
            end
        end
    end
    names2 = string(names1(keepIdx));
    names2 = names2(:);                % ensure column vector
    X2 = X1(:, keepIdx);
    fprintf('Candidate pool shrunk to %d features: %s\n', numel(names2), strjoin(names2.', ', '));
end

function rankTbl = rankCombos(X, y, names, chooseK, maxCombos)
    % Exhaustively evaluate all chooseK-combinations with 5-fold CV robust linear
    n = numel(names);
    if n < chooseK
        rankTbl = table(); return;
    end
    combos = nchoosek(1:n, chooseK);
    nC = size(combos,1);

    % Subsample combos if too many (optional safety)
    if nC > maxCombos
        idx = randperm(nC, maxCombos);
        combos = combos(idx, :);
        nC = size(combos,1);
        fprintf('Too many combos; randomly evaluating %d of %d.\n', nC, nchoosek(n, chooseK));
    end

    RMSE = nan(nC,1); MAE = nan(nC,1); MAPE = nan(nC,1); R2 = nan(nC,1);
    for i = 1:nC
        cols = combos(i,:);
        try
            [R2(i), RMSE(i), MAE(i), MAPE(i)] = cvMetrics(X(:, cols), y);
        catch ME
            warning('Combo %s failed (%s). Marked as Inf RMSE.', strjoin(names(cols).', '+'), ME.message);
            RMSE(i) = inf; MAE(i) = inf; MAPE(i) = inf; R2(i) = -inf;
        end
    end

    % build table (ensure all columns are nC×1)
    f1 = string(names(combos(:,1))); f1 = f1(:);
    f2 = string(names(combos(:,2))); f2 = f2(:);
    f3 = string(names(combos(:,3))); f3 = f3(:);
    if chooseK >= 4
        f4 = string(names(combos(:,4))); f4 = f4(:);
        rankTbl = table(f1, f2, f3, f4, RMSE, MAE, MAPE, R2, 'VariableNames', ...
            {'Feat1','Feat2','Feat3','Feat4','RMSE','MAE','MAPE_pct','R2'});
    else
        rankTbl = table(f1, f2, f3, RMSE, MAE, MAPE, R2, 'VariableNames', ...
            {'Feat1','Feat2','Feat3','RMSE','MAE','MAPE_pct','R2'});
    end
    rankTbl = sortrows(rankTbl, 'RMSE', 'ascend');
end

function [R2, RMSE, MAE, MAPE] = cvMetrics(X, y)
    % 5-fold CV with robust linear regression, z-score per fold to avoid leakage
    cv = cvpartition(numel(y), 'KFold', 5);
    yhat = nan(size(y));
    for k = 1:cv.NumTestSets
        tr = training(cv,k); te = test(cv,k);
        Xtr = X(tr,:); Xte = X(te,:);
        ytr = y(tr);

        % standardize using train stats
        mu = mean(Xtr,1); sd = std(Xtr,0,1); sd(sd==0) = 1;
        Xtr = (Xtr - mu) ./ sd;
        Xte = (Xte - mu) ./ sd;

        mdl = fitlm(Xtr, ytr, 'RobustOpts','on');
        yhat(te) = predict(mdl, Xte);
    end
    RMSE = sqrt(mean((yhat - y).^2));
    MAE  = mean(abs(yhat - y));
    MAPE = mean(abs(yhat - y) ./ max(abs(y), eps)) * 100;
    R2   = 1 - sum((yhat-y).^2) / sum((y-mean(y)).^2);
end