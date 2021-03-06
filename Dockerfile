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
RUN  yum install -y java-1.8.0-openjdk-devel
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.161-0.b14.el7_4.x86_64/



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

#RUN curl -O https://downloads.typesafe.com/play/2.2.2/play-2.2.2.zip \
#  && unzip play-2.2.2.zip -d / \
#  && rm play-2.2.2.zip \
#  && chmod a+x /play-2.2.2/play
# ENV PATH $PATH:/play-2.2.2

# play
RUN curl -O https://downloads.typesafe.com/typesafe-activator/1.3.12/typesafe-activator-1.3.12.zip \
&& unzip typesafe-activator-1.3.12.zip -d / \
&& rm typesafe-activator-1.3.12.zip \
&& chmod a+x /activator-dist-1.3.12/bin/activator
ENV PATH $PATH:/activator-dist-1.3.12/bin

# NodeJS v6
RUN curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - \
 && yum install -y gcc-c++ make \
 && yum install -y nodejs \
 && yum clean all \
 && echo '{ "allow_root": true }' > /root/.bowerrc

## CONFIGURE ##

ENV ELEPHANT_CONF_DIR ${ELEPHANT_CONF_DIR:-/usr/dr-elephant/app-conf}

#ARG SPARK_VERSION
ENV SPARK_VERSION ${SPARK_VERSION:-2.1.1}

#ARG HADOOP_VERSION
ENV HADOOP_VERSION ${HADOOP_VERSION:-2.7.5}

#ARG HADOOP_HOME
ENV HADOOP_HOME ${HADOOP_HOME:-/usr/share/hadoop}

#ARG HADOOP_CONF_DIR
ENV HADOOP_CONF_DIR ${HADOOP_CONF_DIR:-/etc/hadoop/conf}

## SETUP HADOOP CLIENT ##
# Set Hadoop-related environment variables
ENV YARN_HOME ${HADOOP_HOME}
ENV HADOOP_MAPRED_HOME ${HADOOP_HOME}
ENV HADOOP_COMMON_HOME ${HADOOP_HOME}
ENV HADOOP_HDFS_HOME ${HADOOP_HOME}
ENV HADOOP_PREFIX ${HADOOP_HOME}
ENV HADOOP_COMMON_LIB_NATIVE_DIR ${HADOOP_PREFIX}/lib/native
ENV HADOOP_OPTS "-Djava.library.path=$HADOOP_COMMON_LIB_NATIVE_DIR"
ENV PATH $HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

## BUILD AND INSTALL ##

ENV ELEPHANT_VERSION 2.0.13

RUN git clone https://github.com/linkedin/dr-elephant.git -b customSHSWork /tmp/dr-elephant \
 && cd /tmp/dr-elephant \
 && sed -i -e "s/hadoop_version=.*/hadoop_version=$HADOOP_VERSION/g" ./compile.conf \
 && sed -i -e "s/spark_version=.*/spark_version=$SPARK_VERSION/g"    ./compile.conf \
 && ./compile.sh ./compile.conf \

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

VOLUME $ELEPHANT_CONF_DIR $HADOOP_CONF_DIR /usr/dr-elephant/logs

CMD ["/usr/dr-elephant/bin/start.sh"]
