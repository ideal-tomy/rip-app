# Firebase セットアップ手順

アプリを動作させる前に、以下を実行してください。

## 1. Firebase プロジェクト作成

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. 「プロジェクトを追加」で新規プロジェクトを作成
3. プロジェクト設定 > 全般 > マイアプリ > Web アプリを追加

## 2. 匿名認証の有効化

1. Firebase Console > Authentication > サインイン方法
2. 「匿名」を有効化

## 3. FlutterFire 設定

```bash
# FlutterFire CLI をインストール
dart pub global activate flutterfire_cli

# Firebase にログイン
firebase login

# プロジェクトディレクトリで実行（firebase_options.dart を生成）
flutterfire configure
```

`flutterfire configure` 実行時に、作成した Firebase プロジェクトを選択してください。
Web プラットフォームを選択すると、`lib/firebase_options.dart` が正しい認証情報で上書きされます。
`.firebaserc` の `YOUR_PROJECT_ID` も、Firebase プロジェクト ID に置き換えてください。

## 4. Firestore ルール・インデックスのデプロイ

```bash
firebase deploy --only firestore
```

## 5. Flutter Web ビルドと Hosting デプロイ

```bash
# Web ビルド
flutter build web --release

# Hosting にデプロイ
firebase deploy --only hosting
```

デプロイ後、表示される URL（例: https://YOUR_PROJECT_ID.web.app）からアプリにアクセスできます。
