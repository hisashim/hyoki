# Hyoki

Hyoki helps authors and editors to find variants (異表記, 表記ゆれ) in Japanese language text.

It shows words (morphemes) whose dictionary forms have the same yomi but have different representations, regardless of their meanings. It may make it easier to check variants, either intentional or unintentional.

## Usage

### Synopsis

```
hyoki [OPTION]... [FILE]...
```

### Options

Type `hyoki --help` to show command line options.

```
Help finding variants in Japanese text

Usage:
  hyoki [OPTION]... [FILE]...

Options:
    --report-type=variants|heteronyms
                                     Choose report type (default: variants)
    --report-format=text|tsv         Choose report format (default: text)
    --color=auto|always|never        Enable/disable excerpt highlighting (default: auto)
    --context-length=N|N,M           Set excerpt context length to N (or preceding N and succeeding M) characters (default: 5)
    --sort=alphabetical|appearance   Specify how report items should be sorted (default: alphabetical)
    --include-ascii=true|false       Specify whether to include ASCII-only items in the output (default: true)
    --mecab-dict-dir=DIR             Specify MeCab dictionary directory to use (e.g. /var/lib/mecab/dic/ipadic-utf8)
    --help                           Show help message
    --version                        Show version
```

### Examples

Hyoki suggests possible variants.

```
$ echo "暖かい部屋で温かい食事をとる。" | hyoki
* アタタカイ: 暖かい (1) | 温かい (1)
  - -   L1, C1  暖かい  暖かい部屋で温か
  - -   L1, C7  温かい  かい部屋で温かい食事をとる
$
```

```
$ echo "人が云うには、彼がそう言ったのだという。" | hyoki
* イウ: 云う (1) | 言う (1) | いう (1)
  - -   L1, C3  云う    人が云うには、彼が
  - -   L1, C12 言う    、彼がそう言ったのだとい
  - -   L1, C18 いう    ったのだという。
$
```

```
$ echo "行う（本則）・行なう（許容）" | hyoki
* オコナウ: 行う (1) | 行なう (1)
  - -   L1, C1  行う    行う（本則）・
  - -   L1, C8  行なう  （本則）・行なう（許容）
$
```

### More examples and tips

**File names**: File names are displayed if they are provided as command line arguments. This can be useful when chapters or sections of the work are split into multiple files.

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

**Heteronyms**: In addition to variants, it can suggest possible heteronyms (同綴異音異義語).

```
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | hyoki --report-type=variants
* カタ: 方 (1) | かた (1)
  - -   L1, C6  方      その区切り方のほうがい
  - -   L2, C6  かた    その区切りかたの方がいい
* ホウ: ほう (1) | 方 (1)
  - -   L1, C8  ほう    区切り方のほうがいい。
  - -   L2, C9  方      切りかたの方がいい。
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | hyoki --report-type=heteronyms
* 方: カタ (1) | ホウ (1)
  - -   L1, C6  カタ    その区切り方のほうがい
  - -   L2, C9  ホウ    切りかたの方がいい。
$
```

**TSV output**: It can print TSV for ease of further processing.

```
$ echo "その区切り方のほうがいい。\nその区切りかたの方がいい。" | hyoki --output-format=tsv
lexical form yomi       source  line    character       lexical form    surface excerpt
カタ    -       1       6       方      方      その区切り方のほうがい
カタ    -       2       6       かた    かた    その区切りかたの方がいい
ホウ    -       1       8       ほう    ほう    区切り方のほうがいい。
ホウ    -       2       9       方      方      切りかたの方がいい。
$
```

**Skip ASCII-only words**: `--include-ascii=false` removes ASCII-only items from the output. This may help you when you are examining non-ASCII words within multilingual contents.

```
$ echo 'UNIXとUnix。思考と試行。' | hyoki | grep '^\*'
* unix: UNIX (1) | Unix (1)
* シコウ: 思考 (1) | 試行 (1)
$ echo 'UNIXとUnix。思考と試行。' | hyoki --include-ascii=false | grep '^\*'
* シコウ: 思考 (1) | 試行 (1)
$
```

**Tab width**: Fields are separated horizontally by tab characters, which may cause awkward appearance in some situations. It can be worked around by untabifying the output using utilities such like `expand` (included in GNU coreutils).

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

## Installation

```
$ git clone https://github.com/hisashim/hyoki.git && cd hyoki
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

Note that older version of libmecab Debian packages may need some tweak. As of 0.996-14+b12, I took a workaround using private packages:

```
$ mkdir workdir && cd workdir
$ git clone https://salsa.debian.org/hisashim/mecab.git
$ cd mecab
$ git switch adjust-mecab-config-dicdir-for-debian
$ sudo apt install build-essential
$ dpkg-buildpackage -b -rfakeroot -us -uc
...
dpkg-checkbuilddeps: error: Unmet build dependencies: ...
...
$ sudo apt install ...
$ dpkg-buildpackage -b -rfakeroot -us -uc
...
$ sudo dpkg --install ../libmecab-dev_*.deb ../libmecab2_*.deb
```

(See [#1024618 - libmecab-dev: mecab-config --dicdir prints wrong directory](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1024618).)

## Notes

### Limitations and known problems

  * It can not detect “variants” with different yomi in dictionary forms, e.g.:
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
  * Results may be incorrect. Most likely because of bugs, and possibly because this software is based on probabilistic inference.
  * Input text must be UTF-8/LF.
  * MeCab dictionary must be encoded in UTF-8.

For serious purposes, please use professionally developed production-ready tools.

### Motivation

This software was written as a simple proof-of-concept to see if and how situational applications can aid authors.

### See also

The following may be of your interest.

  * [Just Right!](https://www.justsystems.com/jp/products/justright/): A commercial copyediting helper software for Japanese language, with features to find variants.

## License

This software is distributed under the terms of the [MIT license](LICENSE).

## Acknowledgments

Many thanks to:

  * Taku Kudo (MeCab author)
  * lpm11 (mecab and fucoidan shards author)
  * Crystal and its community

## Contributors

  * [Hisashi Morita](https://github.com/hisashim) - creator and maintainer
