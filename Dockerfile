FROM centos:latest
RUN yum install -y wget && cd /tmp && wget https://downloads.typesafe.com/typesafe-activator/1.3.12/typesafe-activator-1.3.12.zip
