# VariantsJa

VariantsJa helps authors and editors to find variants (hyoki-yure) in Japanese language text.

It shows words (morphemes) whose dictionary forms have the same yomi but have different representations, regardless of their meanings.

## Installation

```
$ sudo apt install crystal libmecab-dev
$ make build
$ sudo apt install mecab-ipadic-utf8
$ cp bin/variants_ja ~/bin/
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

## Usage

### Synopsis

```
variants_ja [options] file
```

### Examples

```
$ echo "公開した資料に誤りがあった。航海した死霊に謝りがあった。" | variants_ja
コウカイ: 公開 (1) | 航海 (1)
        L1, C1  公開    公開した資料に
        L1, C15 航海    があった。航海した死霊に
シリョウ: 資料 (1) | 死霊 (1)
        L1, C5  資料    公開した資料に誤りがあ
        L1, C19 死霊    。航海した死霊に謝りがあ
$
```

```
$ echo "人が云うには、彼がそう言ったのだという。" | variants_ja
イウ: 云う (1) | 言う (1) | いう (1)
        L1, C3  云う    人が云うには、彼が
        L1, C12 言う    、彼がそう言ったのだとい
        L1, C18 いう    ったのだという。
$
```

```
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | variants_ja --report-type=variants
カタ: 方 (1) | かた (1)
        L1, C6  方      その区切り方のほうがい
        L2, C6  かた    その区切りかたの方がいい
ホウ: ほう (1) | 方 (1)
        L1, C8  ほう    区切り方のほうがいい。
        L2, C9  方      切りかたの方がいい。

$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | variants_ja --report-type=heteronyms
方: カタ (1) | ホウ (1)
        L1, C6  カタ    その区切り方のほうがい
        L2, C9  ホウ    切りかたの方がいい。
$
```

### Options

Type `variants_ja --help` to show command line options.

## Limitations and known problems

  * Shown results may contain incorrect items. Mostly because of bugs, and partly because this software is based on probabilistic inference.
  * It does not detect variants with different yomi (e.g. サーバ and サーバー).
  * Input text must be UTF-8/LF.
  * MeCab dictionary must be encoded in UTF-8.

## Motivation

This software was written as a proof-of-concept to see if and how computer software can aid authors finding variants. (For serious purposes, please use professionally developed production-ready tools.)

## See also

The following may be of your interest.

  * [Just Right!](https://www.justsystems.com/jp/products/justright/): A commertial copyediting helper software for Japanese language, with features to find variants.

## License

MIT

## Acknowledgements

Many thanks to:

  * Taku Kudo (MeCab author)
  * lpm11 (mecab and fucoidan shards author)
  * Crystal and its community

## Contributors

  * [Hisashi Morita](https://github.com/hisashim) - creator and maintainer
