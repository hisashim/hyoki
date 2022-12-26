# Hyoki

Hyoki helps authors and editors to find variants in Japanese language text.

It shows words (morphemes) whose dictionary forms have the same yomi but have different representations, regardless of their meanings. It may make it easier to check intentional use of variants and to find unintentional variants (so-called hyoki-yure).

## Usage

### Synopsis

```
hyoki [options] file
```

### Examples

```
$ echo "暖かい部屋で温かい食事をとる。" | hyoki
アタタカイ: 暖かい (1) | 温かい (1)
        L1, C1  暖かい  暖かい部屋で温か
        L1, C7  温かい  かい部屋で温かい食事をとる
$
```

```
$ echo "人が云うには、彼がそう言ったのだという。" | hyoki
イウ: 云う (1) | 言う (1) | いう (1)
        L1, C3  云う    人が云うには、彼が
        L1, C12 言う    、彼がそう言ったのだとい
        L1, C18 いう    ったのだという。
$
```

```
$ echo "行う（本則）・行なう（許容）" | hyoki
オコナウ: 行う (1) | 行なう (1)
        L1, C1  行う    行う（本則）・
        L1, C8  行なう  （本則）・行なう（許容）
$
```

```
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | hyoki --report-type=variants
カタ: 方 (1) | かた (1)
        L1, C6  方      その区切り方のほうがい
        L2, C6  かた    その区切りかたの方がいい
ホウ: ほう (1) | 方 (1)
        L1, C8  ほう    区切り方のほうがいい。
        L2, C9  方      切りかたの方がいい。
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | hyoki --report-type=heteronyms
方: カタ (1) | ホウ (1)
        L1, C6  カタ    その区切り方のほうがい
        L2, C9  ホウ    切りかたの方がいい。
$
```

### Options

Type `hyoki --help` to show command line options.

Help message as of version 0.1.0:

```
Help finding variants in Japanese text

Usage:
  hyoki [OPTIONS] file

Options:
    --report-type=variants|heteronyms
                                     Choose report type (default: variants)
    --output-format=text|tsv         Choose output format (default: text)
    --color=auto|always|never        Enable/disable excerpt highlighting (default: auto)
    --context=N|N,M                  Set excerpt context to N (or preceding N and succeeding M) characters (default: 5)
    --sort=alphabetical|appearance   Specify how report items should be sorted (default: alphabetical)
    --mecab-dict-dir=DIR             Specify MeCab dictionary directory to use (e.g. /var/lib/mecab/dic/ipadic-utf8)
    --help                           Show help message
    --version                        Show version
```

## Installation

```
$ sudo apt install crystal libmecab-dev
$ make build
$ sudo apt install mecab-ipadic-utf8
$ cp bin/hyoki ~/bin/
```

### Requirements

  * Runtime requirements:
    - Unix-like operating system (Tested on Debian GNU/Linux)
    - libmecab2
    - mecab-ipadic-utf8 or mecab-naist-jdic
  * Build requirements:
    - Unix-like operating system (Tested on Debian GNU/Linux)
    - [Crystal](https://crystal-lang.org)
    - Fucoidan (See [`shard.yml`](shard.yml))
    - libmecab-dev

## Limitations and known problems

  * It can not detect “variants” with different yomi in dictionary forms, e.g:
    - サーバ and サーバー
    - 1つ and 一つ
    - 誤り and 謝る:
      ```
      $ echo "誤りがあった。謝りがあった。" | hyoki
      $ echo "誤りがあった。謝りがあった。" | mecab
      誤り    名詞,一般,*,*,*,*,誤り,アヤマリ,アヤマリ
      ...
      謝り    動詞,自立,*,*,五段・ラ行,連用形,謝る,アヤマリ,アヤマリ
      ...
      $
      ```
  * Results may contain incorrect items. Most likely because of bugs, and partly because this software is based on probabilistic inference.
  * Input text must be UTF-8/LF.
  * MeCab dictionary must be encoded in UTF-8.

For serious purposes, please use professionally developed production-ready tools.

## Motivation

This software was written as a simple proof-of-concept to see if and how situational applications can aid authors.

## See also

The following may be of your interest.

  * [Just Right!](https://www.justsystems.com/jp/products/justright/): A commercial copyediting helper software for Japanese language, with features to find variants.

## License

MIT

## Acknowledgments

Many thanks to:

  * Taku Kudo (MeCab author)
  * lpm11 (mecab and fucoidan shards author)
  * Crystal and its community

## Contributors

  * [Hisashi Morita](https://github.com/hisashim) - creator and maintainer
