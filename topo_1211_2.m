% トポグラフィ解析プログラム（条件: フレーム数2000, 動画長0.5秒）
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
numFrames = vid.NumFrames;    % フレーム数
frameHeight = vid.Height;     % フレームの高さ
frameWidth = vid.Width;       % フレームの幅
frameRate = 2000 / 0.5;       % フレームレート（仮定: 2000フレーム / 0.5秒）

%% 解析設定
windowSize = 2000; % 移動平均ウィンドウサイズ
rawIntensity = zeros(frameHeight, frameWidth, numFrames, 'single');

% 動画全体をグレースケールで読み込む
for k = 1:numFrames
    frame = read(vid, k);
    if size(frame, 3) == 3
        rawIntensity(:, :, k) = single(rgb2gray(frame)); % グレースケール変換
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

% 最大振幅成分を抽出
[~, maxIdx] = max(amplitude(:, :, 2:end), [], 3); % 直流成分を除外（index: 2:end）
maxAmplitude = max(amplitude(:, :, 2:end), [], 3);
maxFrequency = frequency(maxIdx + 1);

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

%% 図の生成
hFig = figure;

% A: 元動画の静的画像（グレースケール）
subplot(2, 3, 1);
firstFrame = read(vid, 1);
if size(firstFrame, 3) == 3
    firstFrameGray = rgb2gray(firstFrame); % グレースケール変換
else
    firstFrameGray = firstFrame;
end
imagesc(firstFrameGray); axis image; colorbar;
colormap(gca, gray); % グレースケールのカラーマップを適用
title('A: 元動画の静的画像');

% B: 最大振幅成分の振幅分布
subplot(2, 3, 2);
imagesc(maxAmplitude); axis image; colorbar;
colormap(jet);
title('B: 最大振幅成分の振幅分布');

% C: 最大振幅の周波数の空間分布
subplot(2, 3, 3);
imagesc(maxFrequency); axis image; colorbar;
colormap(jet);
title('C: 最大振幅の周波数の空間分布');

% D: 最大振幅成分の位相分布
subplot(2, 3, 4);
if ~ismatrix(maxPhase)
    disp('警告: maxPhaseが適切な2Dデータではありません。プロットをスキップします。');
else
    imagesc(maxPhase); axis image; colorbar;
    colormap(hsv);
    title('D: 最大振幅成分の位相分布');
end

% E: 最大振幅成分の周波数ヒストグラム
subplot(2, 3, [5, 6]);
validFrequency = maxFrequency(maxFrequency > 0); % 0 Hz を除外
histogram(validFrequency, 'Normalization', 'probability');
xlabel('周波数 (Hz)'); ylabel('確率');
title('E: 最大振幅成分の周波数ヒストグラム');

% 全体のレイアウト調整
sgtitle('トポグラフィ解析結果');

%% 図の保存
[saveFileName, savePath] = uiputfile('*.png', '保存先を選択してください');
if isequal(saveFileName, 0)
    disp('保存がキャンセルされました。');
else
    saveas(hFig, fullfile(savePath, saveFileName));
    disp(['図が保存されました: ', fullfile(savePath, saveFileName)]);
end
