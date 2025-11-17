# Hyoki

  * [English](README.md) | [Japanese](README_ja.md)

Hyokiは、日本語の文章の表記ゆれを見つけることを手助けするソフトウェアです。

![screenshot](doc/screenshot.png)

Hyokiは、読みが同一で表記が異なる語（実際には形態素）を一覧表示します。意図的な使い分けであるか、意図しない表記ゆれであるかを判断する能力はありませんが、表記の違いを確認する手助けになるかもしれません。

## 使い方

### 概要

```
hyoki [OPTIONS]... [FILE]...
```

### オプション

`hyoki --help`と入力すると、次のようにコマンドラインオプション等が表示されます。

```
Hyoki helps finding variants in Japanese text

Usage:
  hyoki [OPTIONS]... [FILE]...

Options:
    --report-type=variants|heteronyms
                                     Choose report type (default: variants)
    --report-format=text|markdown|tsv
                                     Choose report format (default: text)
    --highlight=auto|always|never    Enable/disable excerpt highlighting (default: auto)
    --excerpt-context-length=N|N,M   Set excerpt context length to N (or preceding N and succeeding M) characters (default: 5)
    --sort-order=alphabetical|appearance
                                     Specify how report items should be sorted (default: alphabetical)
    --exclude-ascii-only-items=true|false
                                     Specify whether to exclude ASCII-only items in the output (default: false)
    --pager=PAGER                    Specify pager (default: "", falls back to $HYOKI_PAGER or $PAGER)
    --mecab-dict-dir=DIR             Specify MeCab dictionary directory to use (e.g. /var/lib/mecab/dic/ipadic-utf8)
    --help                           Show help message
    --version                        Show version
```

### 実行例

Hyokiは表記ゆれの可能性がある候補を次のように提示します。

```
$ echo "暖かい部屋で温かい食事をとる。" > test.txt
$ hyoki test.txt
* アタタカイ: 暖かい (1) | 温かい (1)
  - test.txt    L1, C1  暖かい  暖かい部屋で温か
  - test.txt    L1, C7  温かい  かい部屋で温かい食事をとる
$
```

```
$ echo "人が云うには、彼がそう言ったのだという。" > test.txt
$ hyoki test.txt
* イウ: 云う (1) | 言う (1) | いう (1)
  - test.txt    L1, C3  云う    人が云うには、彼が
  - test.txt    L1, C12 言う    、彼がそう言ったのだとい
  - test.txt    L1, C18 いう    ったのだという。
$
```

```
$ echo "行う（本則）・行なう（許容）" > test.txt
$ hyoki test.txt
* オコナウ: 行う (1) | 行なう (1)
  - test.txt    L1, C1  行う    行う（本則）・
  - test.txt    L1, C8  行なう  （本則）・行なう（許容）
$
```

```
$ echo "その区切り方のほうがいい。" > a.txt
$ echo "その区切りかたの方がいい。" > b.txt
$ hyoki a.txt b.txt
* カタ: 方 (1) | かた (1)
  - a.txt       L1, C6  方      その区切り方のほうがい
  - b.txt       L1, C6  かた    その区切りかたの方がいい
* ホウ: ほう (1) | 方 (1)
  - a.txt       L1, C8  ほう    区切り方のほうがいい。
  - b.txt       L1, C9  方      切りかたの方がいい。
$
```

### さらなる実行例と利用上のヒント

**同形異音異義語**: variants（異表記）だけでなく、heteronym（同綴異音異義語）の候補を提示することもできます。

```
$ echo "その区切り方のほうがいい。" > a.txt
$ echo "その区切りかたの方がいい。" > b.txt
$ hyoki --report-type=variants a.txt b.txt
* カタ: 方 (1) | かた (1)
  - a.txt       L1, C6  方      その区切り方のほうがい
  - b.txt       L1, C6  かた    その区切りかたの方がいい
* ホウ: ほう (1) | 方 (1)
  - a.txt       L1, C8  ほう    区切り方のほうがいい。
  - b.txt       L1, C9  方      切りかたの方がいい。
$ hyoki --report-type=heteronyms a.txt b.txt
* 方: カタ (1) | ホウ (1)
  - a.txt       L1, C6  カタ    その区切り方のほうがい
  - b.txt       L1, C9  ホウ    切りかたの方がいい。
$
```

**Markdown出力**: 簡単なMarkdown形式での出力も可能です。情報量が少なくなりますが、文字端末以外の環境では読みやすいかもしれません。

```
$ echo "その区切り方のほうがいい。" > a.txt
$ echo "その区切りかたの方がいい。" > b.txt
$ hyoki --report-format=markdown a.txt b.txt
* カタ: 方 (1) | かた (1)
  - a.txt: `その区切り方のほうがい`
  - b.txt: `その区切りかたの方がいい`
* ホウ: ほう (1) | 方 (1)
  - a.txt: `区切り方のほうがいい。`
  - b.txt: `切りかたの方がいい。`
$
```

**TSV出力**: タブ区切りテキスト（TSV）での出力も可能です。Hyokiの出力をさらに機械処理したい場合に役立つかもしれません。

