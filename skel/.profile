[[ -r ~/.bashrc ]] && source ~/.bashrc

alias ls="ls $LS_OPTIONS"
alias gits='git status'

# make package searching easier on Slackware.
lsp ()
{
	ls -1 "/var/log/packages/$@"* |xargs -i basename {}
}
