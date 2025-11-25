#compdef hyoki

# Zsh completion for Hyoki
# (Thanks to https://blog.kloetzl.info/posts/zsh-completion/)
#
# Usage:
#   1. Make sure you have set up fpath, e.g.:
#       grep fpath ~/.zshrc
#       /home/johnd/.zshrc:fpath=(~/.zsh.d/functions/Completion ${fpath})
#   2. Put this file as _hyoki in your fpath, e.g.:
#       cp completion.zsh ~/.zsh.d/functions/Completion/_hyoki
#   3. Start a new shell.

_hyoki() {
  integer ret=1
  local -a args
  args+=(
    '--report-type=[Choose report type]:report_type:(variants heteronyms)'
    '--report-format=[Choose report format]:report_format:(text markdown tsv)'
    '--highlight=[Enable/disable excerpt highlighting]:highlight:(auto always never)'
    '--excerpt-context-length=[Set excerpt context length]:excerpt_context_length:'
    '--sort-order=[Specify how report items should be sorted]:sort_order:(alphabetical appearance)'
    '--exclude-ascii-only-items=[Specify whether to exclude ASCII-only items in the output]:exclude_ascii_only_items:(true false)'
    '--pager=[Specify pager]:pager:'
    '--mecab-dict-dir=[Specify MeCab dictionary directory to use]:mecab_dict_dir:_dir_list'
    '(- *)--help[Show help message]'
    '(- *)--version[Show version]'
    '*:file:_files'
  )
  _arguments $args[@] && ret=0
  return ret
}

_hyoki
