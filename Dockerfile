ARG PYTHON_VERSION=python-3.10
ARG BASE_IMAGE=jupyter/all-spark-notebook
FROM --platform=linux/amd64 $BASE_IMAGE:$PYTHON_VERSION
USER root

ENV TZ=America/Montevideo \
    JUPYTER_ENABLE_LAB=yes \
    GRANT_SUDO=yes

# Install pip deps
RUN pip install --upgrade pip && \
    pip install --upgrade \
    jupyterlab-spreadsheet-editor \
    jupyterlab_latex \
    jupyterlab-github \
    jupyterlab-system-monitor \
    mitosheet3 \
    jupyterlab_theme_solarized_dark

# Install requirements.txt
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

# Install ta-lib
RUN conda install -c conda-forge ta-lib

# Install hadoop
RUN conda install -y -c jetbrains kotlin-jupyter-kernel && echo "Kotlin Jupyter kernel installed via conda"
ENV HADOOP_OPTS = "$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"

USER $NB_UID

CMD ["jupyter-lab","--ip=0.0.0.0","--no-browser","--allow-root"]
