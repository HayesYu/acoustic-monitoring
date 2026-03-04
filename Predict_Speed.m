featV = ["PeakAmp","Bandwidth_Hz","SpectralEntropy"];
toPredV = T(isnan(T.Speed), :);     % 例如 B10、C14
yPredV = mdlSpeed.predictFcn(toPredV);
predV = table(toPredV.Signal, yPredV, 'VariableNames', {'Signal','PredSpeed'});
writetable(predV, 'pred_speed.csv');

T.Speed_pred = T.Speed;
idx = isnan(T.Speed);
T.Speed_pred(idx) = yPredV;
save merged_features_with_preds.mat T
writetable(T, 'merged_features_with_preds.csv');