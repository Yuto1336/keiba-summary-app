# 競馬まとめアプリ（自分専用・SideStore方式）

その日のJRA全レース結果まとめ（コース特徴／レースの運び／勝ち馬の型／全馬の着順・人気・騎手・通過順・上がり）を iPhone で読むためのビューアアプリ。
まとめデータは JSON で、アプリは起動時にデータURLから最新分を取りに行く（取れない場合は同梱分を表示）。

## 構成

- `Sources/` … SwiftUI アプリ本体（iOS 17+、外部ライブラリなし）
- `project.yml` … XcodeGen のプロジェクト定義（Xcodeプロジェクトは生成物なのでリポジトリに含めない）
- `Data/` … まとめデータ。`index.json`（日付一覧）と `YYYY-MM-DD.json`（その日の全レース）
- `tools/convert.py` … まとめ Markdown を JSON に変換するスクリプト
- `.github/workflows/build-ipa.yml` … macOS ランナーで未署名 IPA を自動ビルド

## IPA を作る（GitHub Actions）

1. GitHub でリポジトリ `keiba-summary-app` を作り、このフォルダの中身を push する
2. `Sources/DataStore.swift` の `defaultBaseURL` にある `YOUR_GITHUB_NAME` を自分の GitHub アカウント名に書き換える（アプリの設定画面から後で変えてもOK）
3. GitHub の Actions タブで「Build unsigned IPA」が自動実行される（push 時）。手動実行も可
4. 完了したら Artifacts から `KeibaSummary-unsigned-ipa` をダウンロードする。中に未署名の `KeibaSummary-unsigned.ipa` が入っている

## iPhone に入れる（SideStore）

大まかな流れ（詳細は SideStore 公式 https://sidestore.io のガイド参照）:

1. 初回だけ PC（Mac/Windows）が必要。公式手順で SideStore を iPhone にインストールする
2. iPhone の「設定 > 一般 > VPNとデバイス管理」等で開発者モードを有効化し、SideStore に自分の Apple ID でサインインする
3. ダウンロードした IPA を SideStore で開き、インストールする（SideStore が Apple ID で署名してくれる）
4. 無料の Apple ID 署名は **7日で失効** する。SideStore の自動リフレッシュ（バックグラウンド更新）を有効にしておくと、Wi-Fi 環境で自動再署名される
5. 無料枠では同時に置けるサイドロードアプリ数に上限（3つ）がある

注意: 署名に使う Apple ID は普段使いと分けた専用 ID を作るのがおすすめ。

## データを増やす

新しい日のまとめ Markdown ができたら:

```sh
python3 tools/convert.py JRA結果まとめ_YYYY-MM-DD.md Data
```

で `Data/` に JSON が追加される（`index.json` も自動更新）。GitHub に push すれば、アプリは次回起動時に新しい日を自動で読み込む。**データ追加だけなら再ビルド・再インストールは不要。**

## 既知の制約

- アプリ本体の変更（画面や機能）には再ビルド＋SideStore での再インストールが必要
- プッシュ通知はこのアプリには無い（通知は従来通りチャットで届く想定）
