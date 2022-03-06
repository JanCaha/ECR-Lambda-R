FROM ubuntu:20.04

# set shell to bin/bash instead of default sh
SHELL ["/bin/bash", "-c"]

# install necessary tools
# install R and libraries (system + R) to allow R functionality
RUN apt update && \
    apt install -y curl software-properties-common gnupg wget locales && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
    add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/' && \
    apt-get update && \
    apt-get -y install r-base r-base-dev && \
    apt install -y libcurl4-openssl-dev libssl-dev libxml2-dev && \
    apt install -y python3 python3-pip && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/*

RUN pip install boto3

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm awscliv2.zip

# install aws-lambda-rie for local testing
RUN mkdir -p /usr/local/bin/ && \
    curl -Lo /usr/local/bin/aws-lambda-rie https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie && \ 
    chmod +x /usr/local/bin/aws-lambda-rie

# install R packages
RUN Rscript -e 'install.packages(c("httr", "logging", "jsonlite", "glue", "rlang"), repos="http://cran.r-project.org")' && \ 
    Rscript -e 'install.packages(c("botor", "vroom"), repos="http://cran.r-project.org")' && \ 
    Rscript -e 'install.packages("aws.s3", repos = c("https://RForge.net", "https://cloud.R-project.org"))' && \ 
    Rscript -e 'install.packages(c("tidyverse", "here", "data.table", "fs", "remotes"), repos="http://cran.r-project.org")'

# copy entrypoint
WORKDIR /
COPY files/lambda_entrypoint.sh lambda_entrypoint.sh
RUN chmod 755 lambda_entrypoint.sh

ENTRYPOINT ["/lambda_entrypoint.sh"]

# copy bootstrap
WORKDIR /var/runtime/
COPY files/bootstrap bootstrap
RUN chmod 755 bootstrap

# copy R files
WORKDIR /opt
COPY files/bootstrap.R bootstrap.R
COPY files/runtime.R runtime.R
RUN chmod 755 bootstrap.R runtime.R

# set necessary Environments
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TZ=:/etc/localtime
ENV PATH="/opt/bin:${PATH}"
ENV LD_LIBRARY_PATH="/var/runtime:/var/runtime/lib:/var/task:/var/task/lib:/opt/lib"
ENV LAMBDA_TASK_ROOT=/var/task
ENV LAMBDA_RUNTIME_DIR=/var/runtime

COPY lambda/ /lambda/

WORKDIR /lambda/test

# set command
CMD [ "script.handler" ]
