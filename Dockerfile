#Build container
FROM python:3.11.1-bullseye@sha256:3f6813d830f7d841ef03d6a27e276c50b6eefbfe035f8cd81936a4d2b04361b9 AS builder

#Run apt update && apt install and build pyodbc and cffi as wheels
COPY /requirements-build.txt .
RUN apt-get update &&\
    apt-get install -y build-essential unixodbc-dev &&\
    python -m pip wheel --no-binary :all: --wheel-dir /tmp/wheelhouse -r requirements-build.txt

#App container
FROM python:3.11.1-alpine3.17@sha256:ed092003fe2c497ba66569dae9fa037af68e13afb3e51efa5b760bd62e6b4ae6

ENV ACCEPT_EULA=Y
#Run apk add with no caching && install MS SQL ODBC Driver v18
RUN \
    apk add --no-cache curl gnupg &&\
    curl -O https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/msodbcsql18_18.0.1.1-1_amd64.apk &&\
    curl -O https://download.microsoft.com/download/b/9/f/b9f3cce4-3925-46d4-9f46-da08869c6486/msodbcsql18_18.0.1.1-1_amd64.sig &&\
    curl https://packages.microsoft.com/keys/microsoft.asc  | gpg --import - &&\
    gpg --verify -v msodbcsql18_18.0.1.1-1_amd64.sig msodbcsql18_18.0.1.1-1_amd64.apk &&\
    apk add --allow-untrusted msodbcsql18_18.0.1.1-1_amd64.apk &&\
    rm msodbcsql18_18.0.1.1-1_amd64.apk &&\
    apk del curl gnupg

#Copy pyodbc and cffi wheels to app container, and install them
COPY /requirements-build.txt .
COPY --from=builder /tmp/wheelhouse /tmp/wheelhouse
RUN ls /tmp/wheelhouse && pip install --no-cache-dir --no-index --find-links=/tmp/wheelhouse -r requirements-build.txt

#install other redependencies and copy application
COPY /requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
WORKDIR /app
COPY cardterminals /app/cardterminals
COPY main.py .
ENV PYTHONUNBUFFERED 1
CMD ["python", "main.py"]
