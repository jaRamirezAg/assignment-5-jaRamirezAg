##############################################################
#
# AESD-ASSIGNMENTS
#
##############################################################

# Asegúrate de que el sitio y la versión apunten a tu nuevo repositorio y rama
AESD_ASSIGNMENTS_VERSION = 'HEAD' 
AESD_ASSIGNMENTS_SITE = 'git@github.com:jaRamirezAg/assignment-5-jaRamirezAg.git'
AESD_ASSIGNMENTS_SITE_METHOD = git

define AESD_ASSIGNMENTS_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)/server all
endef

define AESD_ASSIGNMENTS_INSTALL_TARGET_CMDS
	# 1. Instalar el ejecutable en /usr/bin
	$(INSTALL) -m 0755 $(@D)/server/aesdsocket $(TARGET_DIR)/usr/bin/aesdsocket
	
	# 2. Instalar el script de inicio en /etc/init.d/ con el nombre S99aesdsocket
	# El prefijo S99 asegura que sea uno de los últimos servicios en arrancar
	$(INSTALL) -m 0755 $(@D)/server/aesdsocket-start-stop $(TARGET_DIR)/etc/init.d/S99aesdsocket
endef

$(eval $(generic-package))