```
$ echo "その区切り方のほうがいい。" > a.txt
$ echo "その区切りかたの方がいい。" > b.txt
$ hyoki --report-format=tsv a.txt b.txt
lexical form yomi       source  line    character       lexical form    surface excerpt
カタ    a.txt   1       6       方      方      その区切り方のほうがい
カタ    b.txt   1       6       かた    かた    その区切りかたの方がいい
ホウ    a.txt   1       8       ほう    ほう    区切り方のほうがいい。
ホウ    b.txt   1       9       方      方      切りかたの方がいい。
$
```

**ASCII文字からなる単語を出力しない**: `--exclude-ascii-only-items=true` オプションを使うと、ASCII文字だけからなる語を出力しなくなります。複数の言語が混在したテキストの中にある、非ASCIIな語句だけに注目している時に、役に立つかもしれません。

```
$ echo 'UNIXとUnix。思考と試行。' | hyoki --exclude-ascii-only-items=false | grep '^\*'
* unix: UNIX (1) | Unix (1)
* シコウ: 思考 (1) | 試行 (1)
$ echo 'UNIXとUnix。思考と試行。' | hyoki --exclude-ascii-only-items=true | grep '^\*'
* シコウ: 思考 (1) | 試行 (1)
$
```

**タブ幅**: text形式での出力中の行内の各フィールドは、タブ文字で区切られます。そのせいで出力が読みにくくなる場合があります。そういった場合は、`expand`などを使ってタブ文字を空白文字に展開すれば、読みやすくなるかもしれません（`expand`はGNU coreutilsに含まれています）。

```
$ hyoki i_am_a_cat.txt
...
  - i_am_a_cat.txt      L4, C7  ある    吾輩は猫である。名前はま
  - i_am_a_cat.txt      L5, C104        ある    悪な種族であったそうだ。
...
$ hyoki i_am_a_cat.txt | expand --tabs=10
...
  - i_am_a_cat.txt  L4, C7    ある    吾輩は猫である。名前はま
  - i_am_a_cat.txt  L5, C104  ある    悪な種族であったそうだ。
...
$
```

## インストール方法

```
$ git clone https://github.com/hisashim/hyoki.git && cd hyoki
$ sudo apt install crystal shards libmecab-dev mecab-ipadic-utf8
$ make
$ cp bin/hyoki ~/bin/
```

### 必要なソフトウェア

  * 実行するのに必要なもの:
    - Unix系のOS（テストは主にDebian GNU/Linuxで行われています）
    - libmecab2
    - mecab-ipadic-utf8またはmecab-naist-jdic
  * ビルドするのに必要なもの:
    - Unix系のOS（テストは主にDebian GNU/Linuxで行われています）
    - [Crystal](https://crystal-lang.org)
    - [Shards](https://github.com/crystal-lang/shards)（Crystalの依存ライブラリ管理ツール）
    - [crystal-fucoidan](https://github.com/lpm11/crystal-fucoidan) ([`shard.yml`](shard.yml)を参照)
    - libmecab-dev
    - [AsciiDoctor](https://asciidoctor.org)（manual pages生成のため）
    - [Git](https://git-scm.com)

## 備考

### 制限事項と既知の問題

  * 正規化すると読みが同一でなくなるような語句については、Hyokiは異表記に気づくことができない。具体例:
    - サーバ と サーバー
    - 1つ と 一つ
    - 誤り と 謝る:
      ```
      $ echo "誤りがあった。謝りがあった。" | hyoki
      $ echo "誤りがあった。謝りがあった。" | mecab
      誤り    名詞,一般,*,*,*,*,誤り,アヤマリ,アヤマリ
      ...
      謝り    動詞,自立,*,*,五段・ラ行,連用形,謝る,アヤマリ,アヤマリ
      ...
      $
      ```
  * 出力結果が間違っている可能性がある。おそらくバグが原因。
  * 入力テキストはUTF-8/LFでなければならない。
  * MeCab辞書のエンコーディングはUTF-8でなければならない。

仕事や真剣な用途には、プロが開発した業務用のツールを使ってください。

### 開発の動機

このソフトウェアは、situational application（ソフトウェア開発の専門家ではない人が、現場の状況に合わせて間に合わせで作ったアプリケーション）が著者を支援できるかを考えるための、簡単な試作品（proof-of-concept）として作られました。

### 資料

関心がある方のために資料を挙げておきます。

  * [Just Right!](https://www.justsystems.com/jp/products/justright/): 日本語の文章の校正を支援してくれる商用ソフトウェア製品。表記ゆれを検出する機能を備えている。
  * [「異字同訓」の漢字の使い分け例（報告）](https://www.bunka.go.jp/seisaku/bunkashingikai/kokugo/hokoku/pdf/ijidokun_140221.pdf)（文化庁，2014）: 異字同訓の用例。

## ライセンス

このソフトウェアは[MIT license](LICENSE)のもとで公開されています。

## 謝辞

次の方々に深く感謝します:

  * Taku Kudo（MeCab作者）
  * T. Tsunoda（crystal-mecabおよびcrystal-fucoidanの作者）
  * Crystalとそのコミュニティ

## 貢献者

  * [Hisashi Morita](https://github.com/hisashim) - creator and maintainer
