ARG PYTHON_VERSION=python-3.8.8
ARG BASE_IMAGE=jupyter/scipy-notebook
FROM $BASE_IMAGE:$PYTHON_VERSION

LABEL org.opencontainers.image.source="https://github.com/MaastrichtU-IDS/jupyterlab"

ENV TZ=America/Montevideo \
    JUPYTER_ENABLE_LAB=yes \
    GRANT_SUDO=yes
    # CHOWN_HOME=yes \
    # CHOWN_HOME_OPTS='-R'


# Install yarn for handling npm packages
RUN npm install --global yarn

# Enable yarn global add:
ENV PATH="$PATH:$HOME/.yarn/bin"

# Install extensions for JupyterLab with conda and pip
# Multi conda kernels: # https://stackoverflow.com/questions/53004311/how-to-add-conda-environment-to-jupyter-lab
RUN mamba install --quiet -y \
      openjdk=11 \
      maven \
      ipywidgets \
      ipython-sql \
      jupyterlab \
      jupyterlab-git \
      jupyterlab-lsp \
      jupyter-lsp-python \
      jupyter_bokeh \
      jupyterlab-drawio \
      rise \
      nb_conda_kernels \
      'jupyter-server-proxy>=3.1.0' && \
    mamba install -y -c plotly 'plotly>=4.8.2' && \
    mamba install ta-lib

RUN pip install --upgrade pip && \
    pip install --upgrade \
      jupyterlab-spreadsheet-editor \
      jupyterlab_latex \
      jupyterlab-github \
      jupyterlab-system-monitor \
      mitosheet3 \
      jupyterlab_theme_solarized_dark

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt


# Change to root user to install things
USER root

RUN apt-get update && \
    apt-get install -y tzdata curl wget unzip zsh vim htop gfortran \
        python3-dev libpq-dev libclang-dev

# Install Java kernel
RUN wget -O /opt/ijava-kernel.zip https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip && \
    unzip /opt/ijava-kernel.zip -d /opt/ijava-kernel && \
    cd /opt/ijava-kernel && \
    python install.py --sys-prefix && \
    rm /opt/ijava-kernel.zip


# Install VS Code server and extensions
RUN curl -fsSL https://code-server.dev/install.sh | sh
RUN code-server --install-extension redhat.vscode-yaml \
        --install-extension ms-python.python \
        --install-extension vscjava.vscode-java-pack \
        --install-extension ginfuru.ginfuru-better-solarized-dark-theme \
        --install-extension oderwat.indent-rainbow \
        --install-extension mutantdino.resourcemonitor \
        --install-extension mechatroner.rainbow-csv \
        --install-extension GrapeCity.gc-excelviewer \
        --install-extension tht13.html-preview-vscode \
        --install-extension mdickin.markdown-shortcuts \
        --install-extension redhat.vscode-xml \
        --install-extension nickdemayo.vscode-json-editor \
        --install-extension ms-mssql.mssql \
        # --install-extension ms-azuretools.vscode-docker \
        --install-extension eamodio.gitlens 

RUN cd /opt && \
    export EXT_VERSION=0.1.2 && \
    wget https://open-vsx.org/api/vemonet/stardog-rdf-grammars/$EXT_VERSION/file/vemonet.stardog-rdf-grammars-$EXT_VERSION.vsix && \
    code-server --install-extension vemonet.stardog-rdf-grammars-$EXT_VERSION.vsix

# Install oc, kubectl and Helm
RUN cd /tmp && \
    wget https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz && \
    tar xvf oc.tar.gz && \
    mv oc kubectl /usr/local/bin/ && \
    wget https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl_v1.2.0-0-gbc038f9_linux.tar.gz && \
    tar -xzf kfctl_v1.2.0-0-gbc038f9_linux.tar.gz  && \
    mv kfctl /usr/local/bin/ && \
    wget https://get.helm.sh/helm-v3.8.2-linux-386.tar.gz && \
    tar -xzf helm-*-linux-386.tar.gz && \
    mv linux-386/helm /usr/local/bin/


# Add JupyterLab and VSCode settings
COPY icons/*.svg /etc/jupyter/
COPY jupyter_notebook_config.py /etc/jupyter/jupyter_notebook_config.py

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    fix-permissions /home/$NB_USER/.local && \
    fix-permissions /opt && \
    fix-permissions /etc/jupyter


# Switch back to the notebook user to finish installation
USER ${NB_UID}

# Add config files for JupyterLab and VSCode
RUN mkdir -p ~/.jupyter/lab/user-settings/@jupyterlab/terminal-extension
# COPY --chown=$NB_USER:100 plugin.jupyterlab-settings /home/$NB_USER/.jupyter/lab/user-settings/@jupyterlab/terminal-extension/plugin.jupyterlab-settings
COPY themes.jupyterlab-settings /home/$NB_USER/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings
COPY settings.json /home/$NB_USER/.local/share/code-server/User/settings.json

RUN mkdir -p /home/$NB_USER/work

# Update and compile JupyterLab extensions
RUN jupyter labextension update --all && \
    jupyter lab build 


# Install Oh My ZSH! and custom theme
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN curl -fsSL -o ~/.oh-my-zsh/custom/themes/biratime.zsh-theme https://raw.github.com/vemonet/biratime/main/biratime.zsh-theme
RUN sed -i 's/^ZSH_THEME=".*"$/ZSH_THEME="biratime"/g' ~/.zshrc
RUN echo "\`conda config --set changeps1 false\`" >> ~/.oh-my-zsh/plugins/virtualenv/virtualenv.plugin.zsh
RUN echo 'setopt NO_HUP' >> ~/.zshrc
ENV SHELL=/bin/zsh

USER root
RUN chsh -s /bin/zsh 
USER ${NB_UID}

# Add some local scripts/shortcuts
ADD bin/* ~/.local/bin/

# Presets for git
RUN git config --global credential.helper 'store --file ~/.git-credentials' && \
    git config --global diff.colorMoved zebra && \
    git config --global fetch.prune true && \
    git config --global pull.rebase false


ENV WORKSPACE="/home/${NB_USER}/work"
ENV PERSISTENT_FOLDER="${WORKSPACE}/persistent"
RUN mkdir -p $PERSISTENT_FOLDER
WORKDIR ${WORKSPACE}
VOLUME [ "${PERSISTENT_FOLDER}" ]

CMD [ "start-notebook.sh", "--no-browser", "--ip=0.0.0.0", "--config=/etc/jupyter/jupyter_notebook_config.py" ]