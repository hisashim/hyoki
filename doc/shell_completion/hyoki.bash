# Bash completion for Hyoki

_hyoki_completions()
{
  local cur prev opts
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="\
    --report-type \
    --report-format \
    --highlight \
    --excerpt-context-length \
    --sort-order \
    --include-ascii \
    --pager \
    --mecab-dict-dir \
    --help \
    --version\
    "
  COMPREPLY=()

  case ${prev} in
    --report-type)
      COMPREPLY=( $(compgen -W 'variants heteronyms' -- "${cur}") )
      return 0
      ;;
    --report-format)
      COMPREPLY=( $(compgen -W 'text markdown tsv' -- "${cur}") )
      return 0
      ;;
    --highlight)
      COMPREPLY=( $(compgen -W 'auto always never' -- "${cur}") )
      return 0
      ;;
    --excerpt-context-length)
      COMPREPLY=( $(compgen -W '5 5,5' -- "${cur}") )
      return 0
      ;;
    --sort-order)
      COMPREPLY=( $(compgen -W 'alphabetical appearance' -- "${cur}") )
      return 0
      ;;
    --include-ascii)
      COMPREPLY=( $(compgen -W 'true false' -- "${cur}") )
      return 0
      ;;
    --pager)
      COMPREPLY=( $(compgen -W '' -- "${cur}") )
      return 0
      ;;
    --mecab-dict-dir)
      COMPREPLY=( $(compgen -W '/var/lib/mecab/dic/ipadic-utf8' -- "${cur}") )
      return 0
      ;;
    --help | --version)
      return 1
      ;;
  esac

  if [[ ${cur} == -* ]]; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
  fi
} &&
  complete -o filenames -o bashdefault -o default -F _hyoki_completions hyoki
