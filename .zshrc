export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
export EDITOR="$(which vim)"
export VISUAL="$(which vim)"

HISTFILESIZE=1000000000         #maximum Lines of History
HISTSIZE=1000000                #maximum Lines of History 

USE_GKE_GCLOUD_AUTH_PLUGIN=True

[ -f $HOME/bin/fubectl.source ] && source $HOME/bin/fubectl.source

eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# bun completions
[ -s "/Users/florian/.bun/_bun" ] && source "/Users/florian/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# aliases
alias df="df -h"
alias rm="rm -i"
alias mv="mv -i"
alias gs="git status"
alias gl="git log"
alias gll="git log --oneline"
alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
alias tc="tar -cvf"
alias tx="tar -xvf"
alias tv="tar -tvf"

#export DD_API_KEY="<add-value>"
#export DD_APP_KEY="<add-value>"
#export DD_SITE="datadoghq.eu"

[ -f $HOME/Projects/sre-agent ] && export SRE_AGENT_HOME="/Users/florian/Projects/sre-agent"

export PATH="$HOME/.local/bin:$PATH"

echo "finished .zshrc"
