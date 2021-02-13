[[ -r ~/.bashrc ]] && source ~/.bashrc

alias ls="ls $LS_OPTIONS"
alias gits='git status'
alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -i'

export PAGER='less -R'

# make package searching easier on Slackware.
lsp ()
{
	ls -1 "/var/log/packages/$@"* |xargs -i basename {}
}
