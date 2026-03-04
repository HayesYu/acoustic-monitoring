% Feature extraction for SingleTrack_Division.mat (A1..A13, B1..B13, C1..C14)
% Outputs: features.mat (table) and features.csv
% If your sampling rate is not 128 kHz, change fs below.

%% Settings
matFile   = "SingleTrack_Division.mat";
fs        = 128000;                % Hz
nyq       = fs/2;

% Select variables by regex: A1..A13, B1..B13, C1..C14
varRegex  = '^[ABC]\d+$';

% Fixed frequency bands (Hz) for band-energy features
bandEdges = [0 5e3; 5e3 10e3; 10e3 20e3; 20e3 40e3; 40e3 nyq];

% Consistent filtering across all segments (adjust as needed)
doHighpass = true;  hpCut = 800;    % remove very-low-frequency rumble
doBandpass = false; bpLo   = 1e3;   bpHi = 40e3;

% Optional: auto-trim to active region by amplitude threshold
doAutoTrim   = true;
trimThresh   = 0.10;   % keep samples where |x| > 10% of max(abs(x))
trimPad_s    = 0.002;  % seconds of padding on both sides

% Optional: quick plotting of first few processed signals
debugPlotFirstN = 0;   % set >0 to preview

%% Design filters (if enabled)
if doHighpass
    [b_hp, a_hp] = butter(6, hpCut/nyq, 'high');
end
if doBandpass
    [b_bp, a_bp] = butter(4, [bpLo bpHi]/nyq, 'bandpass');
end

%% Discover variables in MAT-file
info = whos('-file', matFile);
vars = string({info.name});
isCol = arrayfun(@(k) info(k).size(2)==1, 1:numel(info));
vars = vars(isCol & ~cellfun(@isempty, regexp(vars, varRegex, 'once')));
vars = sort(vars);

if isempty(vars)
    error("No variables matching %s found in %s", varRegex, matFile);
end
fprintf("Found %d signals:\n%s\n", numel(vars), strjoin(vars, ", "));

%% Extract features
feat = [];
for k = 1:numel(vars)
    S = load(matFile, vars(k));
    x = S.(vars(k));
    x = x(:);

    % Detrend (remove DC), then consistent filtering
    x = detrend(x, 0);
    if doHighpass, x = filtfilt(b_hp, a_hp, x); end
    if doBandpass, x = filtfilt(b_bp, a_bp, x); end

    % Auto-trim to active region
    if doAutoTrim
        thr = trimThresh * max(abs(x)+eps);
        idx = find(abs(x) >= thr);
        if ~isempty(idx)
            pad = round(trimPad_s * fs);
            i1 = max(1, idx(1) - pad);
            i2 = min(numel(x), idx(end) + pad);
            x  = x(i1:i2);
        end
    end

    % Optional debug plot
    if debugPlotFirstN > 0 && k <= debugPlotFirstN
        figure('Name', "Processed "+vars(k)); subplot(2,1,1)
        plot(S.(vars(k))); title(vars(k)+" - original")
        subplot(2,1,2); plot(x); title(vars(k)+" - processed")
        drawnow
    end

    % Compute features
    f = computeFeaturesLPBF(x, fs, bandEdges);
    f.Signal = vars(k);
    feat = [feat; f]; %#ok<AGROW>
end

%% Save table
featuresTbl = struct2table(feat);
featuresTbl = movevars(featuresTbl, "Signal", "Before", 1);
disp(head(featuresTbl))
save features.mat featuresTbl
writetable(featuresTbl, "features.csv");
fprintf("Saved %d rows to features.mat and features.csv\n", height(featuresTbl));

%% ---- Helper function ----
function f = computeFeaturesLPBF(x, fs, bandEdges)
% Time-domain features
x  = x - mean(x);
N  = numel(x);
dur = N / fs;
rmsv = rms(x);
pp   = peak2peak(x);
crest = max(abs(x)) / max(rmsv, eps);
sk = skewness(x);
ku = kurtosis(x);
zcr = sum(abs(diff(sign(x))))/(2*N)*fs;

% One-sided FFT
Y  = fft(x);
P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);
faxis = fs*(0:floor(N/2))/N;

% Spectral features
[pkAmp, idx] = max(P1);
mainFreq     = faxis(idx);
w = P1 + 1e-12;
centroid  = sum(faxis(:).*w(:))/sum(w);
bandwidth = sqrt( sum(((faxis(:)-centroid).^2).*w(:))/sum(w) );
totalEnergy = sum(P1.^2);
p = P1 / sum(P1 + 1e-12);
specEntropy = -sum(p .* log(p + 1e-12));

% Band energies
bandE = zeros(size(bandEdges,1),1);
for b = 1:size(bandEdges,1)
    mask = faxis >= bandEdges(b,1) & faxis < bandEdges(b,2);
    bandE(b) = sum(P1(mask).^2);
end
lowBand  = bandE(1);
highBand = bandE(end);
hi2lo    = highBand / max(lowBand, 1e-12);

% Assemble
f = struct();
f.Duration_s            = dur;
f.RMS                   = rmsv;
f.PeakToPeak            = pp;
f.Crest                 = crest;
f.Skewness              = sk;
f.Kurtosis              = ku;
f.ZeroCrossRate_Hz      = zcr;
f.MainFreq_Hz           = mainFreq;
f.PeakAmp               = pkAmp;
f.SpectralCentroid_Hz   = centroid;
f.Bandwidth_Hz          = bandwidth;
f.TotalEnergy           = totalEnergy;
f.SpectralEntropy       = specEntropy;
for b = 1:size(bandEdges,1)
    nm = sprintf("BandE_%dk_%dk", round(bandEdges(b,1)/1e3), round(bandEdges(b,2)/1e3));
    f.(nm) = bandE(b);
end
f.HighLowBandRatio      = hi2lo;
end