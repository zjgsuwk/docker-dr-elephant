FROM centos:latest
MAINTAINER Damien Claveau <damien.claveau@gmail.com>

## PREREQUESITES ##
RUN yum --exclude=openssh-\* --exclude=policycoreutils\* --exclude=libsemanage-\* --exclude=selinux-\* --exclude=iputils update -y \
 && yum clean all
RUN yum install -y wget git unzip zip which \
 && yum install -y krb5-server krb5-libs krb5-workstation \
 && yum install -y krb5-auth-dialog pam_krb5 \
 && yum install -y openssh-server openssh-clients \
 && yum clean all

# jdk
RUN  yum install -y java-1.8.0-openjdk
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.161-0.b14.el7_4.x86_64/
RUN mkdir ${JAVA_HOME}/bin
RUN ln -s /usr/bin/java ${JAVA_HOME}/bin/java
# jce
RUN yum install -y unzip && yum clean all \
 && cd /tmp \
 && wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip \
 && unzip jce_policy-8.zip \
 && mv -f UnlimitedJCEPolicyJDK8/*.jar $JAVA_HOME/jre/lib/security/ \
 && rm -rf jce_policy-8.zip UnlimitedJCEPolicyJDK8

# sbt
RUN curl https://bintray.com/sbt/rpm/rpm > bintray-sbt-rpm.repo \
 && mv bintray-sbt-rpm.repo /etc/yum.repos.d/ \
 && yum -y install sbt

RUN curl -O https://downloads.typesafe.com/play/2.2.2/play-2.2.2.zip \
  && unzip play-2.2.2.zip -d / \
  && rm play-2.2.2.zip \
  && chmod a+x /play-2.2.2/play
ENV PATH $PATH:/play-2.2.2

# play
# RUN curl -O http://downloads.typesafe.com/typesafe-activator/1.3.9/typesafe-activator-1.3.9.zip \
#  && unzip typesafe-activator-1.3.9.zip -d / \
#  && rm typesafe-activator-1.3.9.zip \
#  && chmod a+x /activator-dist-1.3.9/bin/activator
# ENV PATH $PATH:/activator-dist-1.3.9/bin

## CONFIGURE ##

ENV ELEPHANT_CONF_DIR ${ELEPHANT_CONF_DIR:-/usr/dr-elephant/app-conf}

#ARG SPARK_VERSION
ENV SPARK_VERSION ${SPARK_VERSION:-1.6.0}

## BUILD AND INSTALL ##

ENV ELEPHANT_VERSION 2.0.13

RUN git clone https://github.com/damienclaveau/dr-elephant.git /tmp/dr-elephant \
 && cd /tmp/dr-elephant \
## && git checkout tags/$ELEPHANT_VERSION
## && cp resolver.conf.template ./app-conf/resolver.conf \
 && echo "" >> ./build.sbt && echo "resolvers += \"scalaz-bintray\" at \"https://dl.bintray.com/scalaz/releases\"" >> ./build.sbt \
 && sed -i -e "s/clean\stest\scompile\sdist/clean compile dist/g"    ./compile.sh \
 && sed -i -e "s/spark_version=.*/spark_version=$SPARK_VERSION/g"    ./compile.conf \
 && ./compile.sh ./compile.conf \
 && cd /tmp/dr-elephant \
 && unzip ./dist/dr-elephant-$ELEPHANT_VERSION.zip -d /usr \
 && ln -s  /usr/dr-elephant-$ELEPHANT_VERSION /usr/dr-elephant \
 && rm -Rf /tmp/dr-elephant

## CONFIGURE ##

## Linked MySql container env vars are injected
## Keytab configuration should be valued as env vars by docker run
RUN cd /usr/dr-elephant \
 && sed -i -e "s/port=.*/port=\${http_port:-8080}/g"                              ./app-conf/elephant.conf \
 && sed -i -e "s/db_url=.*/db_url\=\${MYSQL_PORT_3306_TCP_ADDR:-localhost}/g"     ./app-conf/elephant.conf \
 && sed -i -e "s/db_name=.*/db_name=\${MYSQL_ENV_MYSQL_DATABASE:-drelephant}/g"   ./app-conf/elephant.conf \
 && sed -i -e "s/db_user=.*/db_user=\${MYSQL_ENV_MYSQL_USER:-root}/g"             ./app-conf/elephant.conf \
 && sed -i -e "s/db_password=.*/db_password=\${MYSQL_ENV_MYSQL_PASSWORD:-""}/g"   ./app-conf/elephant.conf \
 && sed -i -e "s/#\skeytab_user=.*/keytab_user=\${keytab_user:-""}/g"             ./app-conf/elephant.conf \
 && sed -i -e "s/#\skeytab_location=.*/keytab_location=\${keytab_location:-""}/g" ./app-conf/elephant.conf \
 && sed -i -e 's@jvm_args=.*@jvm_args="-Devolutionplugin=enabled -DapplyEvolutions.default=true -Dlog4j.configuration=file:/usr/dr-elephant/conf/log4j.properties"@g' ./app-conf/elephant.conf \
 && sed -i -e 's@nohup.*@./bin/dr-elephant ${OPTS} > $project_root/dr.log 2>\&1@g' ./bin/start.sh

## RUN ##

EXPOSE 8080

VOLUME $ELEPHANT_CONF_DIR  /usr/dr-elephant/logs

CMD ["/usr/dr-elephant/bin/start.sh"]
