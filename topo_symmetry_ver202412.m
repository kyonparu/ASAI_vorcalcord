% トポグラフィ解析プログラム（統合版: LとRの範囲を常に一致させる）
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

% A: 一番暗いフレームを選択
[~, darkestFrameIdx] = min(sum(rawIntensity, [1, 2]));
darkestFrame = read(vid, darkestFrameIdx);
if size(darkestFrame, 3) == 3
    darkestFrameGray = rgb2gray(darkestFrame); % グレースケール変換
else
    darkestFrameGray = darkestFrame;
end

% 最大振幅成分の位相分布を計算（基準フレームに戻す）
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

%% 対称線をインタラクティブに指定
figure;
imagesc(maxAmplitude); axis image; colorbar;
title('Click to select symmetry line (X-coordinate)');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
[xClick, ~] = ginput(1); % ユーザーにクリックさせる
centerX = round(xClick);

% 入力チェック
if centerX < 1 || centerX > frameWidth
    error('指定されたX座標が範囲外です。');
end

% 左右の領域の長さを決定
if centerX <= frameWidth / 2
    % 左側が長い場合
    L_start = 1;
    L_end = centerX;
    R_start = centerX + 1;
    R_end = centerX + (L_end - L_start);
else
    % 右側が長い場合
    R_end = frameWidth;
    R_start = centerX + 1;
    L_end = centerX;
    L_start = centerX - (R_end - R_start);
end

% 共通サイズに揃える
commonWidth = min(L_end - L_start + 1, R_end - R_start + 1);
L_end = L_start + commonWidth - 1;
R_end = R_start + commonWidth - 1;

% 領域チェック
if L_start < 1 || R_end > frameWidth
    error('指定されたX座標に基づく左右の領域が画像の範囲を超えています。');
end

%% 対称性解析
% 振幅の左右対称性
ampDiffLR = abs(maxAmplitude(:, L_start:L_end) - fliplr(maxAmplitude(:, R_start:R_end)));

% 位相の左右対称性
phaseDiffLR = abs(maxPhase(:, L_start:L_end) - fliplr(maxPhase(:, R_start:R_end)));

% 周波数の左右対称性
freqDiffLR = abs(maxFrequency(:, L_start:L_end) - fliplr(maxFrequency(:, R_start:R_end)));

%% 全体解析結果の表示
fullFig = figure;

% 振幅の全体分布
subplot(3, 2, 1);
imagesc(maxAmplitude); axis image; colorbar;
title('Amplitude Distribution');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% 位相の全体分布
subplot(3, 2, 3);
imagesc(maxPhase, [0, 2*pi]); axis image; colorbar;
title('Phase Distribution');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
colorbar('Ticks', [0, pi, 2*pi], 'TickLabels', {'0', '\pi', '2\pi'}); % カラーバーを0〜2πに設定

% 周波数の全体分布
subplot(3, 2, 5);
imagesc(maxFrequency, [0, max(maxFrequency(:))]); axis image; colorbar;
title('Frequency Distribution');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% 対称性解析結果の表示
symFig = figure;

% 振幅の全体分布
subplot(2, 3, 1);
imagesc(maxAmplitude); axis image; colorbar;
hold on; plot([centerX, centerX], ylim, 'r--', 'LineWidth', 1.5);
title('Amplitude Distribution with Symmetry Line');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% 位相の全体分布
subplot(2, 3, 2);
imagesc(maxPhase, [0, 2*pi]); axis image; colorbar;
hold on; plot([centerX, centerX], ylim, 'r--', 'LineWidth', 1.5);
title('Phase Distribution with Symmetry Line');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
colorbar('Ticks', [0, pi, 2*pi], 'TickLabels', {'0', '\pi', '2\pi'}); % カラーバーを0〜2πに設定

% 周波数の全体分布
subplot(2, 3, 3);
imagesc(maxFrequency, [0, max(maxFrequency(:))]); axis image; colorbar;
hold on; plot([centerX, centerX], ylim, 'r--', 'LineWidth', 1.5);
title('Frequency Distribution with Symmetry Line');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% 下段: 対称性解析
subplot(2, 3, 4);
imagesc(ampDiffLR); axis image; colorbar;
title('Amplitude Symmetry (L-R)');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

subplot(2, 3, 5);
imagesc(phaseDiffLR, [0, 2*pi]); axis image; colorbar;
title('Phase Symmetry (L-R)');
xlabel('Pixels (x)'); ylabel('Pixels (y)');
colorbar('Ticks', [0, pi, 2*pi], 'TickLabels', {'0', '\pi', '2\pi'}); % カラーバーを0〜2πに設定

subplot(2, 3, 6);
imagesc(freqDiffLR, [0, max(freqDiffLR(:))]); axis image; colorbar;
title('Frequency Symmetry (L-R)');
xlabel('Pixels (x)'); ylabel('Pixels (y)');

% 図のサイズを自動的に調整する（サブプロットの間隔を調整）
set(gcf, 'Position', [100, 100, 1200, 900]);  % ウィンドウのサイズを調整

% 保存ダイアログを最前面に表示
figure(symFig);  % 保存ダイアログを表示する前に最前面に移動

% 図の保存
[saveFileName, savePath] = uiputfile('*.png', '保存先を選択してください');
if isequal(saveFileName, 0)
    disp('保存がキャンセルされました。');
else
    saveas(symFig, fullfile(savePath, ['Symmetry_' saveFileName]));
    disp(['対称性解析結果が保存されました: ', fullfile(savePath, ['Symmetry_' saveFileName])]);
end
