# Enterprise/Work specific configuration

export IS_ENTERPRISE=true

# Enterprise-specific aliases
alias vpn="sudo openconnect"
alias corp="cd ~/corporate"
alias docs="cd ~/Documents/work"

# Enterprise environment variables
export CORPORATE_PROXY="http://proxy.corp.local:8080"
export JAVA_HOME="/usr/lib/jvm/java-17"
export PATH="$JAVA_HOME/bin:$PATH"

# Enterprise tools
export MAVEN_HOME="/opt/maven"
export PATH="$MAVEN_HOME/bin:$PATH"

# Corporate Git configuration
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Work Profile}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-user@company.com}"

# Enterprise-specific functions
function corp-vpn() {
  echo "Connecting to corporate VPN..."
  sudo openconnect --user="${CORP_VPN_USER:-$USER}" "${CORP_VPN_HOST:-vpn.corp.local}"
}

function corp-ssh() {
  ssh -i "${CORP_SSH_KEY:-$HOME/.ssh/corp_key}" "${CORP_SSH_USER:-$USER}@$1.${CORP_SSH_DOMAIN:-corp.local}"
} 
