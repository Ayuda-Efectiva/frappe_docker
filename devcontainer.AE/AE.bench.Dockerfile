# DFP Extendemos la imagen original de Frappe con nuestros settings
# DFP: TODO: ir actualizando! No dejamos latest porque no es necesario tener la última versión del bench y te realentiza mucho el arranque cada vez que sale una nueva.
# FROM frappe/bench:latest
FROM frappe/bench:v5.29.1
# https://hub.docker.com/r/frappe/bench/tags

# # Forzar shell bash para "frappe"
# RUN sudo usermod -s /bin/bash "$(whoami)"
# #SHELL ["/bin/bash", "-lc"]

# TODO: ESTO NO ES LO MÁS BONITO PERO
# IMPORTANTE PARA QUE FUNCIONEN LOS BINDS (.ssh/*, github, etc)
# Obtener los UID y GUID del usuario actual en el host
# id -u   # UID y ajustarlo en .env
# id -g   # GID y ajustarlo en .env
# 1000 son los valores por defecto si no se pasan en el docker-compose!
ARG HOST_UID=1001
ARG HOST_GID=1001
RUN sudo groupmod -o -g ${HOST_GID} frappe && sudo usermod -o -u ${HOST_UID} -g ${HOST_GID} frappe

# # Instalar software-properties-common para manejar repositorios adicionales (si es necesario)
# # Actualizar la lista de paquetes y reparar posibles problemas
# RUN sudo apt update && \
#     # apt install -y software-properties-common locales && \
#     # sudo apt update --fix-missing && \
#     sudo apt clean && \
#     sudo rm -rf /var/lib/apt/lists/*

RUN sudo sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
    sudo sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
    sudo sed -i -e 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen && \
    sudo dpkg-reconfigure --frontend=noninteractive locales

# # Generar los locales requeridos
# RUN locale-gen es_ES.UTF-8 fr_FR.UTF-8 en_GB.UTF-8 en_US.UTF-8

# Configurar el local por defecto a Español de España
ENV LANG=es_ES.UTF-8
ENV LANGUAGE=es_ES:es
ENV LC_ALL=es_ES.UTF-8

# # DFP Autoformateado
# RUN pip install --no-cache-dir autopep8

# Mantiene el contenedor en ejecución
#CMD ["sleep", "infinity"]
# CMD ["/bin/bash"]
