# !sh

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export PATH="/usr/local/opt/rbenv/bin:$PATH"
eval "$(rbenv init -)"
eval "cd $DIR; bundle exec ./dns_service.rb -r"

