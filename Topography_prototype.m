% 動画ファイルのパスをファイルダイアログから選択
[fileName, filePath] = uigetfile('*.avi', '解析する動画ファイルを選択してください');
if fileName == 0
    disp('動画の選択がキャンセルされました。');
    return;
end
videoFilePath = fullfile(filePath, fileName); % 完全なファイルパスを作成

% 保存するかどうかを尋ねる
saveVideo = input('解析結果を動画として保存しますか？ (y/n): ', 's');
if lower(saveVideo) == 'y'
    % 保存先のファイル名をファイルダイアログで指定
    [outputFileName, outputFilePath] = uiputfile('*.avi', '動画ファイルの保存場所と名前を指定');
    if outputFileName == 0
        disp('動画の保存がキャンセルされました。');
        return;
    end
    outputPath = fullfile(outputFilePath, outputFileName); % 完全な保存パスを作成
    % VideoWriterオブジェクトを作成し、フレームレートを設定
    outputVideo = VideoWriter(outputPath, 'Uncompressed AVI');
    outputVideo.FrameRate = 30; % 任意のフレームレートを設定（元のビデオと合わせても良い）
    open(outputVideo); % 出力ファイルを開く
else
    outputPath = ''; % 保存しない場合は空のパス
end

% VideoReaderオブジェクトの作成
video = VideoReader(videoFilePath);

% 出力フレームのサイズを指定
outputWidth = 1120; % 必要な出力幅
outputHeight = 840; % 必要な出力高さ

% フレームごとに解析し、結果を保存
figure;

while hasFrame(video)
    % フレームを読み込む
    frame = readFrame(video);
    
    % グレースケールのままフレームをdoubleに変換
    grayFrame = double(frame);
    
    % 勾配（x方向とy方向）
    [dx, dy] = gradient(grayFrame);
    
    % 傾斜（勾配の大きさ）
    slope = sqrt(dx.^2 + dy.^2);
    
    % 方位角（アスペクト）
    aspect = atan2(dy, dx);
    
    % サブプロットを用いて解析結果を表示
    subplot(2, 2, 1);
    imshow(frame, []);
    title('Original Grayscale Frame');
    
    subplot(2, 2, 2);
    imagesc(slope);
    colorbar;
    title('Slope (Gradient Magnitude)');
    
    subplot(2, 2, 3);
    imagesc(aspect);
    colorbar;
    title('Aspect (Direction of Slope)');
    
    subplot(2, 2, 4);
    % 等高線を描画（レベルの順番を反転させる）
    minVal = min(grayFrame(:));
    maxVal = max(grayFrame(:));
    
    % 等高線のレベルを逆に設定（例えばminValからmaxValへ）
    levels = linspace(maxVal, minVal, 10); % 逆順にレベルを設定
    
    [C, h] = contour(grayFrame, levels, 'ShowText', 'on');
    % ラベルをカスタムフォーマットで設定
    clabel(C, h, 'FontSize', 8, 'LabelSpacing', 300); 
    labels = h.TextPrims; % ラベルのオブジェクトを取得
    for k = 1:numel(labels)
        labels(k).String = sprintf('%.1f', str2double(labels(k).String)); % 小数点第一位にフォーマット
    end
    title('Contour Lines');
    
    % 等高線のy軸方向を反転（上が小さい数値になるように設定）
    set(gca, 'YDir', 'reverse');
    
    % 表示更新
    drawnow;
    
    % Figureをフレームとしてキャプチャ
    frameCaptured = getframe(gcf);  % フレームをキャプチャ
    
    % キャプチャしたフレームのサイズをリサイズ
    resizedFrame = imresize(frameCaptured.cdata, [outputHeight, outputWidth]);
    
    % 動画保存が選ばれた場合
    if ~isempty(outputPath)
        % リサイズしたフレームを動画に書き込む
        writeVideo(outputVideo, resizedFrame); % フレームを書き込み
    end
end

% 動画ファイルを閉じる
if ~isempty(outputPath)
    close(outputVideo);
    disp(['解析結果を動画として保存しました: ', outputPath]);
else
    disp('解析結果は動画として保存されませんでした。');
end

