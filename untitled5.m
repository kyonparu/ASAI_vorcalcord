% 動画ファイル選択
[videoFilePath, videoFileDir] = uigetfile('*.avi', '解析する動画ファイルを選択してください');
if isequal(videoFilePath, 0)
    disp('動画の選択がキャンセルされました。');
    return;
end
video = VideoReader(fullfile(videoFileDir, videoFilePath));

% 動画フレームを読み込み
frames = {};
videoData = [];
while hasFrame(video)
    frame = readFrame(video); 
    if size(frame, 3) == 3
        frame = rgb2gray(frame); % グレースケール化
    end
    frames{end+1} = double(frame); %#ok<SAGROW>
    videoData = cat(3, videoData, double(frame)); % 配列としても格納
end
numFrames = size(videoData, 3);

% 最初のフレームでサンプル表示
sampleFrame = frames{1};
[dxSample, dySample] = gradient(sampleFrame);
slopeSample = sqrt(dxSample.^2 + dySample.^2);

% スライダーUI作成
fig = figure('Name', '急勾配領域調整', 'NumberTitle', 'off', 'Visible', 'on');
slider = uicontrol('Style', 'slider', ...
                   'Min', 0, 'Max', 2, 'Value', 0.5, ...
                   'Units', 'normalized', ...
                   'Position', [0.25, 0.02, 0.5, 0.03], ...
                   'SliderStep', [0.01, 0.1]);

% リアルタイム更新用サンプルプロット
subplot(1, 2, 1);
samplePlot = imagesc(sampleFrame);
title('Original Grayscale Frame');
xlabel('X (pixels)');
ylabel('Y (pixels)');
cb1 = colorbar;
cb1.Label.String = 'Pixel Intensity';

subplot(1, 2, 2);
maskPlot = imagesc(slopeSample >= slider.Value);
title('Steep Regions');
xlabel('X (pixels)');
ylabel('Y (pixels)');
cb2 = colorbar;
cb2.Label.String = 'Threshold Mask (True/False)';

% スライダーのコールバック設定
slider.Callback = @(src, ~) updateSampleVisualization(sampleFrame, slopeSample, maskPlot, src.Value);

% Enterキーで閾値を確定
disp('スライダーを調整してEnterキーで閾値を確定してください...');
waitfor(fig, 'CurrentCharacter', char(13));
slopeThreshold = slider.Value;
close(fig);
disp(['確定した閾値: ', num2str(slopeThreshold)]);

% 保存先のファイル名とパスを選択
[saveFileName, savePath] = uiputfile('*.avi', '解析結果を保存する場所とファイル名を選択してください');
if isequal(saveFileName, 0)
    disp('ファイル保存がキャンセルされました。');
    return;
end

% 解析結果保存の準備
disp('全フレームの解析を開始します...');
outputVideo = VideoWriter(fullfile(savePath, saveFileName), 'Uncompressed AVI');
open(outputVideo);
areaResults = zeros(numFrames, 1); % 勾配領域の面積結果
[h, w] = size(sampleFrame);
maxAmplitudes = zeros(h, w); % 最大振幅成分

% 各ピクセルの時系列データの解析
for i = 1:h
    for j = 1:w
        % 各ピクセル位置の時系列データ抽出
        pixelSequence = squeeze(videoData(i, j, :));

        % --- 平均値の差し引き（DC成分除去） ---
        pixelSequence = pixelSequence - mean(pixelSequence);

        % --- ハミング窓の適用 ---
        windowedSequence = pixelSequence .* hamming(numFrames);

        % --- フーリエ変換と最大振幅計算 ---
        spectrum = fft(windowedSequence);
        amplitudeSpectrum = abs(spectrum(1:floor(numFrames / 2))); % 振幅スペクトル
        maxAmplitudes(i, j) = max(amplitudeSpectrum); % 最大振幅成分を保存
    end
end

% 各フレームの解析（急勾配領域解析とマスク）
figHandle = figure(1); % figureオブジェクトを取得して使う
for frameIdx = 1:numFrames
    grayFrame = frames{frameIdx};
    [dx, dy] = gradient(grayFrame);
    slope = sqrt(dx.^2 + dy.^2);

    % 急勾配領域をマスク
    mask = slope >= slopeThreshold;

    % 面積計算
    areaResults(frameIdx) = sum(mask(:));

    % サブプロット描画
    clf(figHandle); % figureの内容をクリア
    subplot(2, 2, 1);
    invertedFrame = 255 - grayFrame; % ピクセル値を反転
    imagesc(invertedFrame); % 反転した画像を表示
    colormap(gca, 'gray'); % グレースケールカラーマップを使用
    caxis([0, 255]); % グレースケールのピクセル範囲に合わせる
    title('Inverted Grayscale Frame');
    xlabel('X (pixels)');
    ylabel('Y (pixels)');
    cb1 = colorbar;
    cb1.Label.String = 'Pixel Intensity';

    subplot(2, 2, 2);
    imagesc(slope);
    colormap(gca, 'jet'); % カラーマップを変更
    caxis([0, max(slope(:))]); % 勾配の最大値をカラーバーの範囲に設定
    title('Slope Magnitude');
    xlabel('X (pixels)');
    ylabel('Y (pixels)');
    cb2 = colorbar;
    cb2.Label.String = 'Gradient Magnitude';

    subplot(2, 2, 3);
    imagesc(mask);
    colormap(gca, 'jet'); % カラーマップを変更
    caxis([0, 1]); % マスクのTrue/False範囲に合わせる
    title(['Steep Regions (Threshold: ', num2str(slopeThreshold, '%.1f'), ')']);
    xlabel('X (pixels)');
    ylabel('Y (pixels)');
    cb3 = colorbar;
    cb3.Label.String = 'Threshold Mask (True/False)';

    % フレームを動画として追加
    frameCaptured = getframe(figHandle); % 明示的にfigHandleを指定
    writeVideo(outputVideo, frameCaptured.cdata); % 動画にフレームを追加
end
close(outputVideo);

% --- 最大振幅成分のヒストグラムを表示 ---
figure;
histogram(maxAmplitudes(:), 'BinWidth', 1);
title('最大振幅成分のヒストグラム');
xlabel('振幅');
ylabel('頻度');

% --- 最大振幅成分の空間分布を表示 ---
figure;
imagesc(maxAmplitudes);
title('最大振幅成分の空間分布');
xlabel('X (pixels)');
ylabel('Y (pixels)');
colorbar;
cb = colorbar;
cb.Label.String = '最大振幅成分';

disp('解析が完了しました。');
disp(['保存した動画: ', fullfile(savePath, saveFileName)]);

% --- ローカル関数 ---
function grayFrame = preprocessFrame(frame)
    if size(frame, 3) == 3
        grayFrame = double(im2gray(frame));
    else
        grayFrame = double(frame);
    end
end

function updateSampleVisualization(frame, slope, plotHandle, threshold)
    mask = slope >= threshold;
    set(plotHandle, 'CData', mask);
    title(['Steep Regions (Threshold: ', num2str(threshold, '%.2f'), ')']);
    drawnow;
end
