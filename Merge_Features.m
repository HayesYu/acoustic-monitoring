% 如果工作区没有 featuresTbl，就先加载
if ~exist('featuresTbl','var')
    load features.mat  % 会加载出 featuresTbl
end

% 读取 params.csv，并把空白/??? 当作缺失
opts = detectImportOptions('params.csv');
opts = setvaropts(opts, {'Power','Speed'}, 'TreatAsMissing', {'','???'});
opts = setvartype(opts, {'Power','Speed'}, 'double');
P = readtable('params.csv', opts);

% 规范 Signal 列类型与空格
featuresTbl.Signal = string(strtrim(string(featuresTbl.Signal)));
P.Signal = string(strtrim(string(P.Signal)));

% 左连接：以 featuresTbl 为主表，补齐 Power/Speed（未知会是 NaN）
T = outerjoin(featuresTbl, P, 'Keys','Signal', 'MergeKeys', true, 'Type','left');

% 预览与保存
disp(head(T))
save merged_features.mat T
writetable(T, 'merged_features.csv');

% 可选：检查未匹配/未标注的样本与多余标签
unmatched_in_params = setdiff(P.Signal, T.Signal);                 % params 有但特征没有
unlabeled_in_features = T.Signal(isnan(T.Power) | isnan(T.Speed)); % 特征有但无标签（待预测）
if ~isempty(unmatched_in_params)
    warning('这些Signal只在params.csv中出现，特征表中没有： %s', strjoin(unmatched_in_params', ', '));
end
if ~isempty(unlabeled_in_features)
    fprintf('待预测样本（Power或Speed缺失）： %s\n', strjoin(string(unique(unlabeled_in_features))', ', '));
end