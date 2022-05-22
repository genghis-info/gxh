FROM ubuntu
LABEL maintainer="Genghis Yang <yangcheng2503@163.com>"

ENV XRAY_CONFIG="e30="

RUN apt-get update && apt-get install -y curl jq tini unzip

COPY *.sh ./

RUN chmod +x ./*.sh && ./install-release.sh

ENTRYPOINT [ "tini", "-g", "-s", "--" ]

CMD [ "./start-xray.sh" ]