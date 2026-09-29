#!/usr/bin/env zsh
# Run with: zsh -f tests/oc-completion.test.zsh modules/ai/oc.zsh
emulate -R zsh
setopt no_unset

module=${1:A}
[[ -f $module ]] || { print -u2 'pass the oc.zsh path'; exit 1; }
typeset -ga offered native_words
typeset -gi files_called=0 native_current=0 prefix_calls=0 checks=0
typeset -g native_service='' prefix=''
typeset -gA _comps

compadd() {
  local -i i=1
  while (( i <= $# )); do
    if [[ ${argv[i]} == -- ]]; then
      offered+=("${(@)argv[i+1,-1]}")
      return
    fi
    (( i++ ))
  done
}
_files() { (( files_called++ )); }
compset() { (( prefix_calls++ )); prefix=$2; }

complete() {
  offered=() native_words=() files_called=0 native_current=0 prefix_calls=0 prefix=''
  words=("$@")
  CURRENT=${#words}
  source "$module"
}
has() {
  (( checks++ ))
  (( ${offered[(Ie)$1]} )) || { print -u2 "missing $1 in: ${offered[*]}"; exit 1; }
}
not_has() {
  (( checks++ ))
  (( ! ${offered[(Ie)$1]} )) || { print -u2 "unexpected $1 in: ${offered[*]}"; exit 1; }
}
is() {
  (( checks++ ))
  [[ $1 == $2 ]] || { print -u2 "expected '$2', got '$1'"; exit 1; }
}

complete oc ''
has run; has mcp; has completion; has acp; has providers; has plugin; has db
not_has agents; not_has sessions
is "$files_called" 1
complete oc --profile ''
has balanced; has anthropic; not_has run
complete oc --review-model=
has fable
complete oc --agents=custom -- ''
has run; not_has balanced
complete oc --profile balanced run --log-level ''
has DEBUG; has WARN; not_has run
complete oc --profile=balanced run --format=json
has default; has json; is "$prefix" '--format='
complete oc run --file ''
is "$files_called" 1; not_has run
complete oc run --agent ''
has build; has plan
complete oc run --model ''
has provider/model
complete oc serve --hostname ''
has localhost
complete oc serve --port ''
has 4096
complete oc --profile openai mcp ''
has add; has list; has auth; not_has run
complete oc providers ''
has login; has logout
complete oc debug ''
has file; has snapshot
complete oc debug file ''
has read; has search
complete oc github ''
has install; has run
complete oc session ''
has delete; has list
complete oc db ''
has path
complete oc upgrade --method ''
has brew; has scoop
complete oc upgrade -m ''
has pnpm; not_has provider/model
complete oc run -m ''
has provider/model; not_has pnpm
complete oc run -f ''
is "$files_called" 1
complete oc uninstall -f ''
is "$files_called" 0
complete oc session list --format ''
has table; has json; not_has tsv
complete oc db --format ''
has tsv; not_has table
complete oc import ''
is "$files_called" 1
complete oc ./project/ ''
is "$files_called" 1
complete oc debug file read ''
not_has search; is "$files_called" 1
complete oc --profile balanced run -- ''
not_has --model
complete oc run --file example.json -- ''
not_has --format
complete oc run --model provider/model -- ''
not_has provider/model
complete oc run --model=provider/model -- ''
not_has provider/model

_opencode_yargs_completions() {
  native_words=("${words[@]}")
  native_current=$CURRENT
  native_service=$service
}
_comps[opencode]=_opencode_yargs_completions
complete oc --profile=balanced --review-model fable -- run --model=provider/model ''
is "${(j:,:)native_words}" 'opencode,run,--model=provider/model,'
is "$native_current" 4; is "$native_service" opencode
complete oc --agents custom run -- ''
is "${(j:,:)native_words}" 'opencode,run,--,'
is "$native_current" 4
unset '_comps[opencode]'
_opencode() { native_words=("${words[@]}"); native_current=$CURRENT; }
complete oc --profile balanced run --agent ''
is "${(j:,:)native_words}" 'opencode,run,--agent,'
is "$native_current" 4
print "ok: $checks completion assertions"
