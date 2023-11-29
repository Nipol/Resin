FROM mcr.microsoft.com/devcontainers/rust:1-1-bullseye

USER vscode

RUN curl -L https://foundry.paradigm.xyz | bash \
    && echo 'export PATH="$FOUNDRY_INSTALL/bin:$PATH"' >> ~/.zshrc
