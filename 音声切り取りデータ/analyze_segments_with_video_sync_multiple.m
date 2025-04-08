function analyze_segments_with_video_sync_multiple()
    % 複数ファイル選択ダイアログを表示
    [files, path] = uigetfile({'*.wav;*.flac', 'Audio Files (*.wav, *.flac)'; '*.*', 'All Files (*.*)'}, ...
                               '音声ファイルを選択', 'MultiSelect', 'on');
    if isequal(files, 0)
        disp('ファイルが選択されませんでした。処理を終了します。');
        return;
    end

    % ファイル選択が1つの場合でもセル配列に統一
    if ischar(files)
        files = {files};
    end

    % パラメータ設定
    frame_size = 0.03; % フレームサイズ（30ms）
    hop_size = 0.01;   % ホップサイズ（10ms）
    frame_rate_video = 4000; % 映像のフレームレート（4000fps）

    % 複数ファイルを順番に処理
    for file_idx = 1:length(files)
        filename = fullfile(path, files{file_idx});
        % 音声データの読み込み
        [audio, fs] = audioread(filename);
        audio = audio / max(abs(audio));  % 正規化

        % パラメータ設定
        frame_len = round(frame_size * fs);
        hop_len = round(hop_size * fs);
        energy_threshold = 0.01; % 無音判定用のエネルギーしきい値
        window_duration = 0.5; % 定常区間の長さ（秒）
        window_frames = floor(window_duration / hop_size);

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
        segments = bwlabel(is_voiced); % セグメント分割
        num_segments = max(segments); % セグメント数

        % 各セグメントの情報を格納する変数
        Segment = []; StartFrame = []; EndFrame = [];
        StartTime = []; EndTime = [];
        SteadyStartFrame = []; SteadyEndFrame = [];
        SteadyStart = []; SteadyEnd = [];
        VideoStartFrame = []; VideoEndFrame = [];
        SteadyVideoStart = []; SteadyVideoEnd = [];

        % セグメントごとのエネルギーを保存
        segment_energies = {};
        segment_relative_times = {};

        % 各セグメントの分析
        for seg = 1:num_segments
            segment_frames = find(segments == seg); % セグメント内のフレーム番号
            if length(segment_frames) < window_frames
                continue; % セグメントが0.5秒より短い場合はスキップ
            end

            % セグメントの相対フレーム番号 (開始フレームを0にリセット)
            relative_frames = segment_frames - segment_frames(1);
            segment_energy = energy(segment_frames);
            segment_relative_time = relative_frames * hop_size; % 相対時間

            % 定常部分の特定
            best_score = -Inf;
            best_start = 0;

            for i = 1:(length(segment_frames) - window_frames + 1)
                % 0.5秒間のエネルギーの安定性評価
                window_energy = segment_energy(i:i+window_frames-1);
                score = -std(window_energy); % 標準偏差が小さいほどスコアが高い
                if score > best_score
                    best_score = score;
                    best_start = i;
                end
            end

            % 定常部分の結果
            best_start_frame = relative_frames(best_start);
            best_end_frame = best_start_frame + window_frames - 1;

            % 映像フレームの計算
            start_time = (segment_frames(1) - 1) * hop_size; % セグメント全体の開始時刻
            relative_time = (segment_frames - segment_frames(1)) * hop_size; % 相対時間
            end_time = relative_time(end);
            steady_start_time = relative_time(best_start);
            steady_end_time = steady_start_time + window_duration;

            % 映像フレームも0からスタート
            video_start_frame = 0; % セグメント開始時の映像フレーム
            video_end_frame = round(end_time * frame_rate_video);
            steady_video_start_frame = round(steady_start_time * frame_rate_video);
            steady_video_end_frame = round(steady_end_time * frame_rate_video);

            % セグメント情報を追加
            Segment = [Segment; seg];
            StartFrame = [StartFrame; 0]; % 相対フレーム
            EndFrame = [EndFrame; relative_frames(end)];
            StartTime = [StartTime; 0]; % 相対時間
            EndTime = [EndTime; end_time];
            SteadyStartFrame = [SteadyStartFrame; best_start_frame];
            SteadyEndFrame = [SteadyEndFrame; best_end_frame];
            SteadyStart = [SteadyStart; steady_start_time];
            SteadyEnd = [SteadyEnd; steady_end_time];
            VideoStartFrame = [VideoStartFrame; video_start_frame];
            VideoEndFrame = [VideoEndFrame; video_end_frame];
            SteadyVideoStart = [SteadyVideoStart; steady_video_start_frame];
            SteadyVideoEnd = [SteadyVideoEnd; steady_video_end_frame];

            % セグメントごとのエネルギーを保存
            segment_energies{seg} = segment_energy;
            segment_relative_times{seg} = segment_relative_time;
        end

        % テーブルを作成
        segment_table = table(Segment, StartFrame, EndFrame, StartTime, EndTime, ...
                              SteadyStartFrame, SteadyEndFrame, SteadyStart, SteadyEnd, ...
                              VideoStartFrame, VideoEndFrame, SteadyVideoStart, SteadyVideoEnd);

        % 結果を表示（グラフとテーブルを個別のウィンドウで表示）
        f = figure('Name', sprintf('音声セグメント分析 - %s', files{file_idx}), 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');
        t = tiledlayout(f, 2, 1, 'TileSpacing', 'Compact');

        % グラフのプロット
        ax1 = nexttile(t, 1);
        hold on;
        colors = lines(num_segments);
        for seg = 1:num_segments
            plot(segment_relative_times{seg}, segment_energies{seg}, 'Color', colors(seg, :), ...
                 'DisplayName', sprintf('Segment %d', seg));
        end
        title(ax1, 'Segment Energy');
        xlabel(ax1, 'Time (s, relative to each segment)');
        ylabel(ax1, 'Energy');
        legend(ax1, 'show');
        hold off;

        % テーブルを表示
        ax2 = nexttile(t, 2);
        uitable('Parent', f, 'Data', segment_table{:,:}, ...
                'ColumnName', segment_table.Properties.VariableNames, ...
                'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    end
end
