% トポグラフィ解析プログラム（修正版：最も黒いフレームを選択 + 正しい周波数設定）
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
numFrames = 2000; % フレーム数は2000に固定
frameHeight = vid.Height;
frameWidth = vid.Width;

% 実際のフレームレート設定（2000フレーム、0.5秒の動画）
frameRate = 4000; % フレーム/秒（2000フレーム / 0.5秒）

%% 最も黒いフレームを選択
minSum = Inf;  % 輝度の合計値の最小値を初期化
darkFrameIdx = 1;  % 最も黒いフレームのインデックスを初期化

% 動画全体を走査して、最も黒いフレームを探す
for k = 1:numFrames
    frame = read(vid, k);
    if size(frame, 3) == 3
        frameGray = rgb2gray(frame);  % グレースケール変換
    else
        frameGray = frame;
    end
    
    % フレームの輝度の合計を計算
    frameSum = sum(frameGray(:));
    
    % 輝度の合計が最小の場合、そのフレームを選択
    if frameSum < minSum
        minSum = frameSum;
        darkFrameIdx = k;  % 最も黒いフレームのインデックスを更新
    end
end

% 最も黒いフレームを取得
darkFrame = read(vid, darkFrameIdx);
if size(darkFrame, 3) == 3
    darkFrameGray = rgb2gray(darkFrame);  % グレースケール変換
else
    darkFrameGray = darkFrame;
end

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
frequency = (0:numFrames-1) * (frameRate / numFrames); % 周波数の設定

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
colormap(gca, jet);
title('B: 最大振幅成分の振幅分布');

% C: 最大振幅の周波数の空間分布
subplot(2, 3, 3);
imagesc(maxFrequency); axis image; colorbar;
colormap(gca, jet);
title('C: 最大振幅の周波数の空間分布');

% D: 最大振幅成分の位相分布
subplot(2, 3, 4);
if ~ismatrix(maxPhase)
    disp('警告: maxPhaseが適切な2Dデータではありません。プロットをスキップします。');
else
    imagesc(maxPhase); axis image; colorbar;
    colormap(gca, hsv);
    title('D: 最大振幅成分の位相分布');
end

% E: 周波数のヒストグラム
subplot(2, 3, [5, 6]);
validFreq = maxFrequency(maxFrequency > 0); % 有効な周波数（ゼロ周波数除外）
histogram(validFreq(:), 'Normalization', 'probability'); % ヒストグラム作成
xlabel('周波数 (Hz)'); ylabel('確率');
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
