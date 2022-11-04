ARG PYTHON_VERSION=python-3.10
ARG BASE_IMAGE=jupyter/pyspark-notebook
FROM --platform=linux/amd64 $BASE_IMAGE:$PYTHON_VERSION
USER root

ENV TZ=America/Montevideo \
    JUPYTER_ENABLE_LAB=yes \
    GRANT_SUDO=yes

# Install conda packages
COPY environment.yml environment.yml
RUN conda install -y boto && \
    conda install -y nomkl && \
    conda env update -f environment.yml -n root && \
    conda clean --all -y && \
    rm -rf ~/.cache/pip

ENV HADOOP_OPTS = "$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"

USER $NB_UID

CMD ["jupyter-lab","--ip=0.0.0.0","--no-browser","--allow-root"]
