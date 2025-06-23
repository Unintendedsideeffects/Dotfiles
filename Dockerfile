FROM archlinux:latest

# ----------------------------------
# Arch Linux base image with dotfiles
# Copies dotfiles and runs bootstrap script
# ----------------------------------

# install base tools
RUN pacman -Syu --noconfirm git base-devel sudo yay zsh && \
    pacman -Scc --noconfirm

# create non-root user
ARG USER=developer
ARG UID=1000
RUN useradd -m -u ${UID} ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# copy dotfiles
COPY .dotfiles /home/${USER}/.dotfiles
RUN chown -R ${USER}:${USER} /home/${USER}/.dotfiles

USER ${USER}
WORKDIR /home/${USER}

# bootstrap dotfiles
RUN bash .dotfiles/bin/bootstrap.sh --skip-gui || true

CMD ["zsh"]