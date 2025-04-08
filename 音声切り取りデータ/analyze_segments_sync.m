function analyze_segments_with_video_sync()
    % ファイル選択ダイアログを表示
    [file, path] = uigetfile({'*.wav;*.flac', 'Audio Files (*.wav, *.flac)'; '*.*', 'All Files (*.*)'}, ...
                             '音声ファイルを選択');
    if isequal(file, 0)
        disp('ファイルが選択されませんでした。処理を終了します。');
        return;
    end
    filename = fullfile(path, file); % フルパスを作成

    % 音声データの読み込み
    [audio, fs] = audioread(filename);
    audio = audio / max(abs(audio));  % 正規化

    % パラメータ設定
    frame_size = 0.03; % フレームサイズ（30ms）
    hop_size = 0.005;  % ホップサイズ（5ms）
    frame_len = round(frame_size * fs);
    hop_len = round(hop_size * fs);
    energy_threshold = 0.01; % 無音判定用のエネルギーしきい値
    window_duration = 1; % 定常区間の長さ（1秒）
    window_frames = floor(window_duration / hop_size); % 1秒分のフレーム数
    frame_rate_video = 4000; % 映像のフレームレート（4000fps）

    % フレーム分割とエネルギー計算
    num_frames = floor((length(audio) - frame_len) / hop_len) + 1;
    energy = zeros(1, num_frames);
    for i = 1:num_frames
        idx_start = (i-1) * hop_len + 1;
        idx_end = idx_start + frame_len - 1;
        frame = audio(idx_start:idx_end);
        energy(i) = sum(frame.^2); % エネルギー計算
    end

    % 無音区間の検出
    is_voiced = energy > energy_threshold; % 発声フラグ
    segments = bwlabel(is_voiced); % セグメント分割 (連続した発声を1つの塊とする)
    num_segments = max(segments); % セグメント数

    % 各セグメントの情報を格納する変数
    Segment = []; StartFrame = []; EndFrame = [];
    SteadyStartFrame = []; SteadyEndFrame = [];
    VideoStartFrame = []; VideoEndFrame = [];
    SteadyVideoStart = []; SteadyVideoEnd = [];
    SteadyStartTime = []; SteadyEndTime = []; % 定常部分の時間

    % セグメントごとのエネルギーを保存
    segment_energies = {};
    segment_relative_times = {};

    % 各セグメントの分析
    for seg = 1:num_segments
        segment_frames = find(segments == seg); % セグメント内のフレーム番号
        if length(segment_frames) < window_frames
            continue; % セグメントが1秒より短い場合はスキップ
        end

        % セグメントの相対フレーム番号 (開始フレームを0にリセット)
        relative_frames = segment_frames - segment_frames(1);
        segment_energy = energy(segment_frames);
        segment_relative_time = relative_frames * hop_size; % 相対時間

        % 定常部分の特定
        best_score = -Inf;
        best_start = 0;

        % 定常部分を測定する際、最初と最後の100フレームを除外
        valid_frames = relative_frames(101:end-100); % 最初と最後の100フレームを除外
        valid_energy = segment_energy(101:end-100);

        for i = 1:(length(valid_frames) - window_frames + 1)
            % 1秒間のエネルギーの安定性評価
            window_energy = valid_energy(i:i+window_frames-1);
            score = -std(window_energy); % 標準偏差が小さいほどスコアが高い
            if score > best_score
                best_score = score;
                best_start = i;
            end
        end

        % 定常部分の結果
        best_start_frame = valid_frames(best_start);
        best_end_frame = best_start_frame + window_frames - 1;

        % 映像フレームの計算
        steady_video_start_frame = round(best_start_frame * frame_rate_video * hop_size);
        steady_video_end_frame = round(best_end_frame * frame_rate_video * hop_size);

        % セグメント情報を追加
        Segment = [Segment; seg];
        StartFrame = [StartFrame; 0]; % 相対フレーム
        EndFrame = [EndFrame; relative_frames(end)];
        SteadyStartFrame = [SteadyStartFrame; best_start_frame];
        SteadyEndFrame = [SteadyEndFrame; best_end_frame];
        VideoStartFrame = [VideoStartFrame; 0];
        VideoEndFrame = [VideoEndFrame; round(relative_frames(end) * frame_rate_video * hop_size)];
        SteadyVideoStart = [SteadyVideoStart; steady_video_start_frame];
        SteadyVideoEnd = [SteadyVideoEnd; steady_video_end_frame];

        % 定常部分の開始・終了時間を追加
        SteadyStartTime = [SteadyStartTime; best_start_frame * hop_size];
        SteadyEndTime = [SteadyEndTime; best_end_frame * hop_size];

        % セグメントごとのエネルギーを保存
        segment_energies{seg} = segment_energy;
        segment_relative_times{seg} = segment_relative_time;
    end

    % テーブルを作成
    segment_table = table(Segment, StartFrame, EndFrame, ...
                          SteadyStartTime, SteadyEndTime, ...  % SteadyStartTime と SteadyEndTime を EndFrame の後ろに追加
                          SteadyStartFrame, SteadyEndFrame, ...
                          VideoStartFrame, VideoEndFrame, SteadyVideoStart, SteadyVideoEnd);

    % 結果を表示（グラフとテーブルを統合）
    f = figure('Name', '音声セグメント分析', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
    
    % スクリーンサイズを取得
    screen_size = get(0, 'ScreenSize');
    
    % 余白を加えたウィンドウサイズ
    margin = 5; % 余白のピクセル数を半分に縮小
    f.Position = [margin, margin, screen_size(3) - 2*margin, screen_size(4) - 2*margin]; % 左右と上下に余白を追加
    
    % グラフのプロット
    ax = subplot(2, 1, 1);
    hold on;
    colors = lines(num_segments);
    for seg = 1:num_segments
        plot(segment_relative_times{seg}, segment_energies{seg}, 'Color', colors(seg, :), ...
             'DisplayName', sprintf('Segment %d', seg));
    end
    [~, name, ~] = fileparts(filename); % ファイルの拡張子を除く
    title(ax, sprintf('Segment Energy - %s', name), 'Interpreter', 'none'); % 'Interpreter'を'none'に設定
    xlabel(ax, 'Time (s, relative to each segment)');
    ylabel(ax, 'Energy');
    legend(ax, 'show');
    hold off;

    % テーブルのデータを axes にテキストとして描画
    ax_table = subplot(2, 1, 2); % 下側のエリアを指定
    cla(ax_table); % クリア
    axis off; % 軸は非表示

    % テーブルデータを文字列として作成
    table_text = evalc('disp(segment_table)'); % テーブル内容を文字列化
    text(0.5, 1, table_text, 'FontName', 'Courier', 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 10);

    % レイアウト調整
    ax_table.Position = [0, 0, 1, 0.375]; % 下部に37.5%の高さを設定（余白を減らす）

    % 余白を除いてFigure全体を保存
    [save_file, save_path] = uiputfile({'*.png', 'PNG Files (*.png)'; '*.*', 'All Files (*.*)'}, ...
                                      '図を保存', 'SegmentAnalysis.png');
    if isequal(save_file, 0)
        disp('保存がキャンセルされました。');
        return;
    end
    save_fullpath = fullfile(save_path, save_file);

    % print関数を使用して画像を保存
    print(f, save_fullpath, '-dpng', '-r300'); % 解像度300で保存
    fprintf('分析結果の図を保存しました: %s\n', save_fullpath);
end
