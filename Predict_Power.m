% 如果还没加载合并表：
load merged_features.mat  % 得到表 T（含 Signal、特征列、Power/Speed）

% 选择与你训练时一致的3个特征名（与App里相同）
featP = ["Duration_s","PeakToPeak","ZeroCrossRate_Hz"];

% 取出未知Power的行
toPredP = T(isnan(T.Power), :);   % 例如 B10、C9、C13、C14

% 使用App导出的模型（导出时给的变量名，这里假设是 mdlPower）
% 如果你导出的是 .mat 文件，先 load；如果导出到工作区已存在就直接用
% load('mdlPower.mat')  % 如你选择保存为文件的话
yPredP = mdlPower.predictFcn(toPredP);   % 传入包含相同列名的table

predP = table(toPredP.Signal, yPredP, 'VariableNames', {'Signal','PredPower'});
writetable(predP, 'pred_power.csv');

% 把预测写回T并保存
T.Power_pred = T.Power; 
idx = isnan(T.Power);
T.Power_pred(idx) = yPredP;
save merged_features_with_preds.mat T
writetable(T, 'merged_features_with_preds.csv');