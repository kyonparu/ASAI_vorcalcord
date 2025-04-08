% トポグラフィ解析プログラム（修正版: 位相分布の範囲を明示、CとDの位置を交換）
clear; clc; close all;

%% 1. AVIファイルを参照で開く
[filename, filepath] = uigetfile('*.avi', 'AVIファイルを選択してください');
if isequal(filename, 0)
    disp('ファイルが選択されませんでした。');
    return;
end
aviPath = fullfile(filepath, filename);

% 動画の読み込み
vid = VideoReader(aviPath);
numFrames = vid.NumFrames;
frameHeight = vid.Height;
frameWidth = vid.Width;
frameRate = 2000 / 0.5; % 2000フレームで0.5秒の動画から計算

%% 解析設定
windowSize = 2000;
rawIntensity = zeros(frameHeight, frameWidth, numFrames, 'single');

% 動画全体をグレースケールで読み込む
for k = 1:numFrames
    frame = read(vid, k);
    if size(frame, 3) == 3
        rawIntensity(:, :, k) = single(rgb2gray(frame));
    else
        rawIntensity(:, :, k) = single(frame);
    end
end

%% 平均輝度レベルを差し引く正規化
avgIntensity = movmean(rawIntensity, windowSize, 3);
normalizedIntensity = rawIntensity - avgIntensity;

%% ハミング窓の適用
hammingWindow = hamming(numFrames, 'periodic');
hammingWindow3D = reshape(hammingWindow, [1, 1, numFrames]);
windowedIntensity = normalizedIntensity .* hammingWindow3D;

%% 離散フーリエ変換
fftResult = fft(windowedIntensity, [], 3);
amplitude = abs(fftResult);
phase = angle(fftResult);
frequency = (0:numFrames-1) * (frameRate / numFrames);

% 最大振幅成分を抽出（基本周波数のみを考慮）
[~, maxIdx] = max(amplitude(:, :, 2:end), [], 3); % 基本周波数はDC成分を除いた2:end
maxAmplitude = max(amplitude(:, :, 2:end), [], 3);
maxFrequency = frequency(maxIdx + 1); % インデックスを補正

% 最大振幅成分の位相分布を計算
maxPhase = zeros(size(phase, 1), size(phase, 2)); % 初期化
for i = 1:size(phase, 1)
    for j = 1:size(phase, 2)
        maxPhase(i, j) = phase(i, j, maxIdx(i, j) + 1);
    end
end

% 位相を0～2πに正規化
maxPhase = mod(maxPhase, 2 * pi);

% NaN/Inf処理（必要であれば）
maxPhase(isnan(maxPhase) | isinf(maxPhase)) = 0;

%% A: 一番暗いフレームを選択
[~, darkestFrameIdx] = min(sum(rawIntensity, [1, 2]));
darkestFrame = read(vid, darkestFrameIdx);
if size(darkestFrame, 3) == 3
    darkestFrameGray = rgb2gray(darkestFrame); % グレースケール変換
else
    darkestFrameGray = darkestFrame;
end

%% 図の生成
hFig = figure;

% A: 元動画の静的画像（最も暗いフレームを表示）
subplot(2, 3, 1);
imagesc(darkestFrameGray); axis image; colorbar;
colormap(gca, gray); % グレースケールのカラーマップを適用
title('A: 元動画の静的画像');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% B: 最大振幅成分の振幅分布
subplot(2, 3, 2);
imagesc(maxAmplitude); axis image; colorbar;
colormap(gca, jet);
title('B: 最大振幅成分の振幅分布');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
c = colorbar;
c.Label.String = 'Amplitude';

% C: 最大振幅成分の位相分布
subplot(2, 3, 3);
if ~ismatrix(maxPhase)
    disp('警告: maxPhaseが適切な2Dデータではありません。プロットをスキップします。');
else
    imagesc(maxPhase, [0, 2*pi]); % カラースケールを0～2πに固定
    axis image; colorbar;
    colormap(gca, hsv);
    c = colorbar;
    c.Ticks = [0, pi, 2*pi];
    c.TickLabels = {'0', '\pi', '2\pi'}; % ラベルを設定
    c.Label.String = 'Phase (radians)';
    title('C: 最大振幅成分の位相分布');
    xlabel('Pixels (x)'); ylabel('Pixels (y)');
end

% D: 最大振幅の周波数の空間分布
subplot(2, 3, 4);
imagesc(maxFrequency); axis image; colorbar;
colormap(gca, jet);
title('D: 最大振幅の周波数の空間分布');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
c = colorbar;
c.Label.String = 'Frequency (Hz)';

% E: 周波数のヒストグラム
subplot(2, 3, [5, 6]);
validFreq = maxFrequency(maxFrequency > 0); % 有効な周波数（ゼロ周波数除外）
histogram(validFreq(:), 'Normalization', 'probability'); % ヒストグラム作成
xlabel('Frequency (Hz)'); ylabel('Probability');
title('E: 最大振幅成分の周波数ヒストグラム');

% 全体のレイアウト調整
sgtitle('トポグラフィ解析結果');

%% 図の保存
% ファイル保存用ダイアログを開く
[saveFileName, savePath] = uiputfile('*.png', '保存先を選択してください');
if isequal(saveFileName, 0)
    disp('保存がキャンセルされました。');
else
    saveas(hFig, fullfile(savePath, saveFileName));
    disp(['図が保存されました: ', fullfile(savePath, saveFileName)]);
end
