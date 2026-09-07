# girinori

girinori は Flutter で作られた、鉄道ルートの入力・可視化・時刻表示を行うクロスプラットフォームアプリです。Android / iOS / Web / Desktop（Windows, macOS, Linux）向けのプロジェクト構成が含まれています。

## 主な機能

- ルート入力画面で駅・路線情報を構成
- ダッシュボードでルートやタイムラインを表示
- 時刻データの整形表示ユーティリティ
- Android ホーム画面ウィジェット連携（`RouteWidgetProvider` / `widget_service`）
- JSON 例ファイル（`assets/route_master.json.example`）を使ったデータ定義

## 技術スタック

- Flutter / Dart
- Kotlin（Android ネイティブ実装）
- Swift（iOS / macOS ランナー）
- CMake 構成（Windows / Linux）

## ディレクトリ構成（要点）

- `lib/main.dart` : アプリエントリーポイント
- `lib/models/` : ドメインモデル（`transit_model.dart`, `trip_model.dart`）
- `lib/controllers/` : 入力・時刻制御ロジック
- `lib/screens/` : 画面（`add_route_screen.dart`, `dashboard_screen.dart`）
- `lib/widgets/` : UI 部品（ダッシュボード表示、入力ノード等）
- `lib/services/widget_service.dart` : ウィジェット連携サービス
- `android/app/src/main/kotlin/com/example/girinori/RouteWidgetProvider.kt` : Android ウィジェットプロバイダ
- `assets/route_master.json.example` : ルートマスターデータ例

## セットアップ

### 1. 依存関係の取得

```bash
flutter pub get
```

### 2. 実行

```bash
# 接続中デバイスで実行
flutter run
```

### 3. テスト

```bash
flutter test
```

## ビルド例

```bash
# Android APK
flutter build apk

# iOS（macOS + Xcode 環境）
flutter build ios

# Web
flutter build web
```

## 補足

- このリポジトリには Flutter 標準の各プラットフォーム用ランナープロジェクトが含まれます。
- iOS の `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` は起動画像差し替え手順用の補助ファイルです。
