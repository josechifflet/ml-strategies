# TA-Lib
FROM python:3.7-slim AS compiler
ENV PYTHONUNBUFFERED 1

RUN apt-get update
RUN apt-get install -y --no-install-recommends build-essential gcc wget
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install numpy

# Install Ta-Lib
RUN wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz && \
  tar -xvzf ta-lib-0.4.0-src.tar.gz && \
  cd ta-lib/ && \
  ./configure --build=aarch64-unknown-linux-gnu --prefix=/opt/venv && \
  make && \
  make install
RUN pip install --global-option=build_ext --global-option="-L/opt/venv/lib" TA-Lib==0.4.24
RUN rm -R ta-lib ta-lib-0.4.0-src.tar.gz

# Install pip dependencies
RUN pip install \
    pandas \
    pandas_ta \
    numpy \
    matplotlib \
    plotly \
    ta \
    finta \
    ccxt \
    yfinance \
    pyspark \
    pyspark[sql] \
    pyspark[pandas_on_spark] \
    scipy \
    cython \
    Ta-Lib \
    tensorflow \
    keras

FROM jupyter/datascience-notebook

COPY --from=compiler /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/venv/lib"

# Let's change to root user to install java 8
USER root

RUN apt-get update \
    && echo "Updated apt-get" \
    && apt-get install -y openjdk-8-jre \
    && echo "Installed openjdk 8" \
    && apt-get install -y --no-install-recommends build-essential \
    && echo "Installed build-essential"
    
RUN conda install -y -c jetbrains kotlin-jupyter-kernel && echo "Kotlin Jupyter kernel installed via conda"

ENV HADOOP_OPTS = "$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"

USER $NB_UID

CMD ["jupyter-lab","--ip=0.0.0.0","--no-browser","--allow-root"]
