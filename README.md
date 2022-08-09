# Infrastructure_docker_csssh

Normal git pushes will rebuild the "cs-ssh-staging.cs.calvin.edu" image, while
pushing a tagged version (v#.#.#) will rebuild production "cs-ssh.cs.calvin.edu"
image.

Show tags:  git tag
To add tag:  git tag -a v#.#.#
To push the tag to github:  git push origin --tags
