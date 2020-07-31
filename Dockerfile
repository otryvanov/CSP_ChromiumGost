FROM selenoid/vnc:chrome_68.0
USER root

ARG HDIMAGE_STORE_NAME=myStoreName
ARG HDIMAGE_STORE_PASSWORD=myStorePassword
ARG CERT_FILE_NAME=mayCertName.cer
#ARG CSP_LICENSE_KEY=
ARG USER_NAME=selenium

ADD dist/ filehome/app/dist/
ADD cert/ /home/app/cert/
##Полный доступ к директории
RUN chmod -R 777 /home/app/

RUN tar -zxf /home/app/dist/linux-amd64_deb.tgz -C /home/app/dist/
RUN tar -xzf /home/app/dist/cades_linux_amd64.tar.gz -C /home/app/dist/

# Установка КриптоПро CSP 4.0
RUN /home/app/dist/linux-amd64_deb/install.sh
RUN dpkg -i /home/app/dist/linux-amd64_deb/cprocsp-rdr-gui-gtk-64_4.0.9944-5_amd64.deb
# kc1 без биодачика
RUN dpkg -i /home/app/dist/linux-amd64_deb/lsb-cprocsp-kc1-64_4.0.9944-5_amd64.deb

# Номер лицензии (Если у вас есть лицензионный ключ, необходимо раскоментировать следующую строку и
# подставить свой серийный ключ вместо $CSP_LICENSE_KEY и раскоментировать его !!!)
#RUN /opt/cprocsp/sbin/amd64/cpconfig -license -set $CSP_LICENSE_KEY

# Проверка лицензии
RUN /opt/cprocsp/sbin/amd64/cpconfig -license -view


# Перенос закрытого ключа в HDIMAGE
RUN mkdir -p /var/opt/cprocsp/keys/$USER_NAME/$HDIMAGE_STORE_NAME.000 && mv /home/app/cert/$HDIMAGE_STORE_NAME.000/ /var/opt/cprocsp/keys/$USER_NAME/
# даем права на чтение закрытого ключа пользователю $USER_NAME
RUN chown $USER_NAME /var/opt/cprocsp/keys/$USER_NAME/ -R
# Создаем хранилище HDIMAGE
RUN /opt/cprocsp/sbin/amd64/cpconfig -hardware reader -add HDIMAGE store

USER $USER_NAME
# Добавляем сертификат в хранилище (от пользователя которым производим подпись)
RUN /opt/cprocsp/bin/amd64/certmgr -inst -file /home/app/cert/$CERT_FILE_NAME -cont "\\\\.\\HDIMAGE\\$HDIMAGE_STORE_NAME"
# Убираем пароль, чтобы он не кидал alert (Если хранилище уже не запаролено, то закоментить следующую строку)
RUN /opt/cprocsp/bin/amd64/csptest -passwd -change '' -cont "\\\\.\\HDIMAGE\\$HDIMAGE_STORE_NAME" -passwd $HDIMAGE_STORE_PASSWORD

USER root
# Устанавливаем alien для rpm пакетов
RUN apt update && apt-get install lsb lsb-core alien ca-certificates -y
# Устанвока КриптоПро ЭЦП Browser plug-in содержит необходимые библиотеки для компиляции и исходники расширений
RUN alien -kci /home/app/dist/cprocsp-pki-2.0.0-amd64-cades.rpm
RUN alien -kci /home/app/dist/cprocsp-pki-2.0.0-amd64-plugin.rpm
RUN alien -kci /home/app/dist/cprocsp-pki-2.0.0-amd64-phpcades.rpm
RUN alien -kci /home/app/dist/lsb-cprocsp-devel-4.0.9921-5.noarch.rpm
# бывает не с первого раза копируется библиотека
RUN alien -kci /home/app/dist/cprocsp-pki-2.0.0-amd64-plugin.rpm
# убираем alert "переход на новый алгоритм в 2019 году
# см. https://support.cryptopro.ru/index.php?/Knowledgebase/Article/View/226/0/otkljuchenie-preduprezhdjushhikh-okon-o-neobkhodimosti-skorogo-perekhod-n-gost-r-3410-2012
RUN sed -i 's/\[Parameters\]/[Parameters]\nwarning_time_gen_2001=ll:131907744000000000\nwarning_time_sign_2001=ll:131907744000000000/g' /etc/opt/cprocsp/config64.ini

USER $USER_NAME
# Добавляем узлы, к которым будем обращаться в доверенные.
RUN /opt/cprocsp/sbin/amd64/cpconfig -ini "\local\Software\Crypto Pro\CAdESplugin" -add multistring TrustedSites "www.site.ru"
